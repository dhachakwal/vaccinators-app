import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/vaccinator.dart';

/// Talks to the EXISTING backend only:
///  - POST payloads to the existing Apps Script endpoint (single POST —
///    the old web form posted twice and duplicated every row).
///  - GET roster / Location / Leave / Announcements via the public
///    gviz JSON read of the same sheet (no new server needed).
///  - Verify-before-success: a submit is only "done" when the row is
///    found back in the sheet. See verifyLocation / verifyLeave.
class ApiService {
  final http.Client _client;
  ApiService([http.Client? client]) : _client = client ?? http.Client();

  // ---------- POST (single path, never dual) ----------
  /// Sends ONE POST. Returns true if the HTTP call itself went out.
  /// This does NOT mean the row landed — call verify* afterwards.
  Future<bool> postPayload(Map<String, dynamic> payload) async {
    try {
      final res = await _client
          .post(
            Uri.parse(AppConfig.locationScriptUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  // ---------- gviz read ----------
  /// Reads a sheet tab via gviz and returns rows as header->value maps.
  /// Header matching is by "contains", like the web form's ix() helper,
  /// so a renamed/extra column does not break the app.
  Future<List<Map<String, dynamic>>> readTab(String sheet) async {
    final res = await _client
        .get(Uri.parse(AppConfig.gvizUrl(sheet)))
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

  /// Filtered gviz read for the verify step: runs [tq] on the
  /// server and returns ONLY the matching rows, mapped
  /// positionally onto [keys] (first selected column -> keys[0]).
  /// Uses headers=0 (see AppConfig.gvizVerifyUrl), so the response
  /// is ~1 KB instead of the whole tab. The sheet's own header row
  /// comes back as a data row and is skipped. Throws on any
  /// failure — callers fall back to the full [readTab] path.
  Future<List<Map<String, dynamic>>> readTabQueryPositional(
      String sheet, String tq, List<String> keys) async {
    final res = await _client
        .get(Uri.parse(
            AppConfig.gvizVerifyUrl(AppConfig.masterSheetId, sheet, tq)))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Sheet query failed');
    final body = res.body;
    final a = body.indexOf('{');
    final b = body.lastIndexOf('}');
    if (a < 0 || b < 0) throw Exception('Bad gviz body');
    final data = jsonDecode(body.substring(a, b + 1)) as Map<String, dynamic>;
    // A bad query still returns HTTP 200 with status "error" and no
    // table — treat it as a failure so the caller falls back to the
    // full-tab read instead of retrying empty results.
    if (data['status'] == 'error') throw Exception('Sheet query error');
    final table = data['table'] as Map<String, dynamic>?;
    if (table == null) return [];
    final rows = (table['rows'] as List?) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final cells = ((r as Map)['c'] as List?) ?? [];
      final m = <String, dynamic>{};
      for (var i = 0; i < keys.length; i++) {
        final cell = i < cells.length ? cells[i] : null;
        dynamic v = '';
        if (cell is Map) v = cell['v'] ?? cell['f'] ?? '';
        m[keys[i]] = v is String ? v : v.toString();
      }
      // headers=0: the sheet's own header row arrives as a data row.
      if ((m['timestamp'] ?? '').toString().trim().toLowerCase() ==
          'timestamp') {
        continue;
      }
      out.add(m);
    }
    return out;
  }

  /// WHERE fragment matching one vaccinator by username key OR
  /// name. [userColNumeric] is true when the sheet column holds
  /// numbers (Leave `Username`, D) — those need a bare number
  /// literal; text columns (Location `Username`, C, in headers=0
  /// mode) need a quoted string. The username key is digits
  /// without leading zeros, so for text columns both the key and
  /// the leading-zero form are tried.
  String _personClause({
    required String key,
    required String name,
    required String userCol,
    required String nameCol,
    required bool userColNumeric,
  }) {
    String esc(String s) => s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    final isDigits = RegExp(r'^\d+$').hasMatch(key);
    final parts = <String>[];
    if (key.isNotEmpty) {
      if (userColNumeric) {
        if (isDigits) parts.add('$userCol = $key');
      } else {
        parts.add("$userCol = '${esc(key)}'");
        if (isDigits) parts.add("$userCol = '${esc('0$key')}'");
      }
    }
    if (name.isNotEmpty) {
      parts.add("lower($nameCol) = '${esc(name.toLowerCase())}'");
    }
    return parts.join(' or ');
  }

  /// A LeaveDate cell value as yyyy-MM-dd. gviz returns real dates
  /// as `Date(2026,10,19)` (JS month is 0-based); formatted text
  /// is already yyyy-MM-dd. The old regex-only parse could never
  /// match the Date(...) form, so leave verify never succeeded
  /// for date-typed cells.
  static String leaveDateYmd(String raw) {
    final dm =
        RegExp(r'Date\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(raw);
    if (dm != null) {
      final y = int.parse(dm.group(1)!);
      final m = int.parse(dm.group(2)!) + 1;
      final d = int.parse(dm.group(3)!);
      return '$y-${m.toString().padLeft(2, '0')}-'
          '${d.toString().padLeft(2, '0')}';
    }
    return RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw)?.group(1) ?? '';
  }

  static String? pick(Map<String, dynamic> row, List<String> candidates) {
    for (final c in candidates) {
      if (row.containsKey(c)) return row[c]?.toString();
    }
    for (final k in row.keys) {
      for (final c in candidates) {
        if (k.contains(c)) return row[k]?.toString();
      }
    }
    return null;
  }

  Future<List<Vaccinator>> loadRoster() async {
    final rows = await readTab('All Vaccinators Profile');
    final out = <Vaccinator>[];
    for (final r in rows) {
      final name = pick(r, ['vaccinator name', 'name']);
      if (name == null || name.trim().isEmpty) continue;
      if (name.trim().toLowerCase() == 'vacant') continue;
      out.add(Vaccinator(
        tehsil: pick(r, ['tehsil']) ?? '',
        uc: pick(r, ['union council', 'uc']) ?? '',
        name: name.trim(),
        username: ApiHelpers.normUser(pick(r, ['username']) ?? ''),
        openingRemaining: double.tryParse(
                (pick(r, ['remaining leave', 'remaining']) ?? '')
                    .replaceAll(',', '')) ??
            24,
        availed: double.tryParse(
                (pick(r, ['availed', 'total casual']) ?? '')
                    .replaceAll(',', '')) ??
            0,
      ));
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> loadLeaveRows() async {
    try {
      return await readTab('Leave');
    } catch (_) {
      return [];
    }
  }

  /// Admin screens: ALL of today's Location rows. The old full-tab
  /// read (headers=1) silently truncates to the newest 83 rows —
  /// verified live 20 Nov 2026: the tab holds 4,753 rows but the
  /// headers=1 read returns only 83. On a heavy day today's rows
  /// can exceed that and vaccinators go missing from the map /
  /// late list. The server-side date filter returns every matching
  /// row (77 today, a few KB) and the headers=0 path has no
  /// 83-row cap (live: full `select *` returns all 4,753 rows).
  /// The date range matches the screens' own
  /// `startsWith(todayYmdPkt)` filter exactly, so their
  /// client-side filter is a no-op on these rows. Falls back to
  /// the full-tab read if the query fails, and to [] if that fails
  /// too — the admin screens never throw from this call.
  Future<List<Map<String, dynamic>>> loadLocationRowsToday() async {
    try {
      final today = AppConfig.todayYmdPkt();
      final p = today.split('-');
      final next = DateTime(
        int.parse(p[0]),
        int.parse(p[1]),
        int.parse(p[2]),
      ).add(const Duration(days: 1));
      final nextYmd = '${next.year}-'
          '${next.month.toString().padLeft(2, '0')}-'
          '${next.day.toString().padLeft(2, '0')}';
      final tq = "select A,B,C,D,E,F,G,H,I,J where A >= '$today' "
          "and A < '$nextYmd'";
      return await readTabQueryPositional('Location', tq, const [
        'timestamp',
        'name',
        'username',
        'tehsil',
        'uc',
        'address',
        'latitude',
        'longitude',
        'accuracy',
        'maps',
      ]);
    } catch (_) {
      try {
        return await readTab('Location');
      } catch (_) {
        return [];
      }
    }
  }

  /// Mock-location reports (type 'mockLocation', proposed new tab
  /// `MockLocation` — see GOAL.md). Empty until the Apps Script
  /// adds the tab; the admin screen must handle that gracefully.
  Future<List<Map<String, dynamic>>> loadMockLocationRows() async {
    try {
      return await readTab('MockLocation');
    } catch (_) {
      return [];
    }
  }

  // ---------- Verify-before-success ----------
  /// Location: match username + exact timestamp; fallback username +
  /// same instant (±60 s) + same GPS pin (6 dp). Same logic as the
  /// fixed web form's verifyLocationInSheet.
  /// v1.0.1: the server-side query fetches only this vaccinator's
  /// recent rows (~1 KB) instead of the whole 4,753-row tab on
  /// every attempt; a failed query falls back to the full read.
  Future<bool> verifyLocation({
    required String name,
    required String username,
    required String tsIso,
    required String lat,
    required String lng,
  }) async {
    final key = ApiHelpers.normUserKey(username);
    final nm = name.trim().toLowerCase();
    final latS = double.tryParse(lat)?.toStringAsFixed(6) ?? '';
    final lngS = double.tryParse(lng)?.toStringAsFixed(6) ?? '';
    final tsMs = DateTime.tryParse(tsIso)?.millisecondsSinceEpoch;
    for (var a = 0; a < AppConfig.verifyAttempts; a++) {
      try {
        final rows = await _verifyLocationRows(key, nm);
        for (final r in rows) {
          if (_locationRowMatches(r,
              key: key,
              nm: nm,
              tsIso: tsIso,
              tsMs: tsMs,
              latS: latS,
              lngS: lngS)) {
            return true;
          }
        }
      } catch (_) {}
      await Future.delayed(AppConfig.verifyDelay);
    }
    return false;
  }

  /// This vaccinator's recent Location rows, newest first.
  /// Filtered server-side; falls back to the full-tab read if the
  /// query fails or there is nothing to match on.
  Future<List<Map<String, dynamic>>> _verifyLocationRows(
      String key, String nm) async {
    final clause = _personClause(
      key: key,
      name: nm,
      userCol: 'C',
      nameCol: 'B',
      userColNumeric: false,
    );
    if (clause.isEmpty) return readTab('Location');
    try {
      final tq = 'select A,B,C,G,H where $clause order by A desc limit 50';
      return await readTabQueryPositional('Location', tq,
          const ['timestamp', 'name', 'username', 'latitude', 'longitude']);
    } catch (_) {
      return readTab('Location');
    }
  }

  bool _locationRowMatches(
    Map<String, dynamic> r, {
    required String key,
    required String nm,
    required String tsIso,
    required int? tsMs,
    required String latS,
    required String lngS,
  }) {
    final rn = (pick(r, ['name']) ?? '').trim().toLowerCase();
    final ru = ApiHelpers.normUserKey(pick(r, ['username']) ?? '');
    final samePerson = (key.isNotEmpty && ru.isNotEmpty && key == ru) ||
        (nm.isNotEmpty && rn.isNotEmpty && nm == rn);
    if (!samePerson) return false;
    final rawTs = pick(r, ['timestamp', 'time']) ?? '';
    if (rawTs.isNotEmpty && rawTs == tsIso) return true;
    final ms = DateTime.tryParse(rawTs)?.millisecondsSinceEpoch;
    if (ms != null && tsMs != null && (ms - tsMs).abs() <= 60000) {
      final rLat =
          double.tryParse(pick(r, ['latitude', 'lat']) ?? '')?.toStringAsFixed(6);
      final rLng = double.tryParse(pick(r, ['longitude', 'long', 'lng']) ?? '')
          ?.toStringAsFixed(6);
      if (rLat == latS && rLng == lngS) return true;
    }
    return false;
  }

  /// Leave verify, same filtered-query pattern as verifyLocation.
  /// Also fixes a real bug: LeaveDate cells are real dates, so
  /// gviz returns `Date(2026,10,19)` — the old yyyy-MM-dd regex
  /// could never match that form, so leave verify never
  /// succeeded for date-typed cells. See leaveDateYmd.
  Future<bool> verifyLeave({
    required String name,
    required String username,
    required String leaveDate,
  }) async {
    final key = ApiHelpers.normUserKey(username);
    final nm = name.trim().toLowerCase();
    for (var a = 0; a < AppConfig.verifyAttempts; a++) {
      try {
        final rows = await _verifyLeaveRows(key, nm);
        for (final r in rows) {
          final rn = (pick(r, ['name']) ?? '').trim().toLowerCase();
          final ru = ApiHelpers.normUserKey(pick(r, ['username']) ?? '');
          final raw = pick(r, ['leave date', 'leavedate', 'date']) ?? '';
          if (leaveDateYmd(raw) != leaveDate) continue;
          if ((key.isNotEmpty && ru.isNotEmpty && key == ru) ||
              (nm.isNotEmpty && rn.isNotEmpty && nm == rn)) {
            return true;
          }
        }
      } catch (_) {}
      await Future.delayed(AppConfig.verifyDelay);
    }
    return false;
  }

  /// This vaccinator's recent Leave rows, newest first.
  /// Filtered server-side; falls back to the full-tab read if the
  /// query fails or there is nothing to match on.
  Future<List<Map<String, dynamic>>> _verifyLeaveRows(
      String key, String nm) async {
    final clause = _personClause(
      key: key,
      name: nm,
      userCol: 'D',
      nameCol: 'C',
      userColNumeric: true,
    );
    if (clause.isEmpty) return loadLeaveRows();
    try {
      final tq = 'select A,B,C,D where $clause order by A desc limit 50';
      return await readTabQueryPositional(
          'Leave', tq, const ['timestamp', 'leavedate', 'name', 'username']);
    } catch (_) {
      return loadLeaveRows();
    }
  }

  /// Full submit flow for location/leave: single POST, then verify.
  /// Returns true ONLY when the row is confirmed in the sheet.
  Future<bool> submitAndVerify(Map<String, dynamic> payload) async {
    final sent = await postPayload(payload);
    if (!sent) return false;
    final type = (payload['type'] ?? '').toString();
    if (type == 'location') {
      return verifyLocation(
        name: (payload['name'] ?? '').toString(),
        username: (payload['username'] ?? '').toString(),
        tsIso: (payload['timestamp'] ?? '').toString(),
        lat: (payload['lat'] ?? '').toString(),
        lng: (payload['lng'] ?? '').toString(),
      );
    }
    if (type == 'leave') {
      return verifyLeave(
        name: (payload['name'] ?? '').toString(),
        username: (payload['username'] ?? '').toString(),
        leaveDate: (payload['leaveDate'] ?? '').toString(),
      );
    }
    // New payload types (dailyReport / zeroEntry) have no
    // verify path until the Apps Script adds them — the caller must
    // queue them instead of claiming success. See SyncService.
    return false;
  }

  void dispose() => _client.close();
}
