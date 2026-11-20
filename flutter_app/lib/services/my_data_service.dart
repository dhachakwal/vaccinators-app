import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/vaccinator.dart';
import 'api_service.dart';
import 'uc_facility_map.dart';

/// MY DATA — "sirf apna data" (user order, 19 Nov 2026 — PRIVACY RULE).
///
/// Every vaccinator sees the site's data for THEIR OWN UC inside the
/// app — and ONLY their own UC's data, never another vaccinator's or
/// another UC's. This is a privacy rule, not a filter preference.
///
/// HOW IT IS ENFORCED (see also design doc §3C):
/// 1. The UC comes ONLY from the logged-in [Vaccinator] object
///    (login -> profile row -> UC). There is NO UC picker, NO search
///    box and NO "all UCs" view anywhere in My Data — the screen
///    does not even accept a UC as input.
/// 2. Where the sheet HAS a UC column (Summary Outreach tab,
///    Attendance Chek-In/Check-Out tabs), the gviz query itself asks
///    the server for only that UC's rows
///    (`select * where upper(B) = 'BAIGAL'`) — the other UCs' rows
///    never leave the server at all.
/// 3. Where the sheet has NO UC column, rows are filtered in memory
///    immediately and the rest are dropped — never cached, never
///    displayed: Vaccinator Records + Leave are matched by the
///    logged-in username (name as fallback, like the site does);
///    the Fixed tab lists FACILITIES, so each facility is linked to
///    its UC with the site's own SV_FAC_UC map and only my UC's
///    facilities are kept.
/// 4. The offline cache stores ONLY the filtered own-UC bundle.
/// 5. Admin views (Live Map, Late/Missing list) are untouched and
///    stay admin-only — vaccinators never see them.
///
/// SOURCES (all existing sheets, read-only via gviz — NO sheet
/// structure changed, NO new write endpoint):
/// (a) Attendance — Attendance sheet, tabs 'Chek-In' / 'Check-Out'
///     (columns: SrNo, District, Tehsil, Union Council (UC),
///     Vaccinator Name, Username, Check-In/Out Time, Status).
/// (b) My doses by antigen — Summary sheet, Outreach tab (live) or
///     Out_YYYY-MM archive: the row whose Name IS my UC (outreach
///     doses in a UC are that UC's vaccinator's work). 21 antigens.
/// (c) My UC summary — (b) Outreach + Fixed for my UC: the Fixed
///     tab lists FACILITIES, so each facility is linked to its UC
///     with the site's own SV_FAC_UC map (see uc_facility_map.dart)
///     and only my UC's facilities are summed.
/// (d) Service record — Vaccinator Records sheet, tab 'Records'
///     (Date | Username | Name | Type | Ref No. | Subject | Details
///     | Status | Issued By). Matched by username, name fallback.
/// (e) Leave status — master sheet 'Leave' tab (existing
///     ApiService.loadLeaveRows) + the profile leave balance.
/// The EMR sheet is NOT used here: its rows are per-child and have
/// no vaccinator column, so they cannot say what ONE vaccinator did.
///
/// HONEST LIMITS: the three sheets must be shared "Anyone with the
/// link can view" like the master sheet, or gviz returns an error
/// and that section shows "could not load" instead of pretending.
/// The app's own Daily Report submissions live in the PROPOSED
/// DailyReport tab (not live yet — see GOAL.md); until it exists,
/// (b) is the Summary sheet's month-to-date figure, which is the
/// official record of the same doses.
class MyDataMonth {
  final int year;
  final int month;
  const MyDataMonth(this.year, this.month);

  String get key =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// Live tabs for the current month, archive tabs for past months.
  String get outreachTab => isCurrent ? 'Outreach' : 'Out_$key';
  String get fixedTab => isCurrent ? 'Fixed' : 'Fix_$key';

  bool get isCurrent {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5));
    return now.year == year && now.month == month;
  }

  static const _en = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];
  static const _ur = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی',
    'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
  ];

  String get labelEn => '${_en[month - 1]} $year';
  String get labelUr => '${_ur[month - 1]} $year';

  /// Current month + the two previous months (the months that have
  /// Summary archive tabs: Out_YYYY-MM / Fix_YYYY-MM).
  static List<MyDataMonth> available() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5));
    final out = <MyDataMonth>[];
    var y = now.year;
    var m = now.month;
    for (var i = 0; i < 3; i++) {
      out.add(MyDataMonth(y, m));
      m--;
      if (m == 0) {
        m = 12;
        y--;
      }
    }
    return out;
  }
}

