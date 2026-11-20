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

  Future<List<Map<String, dynamic>>> loadLocationRowsToday() async {
    try {
      return await readTab('Location');
    } catch (_) {
      return [];
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
        final rows = await readTab('Location');
        for (final r in rows) {
          final rn = (pick(r, ['name']) ?? '').trim().toLowerCase();
          final ru = ApiHelpers.normUserKey(pick(r, ['username']) ?? '');
          final samePerson =
              (key.isNotEmpty && ru.isNotEmpty && key == ru) ||
                  (nm.isNotEmpty && rn.isNotEmpty && nm == rn);
          if (!samePerson) continue;
          final rawTs = pick(r, ['timestamp', 'time']) ?? '';
          if (rawTs.isNotEmpty && rawTs == tsIso) return true;
          final ms = DateTime.tryParse(rawTs)?.millisecondsSinceEpoch;
          if (ms != null && tsMs != null && (ms - tsMs).abs() <= 60000) {
            final rLat = double.tryParse(pick(r, ['latitude', 'lat']) ?? '')
                ?.toStringAsFixed(6);
            final rLng = double.tryParse(
                    pick(r, ['longitude', 'long', 'lng']) ?? '')
                ?.toStringAsFixed(6);
            if (rLat == latS && rLng == lngS) return true;
          }
        }
      } catch (_) {}
      await Future.delayed(AppConfig.verifyDelay);
    }
    return false;
  }

  Future<bool> verifyLeave({
    required String name,
    required String username,
    required String leaveDate,
  }) async {
    final key = ApiHelpers.normUserKey(username);
    final nm = name.trim().toLowerCase();
    for (var a = 0; a < AppConfig.verifyAttempts; a++) {
      try {
        final rows = await loadLeaveRows();
        for (final r in rows) {
          final rn = (pick(r, ['name']) ?? '').trim().toLowerCase();
          final ru = ApiHelpers.normUserKey(pick(r, ['username']) ?? '');
          final raw = pick(r, ['leave date', 'leavedate', 'date']) ?? '';
          final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
          final ymd = m?.group(1) ?? '';
          if (ymd != leaveDate) continue;
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
