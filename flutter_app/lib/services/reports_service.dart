import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// DAILY REPORTS IN-APP (user order, 19 Nov 2026).
///
/// The 11 daily reports the nightly pipeline already sends on
/// WhatsApp at 3:00 AM PKT must ALSO arrive inside each
/// vaccinator's app, every morning. The app side does NOT rebuild
/// that pipeline — it only READS what the pipeline publishes:
///
///   1. The pipeline uploads each report file to the EPI site
///      (e.g. `reports/2026-11-19/emr-tab4.png`).
///   2. The pipeline writes `reports.json` on the site — a
///      manifest listing each day's reports (see files/reports.json
///      for the exact format + a sample).
///   3. This service fetches the manifest on launch / refresh and
///      shows ONLY the logged-in vaccinator's OWN UC reports plus
///      district-wide ones (`uc: "all"`).
///
/// PRIVACY RULE (same as My Data — a rule, not a filter):
/// the UC comes ONLY from the login. There is no UC picker, no
/// search, no "all UCs" view on the Reports screen. An entry is
/// shown only when `uc == "all"` (district-wide, no per-vaccinator
/// personal data) or `uc == my UC` (case-insensitive). Other UCs'
/// entries are dropped in memory immediately — never cached as
/// "my" reports, never displayed. The manifest file itself is a
/// public site file (same as forms.json), so the cache stores the
/// raw manifest; the own-UC filter is applied on every read, live
/// and cached alike.
///
/// Offline: the last fetched manifest is cached, and any report
/// file the vaccinator saved ("Save offline") stays on the phone —
/// with no net the screen shows the cached list with an offline
/// note and opens saved files. A report that was never downloaded
/// cannot be opened offline, and the screen says so plainly.
///
/// Opening: PNGs open INSIDE the app (image viewer, pinch zoom).
/// PDFs are downloaded to the phone and opened with the phone's
/// PDF viewer (OpenFilex) — the app has no built-in PDF renderer,
/// and it never pretends otherwise.
class DailyReportItem {
  final String id;
  final String date; // yyyy-MM-dd
  final String title;
  final String titleUr;
  final String kind; // 'png' or 'pdf'
  final String uc; // a UC name, or 'all' for district-wide
  final String url;

  const DailyReportItem({
    required this.id,
    required this.date,
    required this.title,
    required this.titleUr,
    required this.kind,
    required this.uc,
    required this.url,
  });