/// The 21 HMIS antigen columns of the Summary sheet, in sheet order.
/// The app's 7 antigens map onto these (see [appAntigenDoses]).
const List<String> summaryAntigens = [
  'BCG', 'OPV0', 'Penta1', 'Pneumo1', 'OPV1', 'OPV2', 'OPV3', 'Penta2',
  'Pneumo2', 'Penta3', 'Pneumo3', 'IPV', 'Measles1', 'Measles2', 'HepB',
  'Rota1', 'Rota2', 'IPV2', 'DPT Booster', 'TCV', 'HPV',
];

/// HMIS antigen -> the app's Daily Report antigen.
const Map<String, String> appAntigenMap = {
  'BCG': 'BCG',
  'Penta1': 'Penta-I',
  'Penta2': 'Penta-II',
  'Penta3': 'Penta-III',
  'Measles1': 'MR-1',
  'Measles2': 'MR-II',
  'DPT Booster': 'DTP',
};

class MyAttendanceDay {
  final String date; // as in the sheet, e.g. 11/18/2026
  final String checkIn; // e.g. 10:40:56 AM (empty if none)
  final String checkOut;
  const MyAttendanceDay(
      {required this.date, required this.checkIn, required this.checkOut});

  Map<String, dynamic> toJson() =>
      {'date': date, 'checkIn': checkIn, 'checkOut': checkOut};
  factory MyAttendanceDay.fromJson(Map<String, dynamic> j) =>
      MyAttendanceDay(
        date: (j['date'] ?? '').toString(),
        checkIn: (j['checkIn'] ?? '').toString(),
        checkOut: (j['checkOut'] ?? '').toString(),
      );
}

