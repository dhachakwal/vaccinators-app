import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// Anti-fake-location (MUST-HAVE, user order 19 Nov 2026).
///
/// Two behaviours, both implemented:
///   1. DETECT + REPORT — a mocked fix is detected at once and a
///      `mockLocation` report (who / UC / time / mocked lat-lng) is
///      queued for the admin.
///   2. BLOCK — while a mocked fix is active the app refuses to
///      accept a location submit and shows a blocking warning
///      ("Turn off fake location" — Urdu script + English) until
///      the mock is off and a fresh, clean fix is read.
///
/// Checks run on EVERY location read (manual + background), not
/// just at login. No check here claims to catch a rooted phone
/// running advanced spoofing — that is what the server-side layer
/// is for (see the design doc): impossible travel speed between
/// two accepted submits, and a fix outside the district polygon.
/// Client-side checks:
///   a. [Position.isMocked] — the Android mock-provider flag. This
///      is the reliable signal for standard mock-location apps
///      (Fake GPS etc.): when a mock app is active, Android marks
///      the fix as mocked. There is no reliable Flutter-only way
///      to list *which* mock app is set in Developer options, and
///      no extra permission can ask Android for it — `isMocked`
///      is the sanctioned signal, so it is the primary check.
///   b. Impossible speed — the fix itself reports > 55 m/s
///      (~198 km/h), or the jump from the last *verified*
///      location implies > 150 km/h. A vaccinator on a bike/car
///      in Chakwal cannot travel that fast.
///   c. Timestamp sanity — a fix older than 5 minutes, or stamped
///      in the future (> 2 min ahead), is a cached/replayed fix,
///      not a live one.
///   d. Outside District Chakwal — the fix is far outside the
///      district (wide bounds on purpose, so border UCs such as
///      Lawa are never flagged: lat 32.20–33.60, lng 72.00–73.60).
///      Lahore (31.5) / Islamabad (33.7) / Rawalpindi are outside.
///   e. Implausible accuracy (accuracy < 0, or > 500 m) is a
///      SOFT warning only — it never blocks on its own, because a
///      weak GPS fix indoors is genuine. It is reported with the
///      other reasons when one of (a)–(d) also fires.
enum MockReason { mockedFlag, impossibleSpeed, staleTimestamp, outsideDistrict, badAccuracy }

/// Result of one mock check. [isMocked] is true only when at least
/// one HARD reason fired — a soft-only result never blocks.
class MockLocationCheck {
  final bool isMocked;
  final List<MockReason> reasons;
  const MockLocationCheck({required this.isMocked, required this.reasons});

  static const clean = MockLocationCheck(isMocked: false, reasons: []);

  /// Short stable codes for the report payload / sheet, e.g. "mockedFlag+outsideDistrict".
  String get code =>
      reasons.map((r) => r.name).join('+');

  /// String keys into AppStrings for the user-facing reasons.
  List<String> get reasonKeys =>
      reasons.map((r) => 'mockReason${r.name[0].toUpperCase()}${r.name.substring(1)}').toList();
}

/// A fix together with its mock verdict.
class MockCheckedPosition {
  final Position? position;
  final MockLocationCheck check;
  const MockCheckedPosition({required this.position, required this.check});
}

class MockLocationService {
  MockLocationService._();

  /// District Chakwal — deliberately wide bounds (see header).
  static const double minLat = 32.20;
  static const double maxLat = 33.60;
  static const double minLng = 72.00;
  static const double maxLng = 73.60;

  /// Above this speed a single fix cannot be genuine travel here.
  static const double maxFixSpeedMps = 55.0; // ~198 km/h
  /// Above this implied speed between two fixes, the jump is fake.
  static const double maxTravelSpeedMps = 41.7; // 150 km/h
  static const Duration maxFixAge = Duration(minutes: 5);
  static const Duration maxFutureSkew = Duration(minutes: 2);
  static const double maxPlausibleAccuracyM = 500.0;

  static double _haversineM(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Check one fix. [previousLat]/[previousLng]/[previousTime] are
  /// the last *verified* location (from StorageService) — pass null
  /// in the background isolate, where they are unavailable; the
  /// other checks still run there.
  static MockLocationCheck check(
    Position pos, {
    double? previousLat,
    double? previousLng,
    DateTime? previousTime,
  }) {
    final reasons = <MockReason>[];
    if (pos.isMocked) reasons.add(MockReason.mockedFlag);
    if (pos.speed > maxFixSpeedMps) reasons.add(MockReason.impossibleSpeed);
    final now = DateTime.now();
    final age = now.difference(pos.timestamp);
    if (age > maxFixAge || age < -maxFutureSkew) {
      reasons.add(MockReason.staleTimestamp);
    }
    if (pos.latitude < minLat ||
        pos.latitude > maxLat ||
        pos.longitude < minLng ||
        pos.longitude > maxLng) {
      reasons.add(MockReason.outsideDistrict);
    }
    if (previousLat != null &&
        previousLng != null &&
        previousTime != null) {
      final dt = pos.timestamp.difference(previousTime).inSeconds;
      if (dt > 0) {
        final dist = _haversineM(previousLat, previousLng, pos.latitude, pos.longitude);
        if (dist / dt > maxTravelSpeedMps) {
          if (!reasons.contains(MockReason.impossibleSpeed)) {
            reasons.add(MockReason.impossibleSpeed);
          }
        }
      }
    }
    // Soft only — added for the report, never blocks by itself.
    if (pos.accuracy < 0 || pos.accuracy > maxPlausibleAccuracyM) {
      reasons.add(MockReason.badAccuracy);
    }
    final hard = reasons.where((r) => r != MockReason.badAccuracy).toList();
    return MockLocationCheck(isMocked: hard.isNotEmpty, reasons: reasons);
  }

  /// Report payload for a mocked attempt. Same single-POST pattern
  /// as every other payload; type 'mockLocation' is a PROPOSED new
  /// tab (see GOAL.md) — until the Apps Script adds it, SyncService
  /// queues it honestly and never claims success.
  static Map<String, dynamic> reportPayload({
    required String name,
    required String username,
    required String tehsil,
    required String uc,
    required Position pos,
    required MockLocationCheck check,
  }) {
    return {
      'type': 'mockLocation',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'name': name,
      'username': username,
      'tehsil': tehsil,
      'uc': uc,
      'lat': pos.latitude.toString(),
      'lng': pos.longitude.toString(),
      'accuracy': pos.accuracy.round().toString(),
      'mocked': true,
      'reasons': check.code,
      'fixTimestamp': pos.timestamp.toIso8601String(),
      // Same link format as LocationService.mapsLink; kept inline
      // here on purpose so this file does not import LocationService
      // (which imports this file — a circular import).
      'maps':
          'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}',
    };
  }
}
