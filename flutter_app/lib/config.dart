import 'package:flutter/material.dart';

/// App-wide constants. Backend = existing Google Sheets + Apps Script.
/// Sheet structure is NOT changed by this app. See GOAL.md for the
/// full backend notes, including which payload types are new.
class AppConfig {
  AppConfig._();

  static const String appName = 'Vaccinators App';
  static const String district = 'EPI District Chakwal';
  static const String versionName = '1.0.1';
  static const int versionCode = 2;

  // --- Existing backend (do not change) ---
  static const String masterSheetId =
      '1nG-J44aAXotVp9BTBA_DAu7StQNH3xXK7C02L9hzzd4';
  static const String locationScriptUrl =
      'https://script.google.com/macros/s/AKfycbzhD-4cnQXmLXarQLIYS6Lx6-C6Ztv2_LUkHVlHs-4neHnizD_VO8WptnFNgL3ED9r9Mw/exec';
  static const String siteBase = 'https://dhachakwal.github.io/EPI-Chakwal';
  static const String versionJsonUrl = '$siteBase/version.json';
  static const String apkUrl = '$siteBase/vaccinators-app.apk';
  static const String announcementsUrl = '$siteBase/announcements.json';
  // Dynamic Google Forms (user order, 19 Nov 2026): the form LIST
  // is fetched from this file on every launch / refresh — never
  // hard-coded. A new form = edit forms.json only, no APK update.
  static const String formsUrl = '$siteBase/forms.json';
  // Daily Reports in-app (user order, 19 Nov 2026): the same 11
  // reports the nightly pipeline sends on WhatsApp at 3:00 AM PKT
  // are listed in this manifest on the site. The app fetches it on
  // launch / refresh and shows ONLY the logged-in vaccinator's OWN
  // UC reports (+ district-wide ones) — never another UC's. The
  // app does NOT build the reports; the pipeline must upload the
  // files and write this manifest (see README Step 9).
  static const String reportsUrl = '$siteBase/reports.json';
  // My Microplan in My Data (user order, 19 Nov 2026; files
  // received + audited 20 Nov 2026): the 83 UC microplan
  // workbooks live on the site under microplans/<Tehsil>/<file>
  // and are listed in this manifest (see files/microplans.json
  // for the exact format). The app downloads ONLY the logged-in
  // vaccinator's OWN UC file, on demand — never the whole 58 MB,
  // never baked into the APK. The 83 files + this manifest still
  // have to be uploaded to the site repo (GitHub not connected
  // yet); until then the screen honestly says "not yet".
  static const String microplansUrl = '$siteBase/microplans.json';

  // --- My Data (user order, 19 Nov 2026): read-only gviz reads of
  // the EXISTING sheets — no sheet structure changed, no new write
  // endpoint. Each vaccinator only ever sees their OWN UC (see
  // MyDataService — the UC comes from the login only, there is no
  // UC picker anywhere in the app).
  // Summary by Vaccinator Chakwal — tabs Outreach / Fixed (live,
  // current month) + Out_YYYY-MM / Fix_YYYY-MM (month archives).
  static const String summarySheetId =
      '16YcZU2RwgWMtNjfjukHqsNTH-EW5T-TcZ5XNwgh79ls';
  // Attendance — tabs 'Chek-In' / 'Check-Out' (append-only).
  static const String attendanceSheetId =
      '1KAuJOL3WuYdp5YA4sD70kofeVkYPP3bJ5Rxro_0MUUc';
  // Vaccinator Records — tab 'Records' (service-record letters).
  static const String recordsSheetId =
      '11GHoNbiXzpLhQb6qb9Hyki1Z8bd-pCMMZRt-UFyG764';

  // --- Message Parents (user question, 19 Nov 2026): parent
  // numbers come from the EXISTING EMR sheet — the same sheet the
  // site's Verification Calls module reads (35 columns, Phone is
  // column 11). One tab per month ('Nov-2026' etc.). No sheet
  // structure changed, no new write endpoint. Only the logged-in
  // vaccinator's OWN UC rows are ever read (see MessageService).
  static const String emrSheetId =
      '13ZSu5fZQFarP4bXLQhJVETtGuYOEb8C9jrrdcvK1TAo';

