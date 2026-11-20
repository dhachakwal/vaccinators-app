import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import '../config.dart';
import 'mock_location_service.dart';

/// GPS + background location.
/// Foreground: one high-accuracy fix for a manual submit.
/// Background: Workmanager periodic task (30 min) — Android may delay
/// it on some phones; the app tells the user to turn battery
/// optimisation OFF for this app if background sends stop.
class LocationService {
  static const String bgTaskName = 'epi-background-location';

  Future<bool> ensurePermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    if (!status.isGranted) return false;
    // Background needs "Allow all the time" on Android 10+.
    final bg = await Permission.locationAlways.status;
    if (!bg.isGranted) {
      await Permission.locationAlways.request();
    }
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    return serviceOn;
  }

  Future<Position?> currentPosition() async {
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (!ok) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      return null;
    }
  }

  static String mapsLink(double lat, double lng) =>
      'https://www.google.com/maps?q=$lat,$lng';

  /// One location read WITH the mock verdict. Every caller (manual
  /// submit and the background task) must use this, never
  /// [currentPosition] alone — a mocked fix must be caught at the
  /// read, before anything is sent or stored.
  /// [previousLat]/[previousLng]/[previousTime] are the last
  /// verified fix (StorageService); pass null when unavailable.
  Future<MockCheckedPosition> currentPositionChecked({
    double? previousLat,
    double? previousLng,
    DateTime? previousTime,
  }) async {
    final pos = await currentPosition();
    if (pos == null) {
      return const MockCheckedPosition(
          position: null, check: MockLocationCheck.clean);
    }
    final check = MockLocationService.check(pos,
        previousLat: previousLat,
        previousLng: previousLng,
        previousTime: previousTime);
    return MockCheckedPosition(position: pos, check: check);
  }

  /// Call after login / first location, passing the logged-in vaccinator.
  /// inputData carries the identity into the background isolate,
  /// which cannot read SharedPreferences login state by itself.
  static Future<void> registerBackground(
      Map<String, String> vaccinator) async {
    await Workmanager().initialize(
      _backgroundDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      bgTaskName,
      bgTaskName,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      inputData: vaccinator,
    );
  }

  static Future<void> cancelBackground() async {
    await Workmanager().cancelByUniqueName(bgTaskName);
  }
}

/// Runs in a background isolate. Sends ONE location POST with the
/// identity passed in inputData (see registerBackground). No verify
/// step is possible cheaply here — the foreground app's next sync
/// confirms the row; if this POST fails, Workmanager retries and the
/// foreground queue still holds the manual submits. Never send a
/// nameless pin: no username in inputData means do nothing.
@pragma('vm:entry-point')
void _backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != LocationService.bgTaskName) return Future.value(true);
    try {
      final username = (inputData?['username'] ?? '').toString();
      if (username.isEmpty) return Future.value(true);
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      // Background: a mocked fix is NEVER sent as a location.
      // Report the attempt instead, then stop — no retry, no row.
      final mockCheck = MockLocationService.check(pos);
      if (mockCheck.isMocked) {
        final report = MockLocationService.reportPayload(
          name: (inputData?['name'] ?? '').toString(),
          username: username,
          tehsil: (inputData?['tehsil'] ?? '').toString(),
          uc: (inputData?['uc'] ?? '').toString(),
          pos: pos,
          check: mockCheck,
        );
        await http
            .post(
              Uri.parse(AppConfig.locationScriptUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: jsonEncode(report),
            )
            .timeout(const Duration(seconds: 30));
        return Future.value(true);
      }
      final payload = <String, dynamic>{
        'type': 'location',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'name': (inputData?['name'] ?? '').toString(),
        'username': username,
        'tehsil': (inputData?['tehsil'] ?? '').toString(),
        'uc': (inputData?['uc'] ?? '').toString(),
        'kitStation': (inputData?['kitStation'] ?? '').toString(),
        'lat': pos.latitude.toString(),
        'lng': pos.longitude.toString(),
        'accuracy': pos.accuracy.round().toString(),
        'maps': LocationService.mapsLink(pos.latitude, pos.longitude),
      };
      final res = await http
          .post(
            Uri.parse(AppConfig.locationScriptUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      return Future.value(res.statusCode >= 200 && res.statusCode < 400);
    } catch (_) {
      return Future.value(false); // Workmanager will retry later
    }
  });
}
