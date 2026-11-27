import 'package:flutter/foundation.dart';

export 'firebase_call_signalling.dart';

/// V2 CALLING — REMOVED FROM THE BUILD 27 Nov 2026 (user order,
/// APK size). The WebRTC + Firebase packages added ~19 MB of
/// phone libraries while calling still cannot work (the user's
/// Firebase project setup, design doc §10, is not done), so the
/// real implementation is parked and this stub keeps the same
/// public API with calling honestly unavailable:
/// [signallingReady] is always false, so the Contacts screen
/// shows "Calling Not Set Up Yet" exactly as before — no fake
/// call, no crash, and every other feature is untouched.
///
/// TO RESTORE CALLING (when the Firebase project exists):
/// 1. Copy the real files back from
///    hidden_files/call-code-backup-v1.0.7/ (call_service.dart,
///    firebase_call_signalling.dart, call_screen.dart,
///    pubspec.yaml, AndroidManifest.xml).
/// 2. Re-add flutter_webrtc + firebase_core + firebase_database
///    to pubspec.yaml (exact pins are in the backed-up pubspec).
/// 3. Rebuild, then do the two-phone test before telling anyone
///    calls work.
///
/// LANGUAGE: all user-facing strings live in
/// `lib/l10n/app_strings.dart` (English + Urdu script only).
/// NO Roman Urdu anywhere — standing rule, 19 Nov 2026.

/// One call. Screen share is a mode inside a call, not a separate
/// call — a call starts as audio or video, and either side can
/// start sharing their screen during it.
enum CallType { audio, video }

enum CallState {
  idle, // no call
  calling, // outgoing: ringing the other person
  ringing, // incoming: waiting for accept / decline
  connecting, // accepted, WebRTC handshake in progress
  inCall, // media flowing
  ended,
  failed,
}

/// A signalling message. Signalling carries ONLY connection setup
/// data (offer / answer / ICE candidates / hangup) — never media.
/// Media always flows peer-to-peer (or via TURN), never through
/// the signalling server.
class CallSignal {
  final String kind; // offer | answer | ice | hangup | decline | busy
  final String callId;
  final String fromUser; // roster username (mobile)
  final String toUser;
  final Map<String, dynamic> payload;

  const CallSignal({
    required this.kind,
    required this.callId,
    required this.fromUser,
    required this.toUser,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'callId': callId,
        'from': fromUser,
        'to': toUser,
        'payload': payload,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
      };

  factory CallSignal.fromJson(Map<String, dynamic> json) => CallSignal(
        kind: json['kind'] as String? ?? '',
        callId: json['callId'] as String? ?? '',
        fromUser: json['from'] as String? ?? '',
        toUser: json['to'] as String? ?? '',
        payload: Map<String, dynamic>.from(
            json['payload'] as Map? ?? const {}),
      );
}

/// Signalling transport — the postman for call setup only.
/// Implemented by [FirebaseRealtimeCallSignalling] (see
/// lib/services/firebase_call_signalling.dart). The interface is
/// deliberately tiny so the transport can be swapped without
/// touching the call logic: one stream of incoming signals + one
/// send method.
abstract class CallSignalling {
  /// All signals addressed to the logged-in user.
  Stream<CallSignal> get incoming;

  Future<void> send(CallSignal signal);

  /// Delete my own inbox node for one call (all its signals).
  /// CallService calls this when a call ends, so no call record
  /// stays in the free 1 GB store. Safe to call twice.
  Future<void> deleteCall(String callId);

  Future<void> dispose();
}

/// Data-saving limits. Video and screen share are capped on
/// purpose — the 20 GB/month TURN budget is the reason.
/// Estimates (relayed traffic only; direct P2P calls use no TURN):
/// - audio-only: ~18 MB/hour  -> 20 GB is ~1,100 relayed hours.
/// - video 360p: ~270-450 MB/hour -> 20 GB is ~45-75 relayed hours
///   (conservative published figure for standard video: 20-30 h).
/// - screen share, 5 fps: ~70-135 MB/hour -> ~150-280 relayed hours.
class CallConfig {
  CallConfig._();

  /// Video is capped at 360p. Never raise this without checking
  /// the TURN usage for the month first.
  static const int videoWidth = 640;
  static const int videoHeight = 360;
  static const int videoFps = 15;

  /// Screen share: low frame rate on purpose — a shared screen
  /// barely changes, so 5 fps is enough to follow it and it
  /// saves most of the TURN data a video call would use.
  static const int screenShareFps = 5;

  /// Give up ringing after this long; the caller sees "no answer".
  static const Duration ringTimeout = Duration(seconds: 45);

  /// ICE servers. STUN (free) first; TURN (Metered Open Relay,
  /// 20 GB/month free) only as a fallback when direct fails.
  /// TODO V2: do NOT hard-code TURN credentials. Fetch short-lived
  /// TURN credentials at runtime (Metered dashboard / your own
  /// tiny endpoint) and pass them in here. The placeholders below
  /// are the server addresses only — without credentials the TURN
  /// entries are ignored and relayed calls will fail.
  static Map<String, dynamic> iceServers({
    String? turnUsername,
    String? turnCredential,
  }) {
    final servers = <Map<String, dynamic>>[
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ],
      },
      // Metered Open Relay — free TURN, 20 GB/month.
      // TODO V2: fill in username/credential at runtime (see above).
      if (turnUsername != null && turnCredential != null)
        {
          'urls': [
            'turn:openrelay.metered.ca:80',
            'turn:openrelay.metered.ca:443',
            'turns:openrelay.metered.ca:443?transport=tcp',
          ],
          'username': turnUsername,
          'credential': turnCredential,
        },
    ];
    return {'iceServers': servers};
  }
}

/// Stub call service (27 Nov 2026): same public API as the real
/// WebRTC implementation, but every call action is a no-op and
/// [signallingReady] is always false. The Contacts screen checks
/// [signallingReady] before ever building this, so in practice
/// this class is never constructed — it exists so the calling UI
/// compiles unchanged until the real code is restored (see the
/// file header for the restore steps).
class CallService extends ChangeNotifier {
  /// Always false in this build: calling packages were removed
  /// for APK size (27 Nov 2026) and Firebase is not set up yet.
  static bool get signallingReady => false;

  /// Always false in this build — see [signallingReady].
  static Future<bool> ensureSignallingReady() async => false;

  CallService({
    required CallSignalling signalling,
    required String myUsername,
  });

  CallState get state => CallState.idle;
  CallType get type => CallType.audio;
  String? get peerUsername => null;
  String? get peerName => null;
  bool get isCaller => false;
  bool get isMuted => false;
  bool get isSpeakerOn => false;
  bool get isVideoOn => false;
  bool get isSharingScreen => false;
  String? get error => null;
  bool get inCall => false;

  Future<bool> startCall({
    required String peerUsername,
    required String peerName,
    required CallType type,
  }) async =>
      false;

  Future<bool> acceptCall() async => false;

  Future<void> declineCall() async {}

  void toggleMute() {}

  Future<void> toggleSpeaker() async {}

  void toggleVideo() {}

  Future<void> switchCamera() async {}

  Future<bool> startScreenShare() async => false;

  Future<void> stopScreenShare() async {}

  Future<void> endCall() async {}
}