  /// Month-tab names for the EMR sheet, in the site's own try
  /// order (index.html loadEmrData): 'Nov-2026', 'Nov 2026',
  /// 'November-2026', 'November 2026', 'Nov-26'.
  static List<String> emrMonthTabCandidates([DateTime? when]) {
    final now =
        (when ?? DateTime.now()).toUtc().add(const Duration(hours: 5));
    const short = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const full = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final s = short[now.month - 1];
    final f = full[now.month - 1];
    final y = now.year;
    final yy = (y % 100).toString().padLeft(2, '0');
    return ['$s-$y', '$s $y', '$f-$y', '$f $y', '$s-$yy'];
  }

  /// Today's date in PKT (UTC+5), yyyy-MM-dd.
  /// (Same logic as ApiHelpers.todayYmdPkt; kept here so every
  /// screen can call AppConfig.todayYmdPkt().)
  static String todayYmdPkt() {
    final pkt = DateTime.now().toUtc().add(const Duration(hours: 5));
    final m = pkt.month.toString().padLeft(2, '0');
    final d = pkt.day.toString().padLeft(2, '0');
    return '${pkt.year}-$m-$d';
  }

  static String gvizUrl(String sheet) =>
      'https://docs.google.com/spreadsheets/d/$masterSheetId'
      '/gviz/tq?tqx=out:json&sheet=${Uri.encodeComponent(sheet)}';

  /// gviz read of ANY sheet (not just the master sheet), with an
  /// optional Google Visualization query — used by My Data to ask
  /// the server for ONLY the logged-in vaccinator's UC rows
  /// (e.g. `select * where upper(B) = 'BAIGAL'`). The other UCs'
  /// rows never leave the server.
  static String gvizUrlFor(String sheetId, String sheet, [String? tq]) {
    var url = 'https://docs.google.com/spreadsheets/d/$sheetId'
        '/gviz/tq?tqx=out:json&sheet=${Uri.encodeComponent(sheet)}';
    if (tq != null && tq.isNotEmpty) {
      url += '&tq=${Uri.encodeComponent(tq)}';
    }
    return url;
  }

  /// gviz read with a server-side query AND headers=0 — used by
  /// the verify step only. headers=0 keeps the response tiny: with
  /// headers=1 the Location tab's labels balloon to ~240 KB (a
  /// sheet quirk — each label carries the whole column) and the
  /// full tab is ~800 KB, while headers=0 returns empty labels and
  /// only the matching rows (~1 KB). Rows come back positionally
  /// (A = first selected column), and the sheet's own header row
  /// arrives as a data row — callers must skip it.
  static String gvizVerifyUrl(String sheetId, String sheet, String tq) =>
      'https://docs.google.com/spreadsheets/d/$sheetId'
      '/gviz/tq?tqx=out:json&headers=0&sheet=${Uri.encodeComponent(sheet)}'
      '&tq=${Uri.encodeComponent(tq)}';

  // --- Rules (same as the web form) ---
  static const int monthlyLeaveMax = 2;
  static const int yearlyLeaveMax = 24;
  static const int lateCutoffHour = 10; // 10:00 AM PKT
  static const Duration backgroundInterval = Duration(minutes: 30);
  static const int verifyAttempts = 5;
  static const Duration verifyDelay = Duration(milliseconds: 1800);

  // --- Colours (EPI dashboard v14.22: dark green + gold) ---
  static const Color darkGreen = Color(0xFF0D5C3D);
  static const Color midGreen = Color(0xFF1A8A5C);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color gold = Color(0xFFC9A227);
  static const Color danger = Color(0xFFC62828);
  static const Color success = Color(0xFF2E7D32);
  static const Color ink = Color(0xFF222222);

  static const List<String> antigens = [
    'BCG',
    'Penta-I',
    'Penta-II',
    'Penta-III',
    'MR-1',
    'MR-II',
    'DTP',
  ];
}
