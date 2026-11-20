import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_item.dart';
import '../models/vaccinator.dart';

/// Local storage: login, cached roster, offline queue.
/// The queue is the offline-first heart of the app — nothing is ever
/// lost when the net drops, and nothing is ever double-sent.
class StorageService {
  static const _kUser = 'login_user';
  static const _kRoster = 'roster_cache';
  static const _kQueue = 'offline_queue';
  static const _kLastLocation = 'last_location_at';
  static const _kLastLat = 'last_verified_lat';
  static const _kLastLng = 'last_verified_lng';

  final SharedPreferences _prefs;
  StorageService(this._prefs);
  static Future<StorageService> init() async =>
      StorageService(await SharedPreferences.getInstance());

  // --- Login ---
  Future<void> saveLogin(Vaccinator v) async =>
      _prefs.setString(_kUser, jsonEncode(v.toJson()));
  Vaccinator? get login {
    final s = _prefs.getString(_kUser);
    if (s == null) return null;
    try {
      return Vaccinator.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_kUser);
  }

  // --- Roster cache (so login + dropdowns work offline after day 1) ---
  Future<void> saveRoster(List<Vaccinator> list) async =>
      _prefs.setString(
          _kRoster, jsonEncode(list.map((v) => v.toJson()).toList()));
  List<Vaccinator> get roster {
    final s = _prefs.getString(_kRoster);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => Vaccinator.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Offline queue ---
  List<PendingItem> get queue {
    final s = _prefs.getString(_kQueue);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => PendingItem.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<PendingItem> q) async =>
      _prefs.setString(
          _kQueue, jsonEncode(q.map((i) => i.toJson()).toList()));

  Future<void> enqueue(PendingItem item) async {
    final q = queue;
    if (q.any((i) => i.id == item.id)) return; // never queue twice
    q.add(item);
    await _saveQueue(q);
  }

  Future<void> removeFromQueue(String id) async {
    final q = queue..removeWhere((i) => i.id == id);
    await _saveQueue(q);
  }

  Future<void> updateQueued(PendingItem item) async {
    final q = queue;
    final i = q.indexWhere((e) => e.id == item.id);
    if (i >= 0) q[i] = item;
    await _saveQueue(q);
  }

  Future<void> setLastLocation(String iso) async =>
      _prefs.setString(_kLastLocation, iso);
  String? get lastLocationAt => _prefs.getString(_kLastLocation);

  /// Last VERIFIED fix — only set after the sheet confirms the row.
  /// Used by MockLocationService for the impossible-travel check.
  /// A mocked fix must never overwrite these (it is never verified).
  Future<void> setLastVerifiedFix(
      {required double lat, required double lng, required String iso}) async {
    await _prefs.setDouble(_kLastLat, lat);
    await _prefs.setDouble(_kLastLng, lng);
    await _prefs.setString(_kLastLocation, iso);
  }

  double? get lastVerifiedLat => _prefs.getDouble(_kLastLat);
  double? get lastVerifiedLng => _prefs.getDouble(_kLastLng);
}
