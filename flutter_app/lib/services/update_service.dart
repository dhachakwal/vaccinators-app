import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';

/// FORCED IN-APP UPDATE (user order, 19 Nov 2026 — STANDING RULE):
/// checks version.json on the EPI site on launch. If the site
/// versionCode is newer, the app must update FIRST — the old version
/// does not open. The update downloads the APK in-app (with
/// progress) and opens the Android installer automatically.
/// No Play Store involved.
///
/// version.json fields:
///   versionCode (int), versionName (String),
///   apkUrl (String), whatsNew (String, English),
///   whatsNewUr (String, Urdu script — optional),
///   optional (bool — optional; absent/false = FORCED, the default).
///
/// Server-down exception: check() returns null when version.json
/// cannot be reached at all (no net, site down, bad status). The
/// caller (main.dart) must then OPEN THE APP NORMALLY with a small
/// note — a site outage must never lock 70 vaccinators out. Only
/// a successful check that finds a newer version blocks the app.
class AppUpdate {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String whatsNew;
  final String whatsNewUr;
  final bool optional;
  const AppUpdate({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.whatsNew,
    this.whatsNewUr = '',
    this.optional = false,
  });

  bool get isNewer => versionCode > AppConfig.versionCode;

  /// True when the update blocks the app (the default).
  /// Only `optional: true` in version.json allows "Later".
  bool get isForced => isNewer && !optional;
}

class UpdateService {
  /// Returns the site update, or null when the check itself failed
  /// (no net / site down / bad response) — null means "could not
  /// check", NEVER "no update". Callers must open the app normally.
  Future<AppUpdate?> check() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.versionJsonUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return AppUpdate(
        versionCode: (j['versionCode'] as num?)?.toInt() ?? 0,
        versionName: (j['versionName'] ?? '').toString(),
        apkUrl: (j['apkUrl'] ?? AppConfig.apkUrl).toString(),
        whatsNew: (j['whatsNew'] ?? '').toString(),
        whatsNewUr: (j['whatsNewUr'] ?? '').toString(),
        optional: j['optional'] == true,
      );
    } catch (_) {
      return null; // No net / site down — never block launch.
    }
  }

  /// Downloads the APK to the app's temp folder, reporting progress.
  /// Returns the downloaded file. Throws on any failure (no net,
  /// bad status, write error) — the caller shows Retry.
  /// The file is deleted by Android/the OS temp cleanup later; the
  /// installer copies what it needs at install time.
  Future<File> downloadApkFile(
    String url, {
    required void Function(int received, int? total) onProgress,
  }) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(
            const Duration(minutes: 10),
          );
      if (res.statusCode != 200) {
        throw HttpException(
            'APK download failed: HTTP ${res.statusCode}');
      }
      final total = res.contentLength == -1 ? null : res.contentLength;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/vaccinators-app-update.apk');
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          received += chunk.length;
          sink.add(chunk);
          onProgress(received, total);
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close();
    }
  }

  /// Opens the Android installer for a downloaded APK.
  /// Returns true when the installer opened. Returns false when it
  /// did not (e.g. "install unknown apps" is not allowed yet for
  /// this app) — the caller then shows the Settings instruction.
  /// Requires REQUEST_INSTALL_PACKAGES (see AndroidManifest.xml).
  Future<bool> openInstaller(File apkFile) async {
    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }

  /// Legacy fallback: open the APK link in the browser (used only
  /// if the in-app download path is unavailable). Kept for the
  /// Profile "Check for Update" path before the update screen.
  Future<void> downloadApk(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