class MyRecordRow {
  final String date;
  final String type; // Explanation / Show Cause / Warning / Notice / Appreciation
  final String refNo;
  final String subject;
  final String status; // Pending / Replied / Closed
  final String issuedBy;
  const MyRecordRow({
    required this.date,
    required this.type,
    required this.refNo,
    required this.subject,
    required this.status,
    required this.issuedBy,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'type': type,
        'refNo': refNo,
        'subject': subject,
        'status': status,
        'issuedBy': issuedBy,
      };
  factory MyRecordRow.fromJson(Map<String, dynamic> j) => MyRecordRow(
        date: (j['date'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        refNo: (j['refNo'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        issuedBy: (j['issuedBy'] ?? '').toString(),
      );
}

class MyLeaveRow {
  final String date; // yyyy-MM-dd
  final String type;
  const MyLeaveRow({required this.date, required this.type});

  Map<String, dynamic> toJson() => {'date': date, 'type': type};
  factory MyLeaveRow.fromJson(Map<String, dynamic> j) => MyLeaveRow(
        date: (j['date'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
      );
}

/// Everything My Data shows for ONE vaccinator's OWN UC, for one
/// month. Only this (already filtered) bundle is ever cached.
class MyDataBundle {
  final String monthKey;
  final String uc;
  final List<MyAttendanceDay> attendance;
  final Map<String, int> outreachDoses; // 21 antigens, my UC, Outreach
  final int outreachTotal;
  final Map<String, int> fixedDoses; // 21 antigens, my UC's facilities
  final int fixedTotal;
  final List<(String, int)> fixedFacilities; // (facility name, total)
  final List<MyRecordRow> records;
  final List<MyLeaveRow> leaves;
  final bool hadError; // true when live load failed and no cache existed

  const MyDataBundle({
    required this.monthKey,
    required this.uc,
    required this.attendance,
    required this.outreachDoses,
    required this.outreachTotal,
    required this.fixedDoses,
    required this.fixedTotal,
    required this.fixedFacilities,
    required this.records,
    required this.leaves,
    this.hadError = false,
  });

  factory MyDataBundle.empty(String monthKey, String uc,
          {bool hadError = false}) =>
      MyDataBundle(
        monthKey: monthKey,
        uc: uc,
        attendance: const [],
        outreachDoses: const {},
        outreachTotal: 0,
        fixedDoses: const {},
        fixedTotal: 0,
        fixedFacilities: const [],
        records: const [],
        leaves: const [],
        hadError: hadError,
      );

  /// My doses by antigen in the app's 7 antigen names.
  Map<String, int> get appAntigenDoses {
    final out = <String, int>{};
    appAntigenMap.forEach((hmis, app) {
      out[app] = outreachDoses[hmis] ?? 0;
    });
    return out;
  }

  int get presentDays => attendance
      .where((d) => d.checkIn.isNotEmpty)
      .length;

  Map<String, dynamic> toJson() => {
        'monthKey': monthKey,
        'uc': uc,
        'attendance': attendance.map((d) => d.toJson()).toList(),
        'outreachDoses': outreachDoses,
        'outreachTotal': outreachTotal,
        'fixedDoses': fixedDoses,
        'fixedTotal': fixedTotal,
        'fixedFacilities':
            fixedFacilities.map((f) => [f.$1, f.$2]).toList(),
        'records': records.map((r) => r.toJson()).toList(),
        'leaves': leaves.map((l) => l.toJson()).toList(),
      };

  factory MyDataBundle.fromJson(Map<String, dynamic> j) {
    Map<String, int> intMap(dynamic v) {
      final out = <String, int>{};
      if (v is Map) {
        v.forEach((k, val) {
          out[k.toString()] = (val as num?)?.toInt() ?? 0;
        });
      }
      return out;
    }

    return MyDataBundle(
      monthKey: (j['monthKey'] ?? '').toString(),
      uc: (j['uc'] ?? '').toString(),
      attendance: ((j['attendance'] as List?) ?? [])
          .map((e) => MyAttendanceDay.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      outreachDoses: intMap(j['outreachDoses']),
      outreachTotal: (j['outreachTotal'] as num?)?.toInt() ?? 0,
      fixedDoses: intMap(j['fixedDoses']),
      fixedTotal: (j['fixedTotal'] as num?)?.toInt() ?? 0,
      fixedFacilities: ((j['fixedFacilities'] as List?) ?? [])
          .map((e) {
            final l = e as List;
            return (
              l.isNotEmpty ? l[0].toString() : '',
              l.length > 1 ? (l[1] as num?)?.toInt() ?? 0 : 0
            );
          })
          .toList(),
      records: ((j['records'] as List?) ?? [])
          .map((e) => MyRecordRow.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
      leaves: ((j['leaves'] as List?) ?? [])
          .map((e) => MyLeaveRow.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class MyDataService {
  final http.Client _client;
  MyDataService([http.Client? client]) : _client = client ?? http.Client();

  String _cacheKey(Vaccinator user, MyDataMonth month) =>
      'mydata_cache_${ApiHelpers.normUserKey(user.username)}_'
      '${user.uc.trim().toLowerCase()}_${month.key}';

  /// Loads My Data for the logged-in vaccinator's OWN UC only.
  /// Returns (bundle, fromCache). On any live failure the last
  /// cached own-UC bundle is returned instead — never a blank
  /// screen, never another UC's data.
  Future<(MyDataBundle, bool)> fetchMyData(
      Vaccinator user, MyDataMonth month) async {
    final uc = user.uc.trim();
    var okSections = 0;
    var attendance = <MyAttendanceDay>[];
    var outreachDoses = <String, int>{};
    var outreachTotal = 0;
    var fixedDoses = <String, int>{};
    var fixedTotal = 0;
    var fixedFacilities = <(String, int)>[];
    var records = <MyRecordRow>[];
    var leaves = <MyLeaveRow>[];

    try {
      attendance = await _fetchAttendance(user, month);
      okSections++;
    } catch (_) {}
    try {
      final r = await _fetchSummaryRow(
          AppConfig.summarySheetId, month.outreachTab, uc);
      outreachDoses = r.$1;
      outreachTotal = r.$2;
      okSections++;
    } catch (_) {}
    try {
      final f = await _fetchFixedForUc(month.fixedTab, uc);
      fixedDoses = f.$1;
      fixedTotal = f.$2;
      fixedFacilities = f.$3;
      okSections++;
    } catch (_) {}
    try {
      records = await _fetchRecords(user);
      okSections++;
    } catch (_) {}
    try {
      leaves = await _fetchLeaves(user, month);
      okSections++;
    } catch (_) {}

    if (okSections == 0) {
      final cached = await _cached(user, month);
      if (cached != null) return (cached, true);
      return (MyDataBundle.empty(month.key, uc, hadError: true), true);
    }

    final bundle = MyDataBundle(
      monthKey: month.key,
      uc: uc,
      attendance: attendance,
      outreachDoses: outreachDoses,
      outreachTotal: outreachTotal,
      fixedDoses: fixedDoses,
      fixedTotal: fixedTotal,
      fixedFacilities: fixedFacilities,
      records: records,
      leaves: leaves,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _cacheKey(user, month), jsonEncode(bundle.toJson()));
    return (bundle, false);
  }

  Future<MyDataBundle?> _cached(
      Vaccinator user, MyDataMonth month) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(user, month));
      if (raw == null) return null;
      return MyDataBundle.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  // ---------- gviz helpers (same parse as ApiService.readTab) ----------

  Future<List<Map<String, dynamic>>> _readGviz(String url) async {
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Sheet read failed');
    final body = res.body;
    final a = body.indexOf('{');
    final b = body.lastIndexOf('}');
    if (a < 0 || b < 0) throw Exception('Bad gviz body');
    final data = jsonDecode(body.substring(a, b + 1)) as Map<String, dynamic>;
    final table = data['table'] as Map<String, dynamic>?;
    if (table == null) return [];
    final cols = (table['cols'] as List)
        .map((c) => ((c as Map)['label'] ?? '').toString().toLowerCase().trim())
        .toList();
    final rows = (table['rows'] as List?) ?? [];
    return rows.map((r) {
      final cells = ((r as Map)['c'] as List?) ?? [];
      final m = <String, dynamic>{};
      for (var i = 0; i < cols.length; i++) {
        final cell = i < cells.length ? cells[i] : null;
        dynamic v = '';
        if (cell is Map) {
          v = cell['v'] ?? cell['f'] ?? '';
        }
        m[cols[i]] = v;
      }
      return m;
    }).toList();
  }

  /// gviz read that asks the SERVER for only one UC's rows.
  /// [ucColumnLetter]: Summary Name = B, Attendance UC = D.
  /// The query is case-insensitive (upper on both sides) and the
  /// UC value is quoted/escaped — no other UC's rows are returned.
  Future<List<Map<String, dynamic>>> _readUcRows(
      String sheetId, String tab, String ucColumnLetter, String uc) async {
    final safe = uc.replaceAll("'", "\\'");
    final tq = "select * where upper($ucColumnLetter) = "
        "'${safe.toUpperCase()}'";
    return _readGviz(AppConfig.gvizUrlFor(sheetId, tab, tq));
  }

  static int _num(dynamic v) =>
      (double.tryParse(v.toString().replaceAll(',', '')) ?? 0).toInt();

  /// One Summary row (Outreach) for my UC: 21 antigen doses + Total.
  /// Returns (doses, total). Empty map + 0 when my UC has no row.
  Future<(Map<String, int>, int)> _fetchSummaryRow(
      String sheetId, String tab, String uc) async {
    final rows = await _readUcRows(sheetId, tab, 'B', uc);
    if (rows.isEmpty) return (<String, int>{}, 0);
    final r = rows.first;
    final doses = <String, int>{};
    for (final a in summaryAntigens) {
      doses[a] = _num(ApiService.pick(r, [a.toLowerCase()]) ?? '0');
    }
    final total = _num(ApiService.pick(r, ['total']) ?? '0');
    return (doses, total);
  }

  /// Fixed doses for MY UC only: the Fixed tab lists facilities,
  /// so each facility is linked to its UC with the site's own
  /// SV_FAC_UC map and only my UC's facilities are summed.
  /// Returns (doses by antigen, total, per-facility totals).
  Future<(Map<String, int>, int, List<(String, int)>)> _fetchFixedForUc(
      String tab, String uc) async {
    final rows =
        await _readGviz(AppConfig.gvizUrlFor(AppConfig.summarySheetId, tab));
    final myUc = uc.trim().toUpperCase();
    final doses = <String, int>{for (final a in summaryAntigens) a: 0};
    var total = 0;
    final facilities = <(String, int)>[];
    for (final r in rows) {
      final name = (ApiService.pick(r, ['name']) ?? '').toString();
      if (name.trim().isEmpty) continue;
      final rowUc = kFacilityToUc[normFacilityName(name)] ?? '';
      if (rowUc.toUpperCase() != myUc) continue; // not my UC: drop
      var rowTotal = 0;
      for (final a in summaryAntigens) {
        final v = _num(ApiService.pick(r, [a.toLowerCase()]) ?? '0');
        doses[a] = (doses[a] ?? 0) + v;
        rowTotal += v;
      }
      total += rowTotal;
      facilities.add((name.trim(), rowTotal));
    }
    return (doses, total, facilities);
  }

  /// (a) My attendance this month: Chek-In + Check-Out tabs,
  /// server-filtered to my UC, then grouped by date and filtered
  /// to the selected month. Days are shown newest first.
  Future<List<MyAttendanceDay>> _fetchAttendance(
      Vaccinator user, MyDataMonth month) async {
    final uc = user.uc.trim();
    final ins = await _readUcRows(
        AppConfig.attendanceSheetId, 'Chek-In', 'D', uc);
    final outs = await _readUcRows(
        AppConfig.attendanceSheetId, 'Check-Out', 'D', uc);
    final byDate = <String, (String, String)>{};

    String? dateOf(String raw) {
      final m = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(raw);
      if (m != null) {
        return '${m.group(3)}-${m.group(1)!.padLeft(2, '0')}-'
            '${m.group(2)!.padLeft(2, '0')}';
      }
      final iso =
          RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
      if (iso != null) return iso.group(0);
      return null;
    }

    String timeOf(String raw) {
      final m = RegExp(r'(\d{1,2}:\d{2}(?::\d{2})?\s*[AP]M)',
              caseSensitive: false)
          .firstMatch(raw);
      return m?.group(1) ?? raw;
    }

    for (final r in ins) {
      final raw =
          (ApiService.pick(r, ['check-in time', 'check in time', 'time']) ??
                  '')
              .toString();
      final d = dateOf(raw);
      if (d == null || !d.startsWith(month.key)) continue;
      final cur = byDate[d] ?? ('', '');
      byDate[d] = (timeOf(raw), cur.$2);
    }
    for (final r in outs) {
      final raw =
          (ApiService.pick(r, ['check-out time', 'check out time', 'time']) ??
                  '')
              .toString();
      final d = dateOf(raw);
      if (d == null || !d.startsWith(month.key)) continue;
      final cur = byDate[d] ?? ('', '');
      byDate[d] = (cur.$1, timeOf(raw));
    }
    final days = byDate.entries
        .map((e) => MyAttendanceDay(
            date: e.key, checkIn: e.value.$1, checkOut: e.value.$2))
        .toList();
    days.sort((a, b) => b.date.compareTo(a.date));
    return days;
  }

  /// (d) My service record: the Records sheet has NO UC column, so
  /// rows are matched in memory by the logged-in username (mobile /
  /// OR code, normalised like the site does) with the name as a
  /// fallback. Every non-matching row is dropped immediately —
  /// never cached, never displayed.
  Future<List<MyRecordRow>> _fetchRecords(Vaccinator user) async {
    final rows = await _readGviz(
        AppConfig.gvizUrlFor(AppConfig.recordsSheetId, 'Records'));
    final key = ApiHelpers.normUserKey(user.username);
    final nm = user.name.trim().toLowerCase();
    final out = <MyRecordRow>[];
    for (final r in rows) {
      final ru = ApiHelpers.normUserKey(
          (ApiService.pick(r, ['username']) ?? '').toString());
      final rn = (ApiService.pick(r, ['name']) ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final mine = (key.isNotEmpty && ru.isNotEmpty && key == ru) ||
          (nm.isNotEmpty && rn.isNotEmpty && nm == rn);
      if (!mine) {
        continue; // not mine: drop, never stored
      }
      out.add(MyRecordRow(
        date: (ApiService.pick(r, ['date']) ?? '').toString(),
        type: (ApiService.pick(r, ['type']) ?? '').toString(),
        refNo: (ApiService.pick(r, ['ref no', 'ref']) ?? '').toString(),
        subject: (ApiService.pick(r, ['subject']) ?? '').toString(),
        status: (ApiService.pick(r, ['status']) ?? '').toString(),
        issuedBy: (ApiService.pick(r, ['issued by']) ?? '').toString(),
      ));
    }
    return out;
  }

  /// (e) My leave this month: master sheet 'Leave' tab, same
  /// username/name matching as the Leave screen, month-filtered.
  /// (The Leave tab has no confirmed UC column, so it is matched
  /// by username like the Records sheet — see §3C.)
  Future<List<MyLeaveRow>> _fetchLeaves(
      Vaccinator user, MyDataMonth month) async {
    final rows = await ApiService().loadLeaveRows();
    final key = ApiHelpers.normUserKey(user.username);
    final nm = user.name.trim().toLowerCase();
    final out = <MyLeaveRow>[];
    for (final r in rows) {
      final ru = ApiHelpers.normUserKey(
          (ApiService.pick(r, ['username']) ?? '').toString());
      final rn = (ApiService.pick(r, ['name']) ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final mine = (key.isNotEmpty && ru.isNotEmpty && key == ru) ||
          (nm.isNotEmpty && rn.isNotEmpty && nm == rn);
      if (!mine) {
        continue;
      }
      final raw =
          (ApiService.pick(r, ['leave date', 'leavedate', 'date']) ?? '')
              .toString();
      final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
      final ymd = m?.group(1) ?? '';
      if (ymd.isEmpty || !ymd.startsWith(month.key)) continue;
      out.add(MyLeaveRow(
        date: ymd,
        type: (ApiService.pick(r, ['leave type', 'leavetype', 'type']) ??
                'Casual')
            .toString(),
      ));
    }
    return out;
  }

  void dispose() => _client.close();
}