  factory DailyReportItem.fromJson(
      String date, Map<String, dynamic> j) =>
      DailyReportItem(
        id: (j['id'] ?? '').toString(),
        date: date,
        title: (j['title'] ?? '').toString(),
        titleUr: (j['titleUr'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString().toLowerCase(),
        uc: (j['uc'] ?? 'all').toString(),
        url: (j['url'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'titleUr': titleUr,
        'kind': kind,
        'uc': uc,
        'url': url,
      };

  bool get isPdf => kind == 'pdf';
  bool get isPng => kind == 'png';
  bool get isDistrictWide => uc.trim().toLowerCase() == 'all';

  /// File extension for the on-phone copy (from kind, not the URL
  /// — a URL may carry a query string).
  String get fileExt => isPdf ? 'pdf' : 'png';

  String titleFor(bool isUrdu) =>
      isUrdu && titleUr.isNotEmpty ? titleUr : title;

  /// Visible to this vaccinator? District-wide, or my own UC.
  bool visibleFor(String myUc) {
    if (isDistrictWide) return true;
    return uc.trim().toUpperCase() == myUc.trim().toUpperCase();
  }
}

/// One day's reports, newest day first.
class ReportDay {
  final String date; // yyyy-MM-dd
  final List<DailyReportItem> items;
  const ReportDay({required this.date, required this.items});

  bool get isToday => date == AppConfig.todayYmdPkt();

  /// "19 Nov 2026" — day + short English month + year.
  String get label {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final p = date.split('-');
    if (p.length != 3) return date;
    final m = int.tryParse(p[1]) ?? 1;
    return '${int.tryParse(p[2]) ?? p[2]} ${months[m - 1]} ${p[0]}';
  }
}

class ReportsService {
  static const _kCache = 'reports_cache_json';
  static const _kDownloaded = 'reports_downloaded_ids';

  final http.Client _client;
  ReportsService([http.Client? client]) : _client = client ?? http.Client();

  void dispose() => _client.close();

  List<ReportDay> _parseManifest(String raw, String myUc) {
    final j = jsonDecode(raw);
    final days = (j is Map ? (j['days'] as List? ?? []) : <dynamic>[]);
    final out = <ReportDay>[];
    for (final d in days) {
      final m = Map<String, dynamic>.from(d as Map);
      final date = (m['date'] ?? '').toString();
      if (date.isEmpty) continue;
      final items = ((m['reports'] as List?) ?? [])
          .map((e) => DailyReportItem.fromJson(
              date, Map<String, dynamic>.from(e as Map)))
          .where((it) =>
              it.id.isNotEmpty &&
              it.url.isNotEmpty &&
              (it.isPng || it.isPdf) &&
              it.visibleFor(myUc))
          .toList();
      // A day with no visible reports for this UC is not shown
      // at all — the vaccinator never sees an empty day header.
      if (items.isEmpty) continue;
      out.add(ReportDay(date: date, items: items));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Fetches the live manifest and filters it to this
  /// vaccinator's OWN UC (+ district-wide). On any failure (no
  /// net, site down, bad file) returns the cached manifest,
  /// filtered the same way — never a blank screen, never another
  /// UC's reports. Returns ([days], [fromCache]).
  Future<(List<ReportDay>, bool)> fetchForUc(String myUc) async {
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.reportsUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCache, res.body);
        return (_parseManifest(res.body, myUc), false);
      }
    } catch (_) {
      // Fall through to the cache below.
    }
    return (await _cachedForUc(myUc), true);
  }

  /// Last successfully fetched manifest, filtered to my UC.
  Future<List<ReportDay>> _cachedForUc(String myUc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw == null) return [];
      return _parseManifest(raw, myUc);
    } catch (_) {
      return [];
    }
  }

  // ---------- Offline files ----------

  Future<Directory> _reportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reports = Directory('${dir.path}/reports');
    if (!await reports.exists()) {
      await reports.create(recursive: true);
    }
    return reports;
  }

  Future<File> _localFile(DailyReportItem item) async {
    final dir = await _reportsDir();
    final safeId = item.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safeId.${item.fileExt}');
  }

  Future<bool> isDownloaded(DailyReportItem item) async {
    try {
      return await (await _localFile(item)).exists();
    } catch (_) {
      return false;
    }
  }

  /// Downloads the report file to the phone (for opening, and for
  /// "Save offline"). Reports progress as (received, total).
  /// Throws on any failure — the caller shows Retry, never a fake
  /// "saved" state.
  Future<File> download(
    DailyReportItem item, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse(item.url));
    final res = await _client.send(req).timeout(
          const Duration(minutes: 5),
        );
    if (res.statusCode != 200) {
      throw HttpException('Report download failed: HTTP ${res.statusCode}');
    }
    final total = res.contentLength == -1 ? null : res.contentLength;
    final file = await _localFile(item);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_kDownloaded) ?? []).toSet()
      ..add(item.id);
    await prefs.setStringList(_kDownloaded, ids.toList());
    return file;
  }

  /// Returns the local file to open — the saved copy if present,
  /// otherwise downloads it now (needs internet). Returns null
  /// when the file cannot be obtained.
  Future<File?> ensureLocal(DailyReportItem item) async {
    try {
      final file = await _localFile(item);
      if (await file.exists()) return file;
      return await download(item);
    } catch (_) {
      return null;
    }
  }

  /// Opens a PDF with the phone's PDF viewer (downloads it first
  /// if it is not saved yet). Returns false when the file could
  /// not be obtained or no app on the phone can open it — the
  /// caller tells the vaccinator to install a PDF viewer.
  Future<bool> openPdf(DailyReportItem item) async {
    final file = await ensureLocal(item);
    if (file == null) return false;
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    return result.type == ResultType.done;
  }
}
