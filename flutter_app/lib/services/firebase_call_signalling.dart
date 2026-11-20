import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'call_service.dart';

/// V2 CALLING — Firebase Realtime Database signalling (IMPLEMENTED
/// 19 Nov 2026). This is the "postman" for call setup only: it
/// carries offer / answer / ICE candidates / hangup between the two
/// phones. It never sees or hears the call — media always flows
/// peer-to-peer (or via TURN), never through Firebase.
///
/// FREE-TIER DISCIPLINE (Spark plan — free, no card):
/// - One small node per ACTIVE call only, under
///   `/calls/<toUser>/<callId>/<pushId>`. Each signal is one tiny
///   JSON object (a few hundred bytes). No call history is kept:
///   [deleteCall] removes the caller's and the callee's node for
///   that call when it ends, so the 1 GB store never fills with
///   old calls. Spark never charges — it stops the service for the
///   rest of the month if a quota is exceeded — so keeping
///   signalling tiny is what keeps calls working all month.
/// - 100 simultaneous connections: 70 vaccinators + admin = max
///   71, so the cap fits (but only while the app is open — see
///   FCM note in the design doc).
/// - Presence: `/presence/<username>` = {online, ts}, removed
///   automatically with `onDisconnect()` when the app closes or
///   the network drops, so the Contacts screen can show who is
///   online. Presence is best-effort only — if it fails, calls
///   still work; the contact just shows as offline.
///
/// HONEST STATES (no fake "calling", ever):
/// - Firebase NOT configured (no google-services.json yet — the
///   user still has to create the Firebase project, see
///   files/Calling-v2-Design.md §10): [ensureInitialized] returns
///   false, [isConfigured] stays false, [CallService.signallingReady]
///   stays false, and the Contacts screen keeps showing
///   "Calling Not Set Up Yet". The rest of the app is unaffected.
/// - No network at call time: [send] throws a StateError with a
///   plain message, which CallService turns into a failed call —
///   never a "calling" screen that goes nowhere.
/// - A signal written BEFORE this phone started listening (e.g.
///   the caller rang while this app was closed) is ignored: the
///   listener drops anything older than when it attached. Without
///   FCM push, ringing only works while the app is open — that is
///   a documented V2 limit, not a bug.
///
/// DATABASE LAYOUT (see the rules JSON in the design doc §10):
///   /calls/<toUser>/<callId>/<pushId> = {kind, callId, from, to,
///       payload, ts}
///   /presence/<username> = {online: true, ts}
/// Usernames are roster usernames (mobile numbers) or 'admin'.
/// They are sanitised with [keyForUser] because Realtime Database
/// keys may not contain . # $ [ ] / or whitespace.
///
/// LANGUAGE: no user-facing strings are built here — errors are
/// short English StateErrors for CallService; the UI strings live
/// in lib/l10n/app_strings.dart (English + Urdu script only).
/// No Roman Urdu anywhere — standing rule, 19 Nov 2026.
class FirebaseRealtimeCallSignalling implements CallSignalling {
  // ---------- Firebase init (once, cached) ----------

  static Future<bool>? _initFuture;
  static bool? _initResult;

  /// True only after [Firebase.initializeApp] has succeeded.
  /// False before init is attempted, and false forever when the
  /// project is not configured (no google-services.json) — that
  /// is the normal state until the user does the §10 setup.
  static bool get isConfigured => _initResult == true;

  /// Initialise Firebase once and remember the result. Returns
  /// false (never throws) when the project is not configured or
  /// there is no network — calling simply stays unavailable.
  /// Safe to call at app boot (main.dart) and again later; the
  /// second call returns the cached answer immediately.
  static Future<bool> ensureInitialized() {
    if (_initResult != null) return Future.value(_initResult);
    return _initFuture ??= _doInit().then((v) {
      _initResult = v;
      return v;
    });
  }

  static Future<bool> _doInit() async {
    try {
      if (Firebase.apps.isEmpty) {
        // Reads google-services.json (Android) via the FlutterFire
        // plugin. Throws when the file / project is missing.
        await Firebase.initializeApp();
      }
      return true;
    } catch (_) {
      // Missing google-services.json, no network, or Firebase not
      // supported on this device. Not a crash — calling stays off.
      return false;
    }
  }

  /// Realtime Database keys may not contain . # $ [ ] / or
  /// whitespace. Roster usernames are mobiles (digits) or 'admin',
  /// so this is normally a no-op — it only guards against a
  /// strange username breaking every database path.
  static String keyForUser(String username) =>
      username.trim().replaceAll(RegExp(r'[.#$\[\]/\s]'), '_');

  // ---------- Instance state ----------

  final String myUsername;
  final String _myUser;
  FirebaseDatabase? _db;
  late final Future<void> _ready;
  final _controller = StreamController<CallSignal>.broadcast();
  StreamSubscription<DatabaseEvent>? _inboxSub;
  final Map<String, StreamSubscription<DatabaseEvent>> _callSubs = {};

