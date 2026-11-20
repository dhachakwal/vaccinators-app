import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/pending_item.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Sends the offline queue, ONE item at a time, in order.
/// An item leaves the queue ONLY after verify confirms its row.
/// New payload types (dailyReport / zeroEntry / mockLocation)
/// cannot be verified yet — the Apps Script does not handle them —
/// so they stay queued (max 5 attempts, then they wait for the next
/// sync) and the UI must say "queued", never "submitted". See GOAL.md.
/// A mockLocation report is queued the same way: the admin is told
/// as soon as the script + tab exist; until then the report waits
/// in the queue and the vaccinator is still blocked on the spot.
class SyncService {
  final ApiService api;
  final StorageService storage;
  SyncService(this.api, this.storage);

  static const Set<String> verifiableTypes = {'location', 'leave'};

  Future<bool> get hasNet async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.mobile) ||
        r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }

  /// Try to flush the whole queue. Returns (sent, stillPending).
  /// v1.0.1: items whose type has no server handler yet
  /// (dailyReport / zeroEntry / mockLocation) are SKIPPED — never
  /// posted, never breaking the loop. They stay queued for a later
  /// app version, while location/leave behind them can still sync.
  /// (Before this fix, syncAll posted them anyway, verify always
  /// failed, and the loop broke — one queued daily report blocked
  /// every location/leave behind it, so "sync" looked dead.)
  Future<(int, int)> syncAll() async {
    if (!await hasNet) return (0, storage.queue.length);
    var sent = 0;
    for (final item in List.of(storage.queue)) {
      if (item.attempts >= 5) continue;
      if (!verifiableTypes.contains(item.type)) continue;
      final ok = await api.submitAndVerify(item.payload);
      if (ok) {
        await storage.removeFromQueue(item.id);
        sent++;
      } else {
        await storage.updateQueued(item.withAttempt());
        // Stop on first failure — keep order, retry later.
        break;
      }
    }
    return (sent, storage.queue.length);
  }

  /// Submit one payload now. Returns:
  /// 'verified' (row confirmed), 'queued' (saved, will sync later),
  /// 'failed' (could not even save — caller shows the error).
  Future<String> submit(Map<String, dynamic> payload) async {
    final type = (payload['type'] ?? '').toString();
    final id =
        '$type|${payload['username']}|${payload['timestamp'] ?? payload['leaveDate'] ?? DateTime.now().toIso8601String()}';
    if (!await hasNet) {
      await storage.enqueue(PendingItem(
        id: id,
        type: type,
        payload: payload,
        createdAtIso: DateTime.now().toIso8601String(),
      ));
      return 'queued';
    }
    if (!verifiableTypes.contains(type)) {
      // Server cannot confirm this type yet — queue it honestly.
      await storage.enqueue(PendingItem(
        id: id,
        type: type,
        payload: payload,
        createdAtIso: DateTime.now().toIso8601String(),
      ));
      return 'queued';
    }
    final ok = await api.submitAndVerify(payload);
    if (ok) return 'verified';
    await storage.enqueue(PendingItem(
      id: id,
      type: type,
      payload: payload,
      createdAtIso: DateTime.now().toIso8601String(),
    ));
    return 'queued';
  }
}