  /// Wall-clock (ms) when this phone started listening. Signals
  /// older than this (minus a 5 s grace for in-flight messages)
  /// are leftovers from before — dropped, never replayed as a
  /// "new" call. See the class doc comment.
  int _listenStartedAt = 0;
  bool _disposed = false;

  FirebaseRealtimeCallSignalling({required this.myUsername})
      : _myUser = keyForUser(myUsername) {
    // Start Firebase + the inbox listener in the background. The
    // caller does not have to await this — [send] awaits [_ready]
    // itself and throws a clear error if Firebase never came up.
    _ready = _start();
  }

  Future<void> _start() async {
    final ok = await ensureInitialized();
    if (!ok || _disposed) return;
    _db = FirebaseDatabase.instance;
    _listenStartedAt = DateTime.now().millisecondsSinceEpoch;
    _subscribeInbox();
    await _markOnline();
  }

  // ---------- Incoming signals ----------

  @override
  Stream<CallSignal> get incoming => _controller.stream;

  void _subscribeInbox() {
    final db = _db;
    if (db == null) return;
    // A new child under /calls/<me> is a new call addressed to me.
    // onChildAdded also fires once for each call already there —
    // their signals are filtered by timestamp in _subscribeCall,
    // so stale calls never ring.
    _inboxSub = db.ref('calls/$_myUser').onChildAdded.listen((event) {
      final callId = event.snapshot.key;
      if (callId == null || _callSubs.containsKey(callId)) return;
      _subscribeCall(callId);
    }, onError: (_) {
      // Listener dropped (network lost). Nothing to do here —
      // CallService fails any in-progress call via send() errors,
      // and a fresh listener is attached next time a
      // FirebaseRealtimeCallSignalling is constructed.
    });
  }

  void _subscribeCall(String callId) {
    final db = _db;
    if (db == null) return;
    _callSubs[callId] =
        db.ref('calls/$_myUser/$callId').onChildAdded.listen((event) {
      final data = event.snapshot.value;
      if (data is! Map) return;
      try {
        final map = Map<String, dynamic>.from(data);
        final ts = (map['ts'] as num?)?.toInt() ?? 0;
        if (ts < _listenStartedAt - 5000) return; // stale, ignore.
        if (!_controller.isClosed) {
          _controller.add(CallSignal.fromJson(map));
        }
      } catch (_) {
        // A malformed signal (should not happen — rules validate
        // the shape) is skipped, never a crash.
      }
    }, onError: (_) {});
  }

  // ---------- Outgoing signals ----------

  @override
  Future<void> send(CallSignal signal) async {
    final db = await _dbOrThrow();
    await db
        .ref('calls/${keyForUser(signal.toUser)}/${signal.callId}')
        .push()
        .set(signal.toJson());
    // Ending the call: tidy my own inbox node for this call, so
    // no record of it stays in the free 1 GB store. The other
    // side deletes ITS node when it receives this hangup/decline
    // (each side only ever deletes its own inbox).
    if (signal.kind == 'hangup' ||
        signal.kind == 'decline' ||
        signal.kind == 'busy') {
      unawaited(deleteCall(signal.callId));
    }
  }

  Future<FirebaseDatabase> _dbOrThrow() async {
    await _ready;
    final db = _db;
    if (db == null) {
      throw StateError(
        'Call server is not set up yet — Firebase is not '
        'configured (google-services.json missing) or there is '
        'no network.',
      );
    }
    return db;
  }

  // ---------- Cleanup ----------

  /// Delete my own inbox node for one call (all its signals) and
  /// stop listening to it. Safe to call twice or for a call that
  /// is already gone — removing a missing node is a no-op.
  /// Called by CallService when a call ends, and by [send] after
  /// a hangup / decline / busy is sent.
  @override
  Future<void> deleteCall(String callId) async {
    await _callSubs.remove(callId)?.cancel();
    final db = _db;
    if (db == null) return;
    try {
      await db.ref('calls/$_myUser/$callId').remove();
    } catch (_) {
      // Network already gone — the node is tiny and will be
      // cleaned up next time this phone is online (or it simply
      // stays as one stale node; it holds no media or history).
    }
  }

  /// Mark this user online, with automatic removal when the app
  /// closes or the network drops. Best-effort: presence failing
  /// never blocks calls.
  Future<void> _markOnline() async {
    final db = _db;
    if (db == null) return;
    final ref = db.ref('presence/$_myUser');
    try {
      await ref.onDisconnect().remove();
      await ref.set({
        'online': true,
        'ts': ServerValue.timestamp,
      });
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _inboxSub?.cancel();
    for (final sub in _callSubs.values) {
      await sub.cancel();
    }
    _callSubs.clear();
    final db = _db;
    if (db != null) {
      try {
        await db.ref('presence/$_myUser').remove();
      } catch (_) {}
    }
    await _controller.close();
  }
}
