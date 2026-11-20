import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'firebase_call_signalling.dart';

export 'firebase_call_signalling.dart';

/// V2 CALLING — SKELETON, NOT YET TESTED END-TO-END (19 Nov 2026).
///
/// In-app 1-to-1 Audio Call + Video Call + Screen Share, via WebRTC.
/// Purpose (user order): when something needs explaining, share your
/// screen and explain it, or watch the other person's screen share.
///
/// SCOPE — app-to-app ONLY: both people must have the app, be
/// logged in (roster users only) and be online. Calls to outside
/// phone numbers are NOT in scope — that needs a paid PSTN gateway
/// (e.g. Twilio) and is deliberately not built here.
///
/// FREE-TIER DESIGN (verified 19 Nov 2026):
/// - WebRTC itself is free / open source, no licence.
/// - STUN is free (Google public STUN servers).
/// - TURN relay (Metered Open Relay) is 20 GB FREE PER MONTH
///   (not per day) — about 20-30 hours of relayed standard video.
///   Most calls connect directly peer-to-peer (STUN only, $0, no
///   TURN data at all); TURN is used only when a direct connection
///   fails (~10-20% of calls). So: audio is the default, video is
///   capped at 360p, screen share runs at low frame rate — see
///   [CallConfig] below. Never send 720p/1080p through TURN.
/// - Signalling: Firebase Realtime Database, Spark (free) plan —
///   100 simultaneous connections, 1 GB stored, 10 GB/month
///   downloads. 70 vaccinators + admin = at most 71 online, so the
///   100-connection cap fits. Signalling messages are a few KB per
///   call, so the 10 GB download quota is not the binding limit.
///   Call records MUST be deleted after each call ends (see
///   [CallSignalling] / the design doc) so the 1 GB store is not
///   filled with old calls. Spark shuts a product off for the rest
///   of the month if its quota is exceeded — it never charges, but
///   calls would stop, so keep signalling tiny.
///
/// WHAT IS REAL HERE vs WHAT IS A TODO:
/// - REAL: peer-connection setup, ICE servers, local media capture,
///   audio/video/screen-share track handling, call state machine,
///   in-call controls (mute / speaker / camera / screen share),
///   and the Firebase Realtime Database signalling itself
///   ([FirebaseRealtimeCallSignalling] — implemented 19 Nov 2026,
///   see lib/services/firebase_call_signalling.dart). The code is
///   complete; what is still missing is the USER's Firebase
///   project setup (create project, google-services.json — design
///   doc §10) and the two-phone test. Until then
///   [CallService.signallingReady] stays false and the Contacts
///   screen honestly says "Calling Not Set Up Yet".
/// - TODO: TURN credentials (fetch short-lived credentials at
///   runtime — never hard-code them), incoming-call push when the
///   app is closed (needs firebase_messaging / FCM — in-app
///   ringing only works while the app is open), the live
///   CallService in main.dart + incoming-call overlay, and a real
///   two-phone test. Do NOT tell the user calls work until that
///   test passes.
///
/// LANGUAGE: all user-facing strings live in
/// `lib/l10n/app_strings.dart` (English + Urdu script only —
/// merged from call_strings.dart, 19 Nov 2026).
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

/// Owns one call at a time (1-to-1 only in V2 — no group calls).
/// UI reads this through [ChangeNotifier] and shows
/// [CallScreen] for [CallState.calling]/[ringing]/[connecting]/
/// [inCall]. Call history is NOT stored in V2 (privacy — see the
/// design doc); only the live call exists in memory.
class CallService extends ChangeNotifier {
  /// True ONLY after Firebase initialised successfully
  /// (google-services.json present + reachable — see
  /// FirebaseRealtimeCallSignalling.isConfigured). The contacts
  /// screen checks this BEFORE building a CallService, so until
  /// the user's Firebase project is set up (design doc §10) it
  /// stays false and tapping a call button honestly says
  /// "Calling Not Set Up Yet" — never a crash, never a fake
  /// call. Call [ensureSignallingReady] at app boot (main.dart)
  /// or when the Calls screen opens, so the flag is true before
  /// the user taps a call button.
  static bool get signallingReady =>
      FirebaseRealtimeCallSignalling.isConfigured;

  /// Try to initialise Firebase signalling (once, cached).
  /// Returns true when calls can now be placed. Safe to call at
  /// boot and again later; a second call returns the cached
  /// answer immediately.
  static Future<bool> ensureSignallingReady() =>
      FirebaseRealtimeCallSignalling.ensureInitialized();

  final CallSignalling _signalling;
  final String _myUsername;

  CallService({
    required CallSignalling signalling,
    required String myUsername,
  })  : _signalling = signalling,
        _myUsername = myUsername {
    _signalling.incoming.listen(_onSignal, onError: _onSignalError);
  }

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _screenStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  CallState _state = CallState.idle;
  CallType _type = CallType.audio;
  String? _callId;
  String? _peerUsername;
  String? _peerName;
  bool _isCaller = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _videoOn = true;
  bool _sharingScreen = false;
  String? _error;
  Timer? _ringTimer;

  CallState get state => _state;
  CallType get type => _type;
  String? get peerUsername => _peerUsername;
  String? get peerName => _peerName;
  bool get isCaller => _isCaller;
  bool get isMuted => _muted;
  bool get isSpeakerOn => _speakerOn;
  bool get isVideoOn => _videoOn;
  bool get isSharingScreen => _sharingScreen;
  String? get error => _error;
  bool get inCall => _state == CallState.inCall;

  Future<void> _ensureRenderers() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  // ---------- Outgoing ----------

  /// Start a 1-to-1 call. [type] audio = voice only (cheapest,
  /// the default); video = camera on. Screen share is started
  /// later, inside the call, with [startScreenShare].
  /// Returns false (state = failed) if there is no network or the
  /// signalling send throws — the caller sees an error, never a
  /// fake "calling" screen that goes nowhere.
  Future<bool> startCall({
    required String peerUsername,
    required String peerName,
    required CallType type,
  }) async {
    if (_state != CallState.idle && _state != CallState.ended) {
      return false; // already in a call — V2 is 1-to-1 only.
    }
    _type = type;
    _peerUsername = peerUsername;
    _peerName = peerName;
    _isCaller = true;
    _callId = 'call_${DateTime.now().millisecondsSinceEpoch}_$_myUsername';
    _error = null;
    try {
      await _ensureRenderers();
      await _setupPeerConnection();
      await _getLocalMedia();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _signalling.send(CallSignal(
        kind: 'offer',
        callId: _callId!,
        fromUser: _myUsername,
        toUser: peerUsername,
        payload: {'type': type.name, 'sdp': offer.sdp},
      ));
      _setState(CallState.calling);
      _ringTimer = Timer(CallConfig.ringTimeout, () {
        if (_state == CallState.calling) {
          _fail('No answer — the other person did not pick up.');
        }
      });
      return true;
    } catch (e) {
      _fail('Could not start the call: $e');
      return false;
    }
  }

  // ---------- Incoming ----------

  void _onSignal(CallSignal signal) {
    switch (signal.kind) {
      case 'offer':
        _onIncomingOffer(signal);
      case 'answer':
        _onAnswer(signal);
      case 'ice':
        _onRemoteIce(signal);
      case 'hangup':
      case 'decline':
      case 'busy':
        if (signal.callId == _callId) _endCallLocally();
    }
  }

  void _onSignalError(Object e) {
    // Signalling dropped (e.g. network lost mid-call setup).
    // Never crash the app for this; surface it only if a call
    // was in progress.
    if (_state == CallState.calling ||
        _state == CallState.ringing ||
        _state == CallState.connecting) {
      _fail('Connection to the call server was lost.');
    }
  }

  /// An offer arrived: someone is calling. The UI shows the
  /// incoming-call screen (accept / decline) — nothing is
  /// answered automatically and the microphone/camera stay off
  /// until the user taps Accept.
  void _onIncomingOffer(CallSignal signal) {
    if (_state != CallState.idle && _state != CallState.ended) {
      // Busy: already in a call — tell the caller, do not interrupt.
      unawaited(_signalling.send(CallSignal(
        kind: 'busy',
        callId: signal.callId,
        fromUser: _myUsername,
        toUser: signal.fromUser,
      )));
      return;
    }
    _callId = signal.callId;
    _peerUsername = signal.fromUser;
    _peerName = signal.payload['callerName'] as String? ?? signal.fromUser;
    _type = (signal.payload['type'] as String?) == 'video'
        ? CallType.video
        : CallType.audio;
    _isCaller = false;
    final offerSdp = signal.payload['sdp'] as String?;
    _pendingOffer = offerSdp == null
        ? null
        : RTCSessionDescription(offerSdp, 'offer');
    _setState(CallState.ringing);
    _ringTimer = Timer(CallConfig.ringTimeout, () {
      if (_state == CallState.ringing) _endCallLocally();
    });
  }

  /// Accept the incoming call: get local media, then answer.
  Future<bool> acceptCall() async {
    if (_state != CallState.ringing || _callId == null) return false;
    try {
      await _ensureRenderers();
      await _setupPeerConnection();
      await _getLocalMedia();
      // The offer SDP was stored on the signal; the full answer
      // flow needs it — see _pendingOffer below.
      final offer = _pendingOffer;
      if (offer == null) {
        _fail('Call invitation expired. Ask the caller to try again.');
        return false;
      }
      await _pc!.setRemoteDescription(offer);
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      await _signalling.send(CallSignal(
        kind: 'answer',
        callId: _callId!,
        fromUser: _myUsername,
        toUser: _peerUsername!,
        payload: {'sdp': answer.sdp},
      ));
      _setState(CallState.connecting);
      return true;
    } catch (e) {
      _fail('Could not answer the call: $e');
      return false;
    }
  }

  RTCSessionDescription? _pendingOffer;

  Future<void> declineCall() async {
    if (_state != CallState.ringing || _callId == null) return;
    await _signalling.send(CallSignal(
      kind: 'decline',
      callId: _callId!,
      fromUser: _myUsername,
      toUser: _peerUsername ?? '',
    ));
    _endCallLocally();
  }

  // ---------- WebRTC plumbing ----------

  Future<void> _setupPeerConnection() async {
    // TODO V2: pass real TURN credentials from CallConfig.iceServers
    // once the runtime credential fetch exists. Until then only
    // STUN is configured, so direct calls work and relayed calls
    // (strict networks) will fail — that is expected pre-launch.
    _pc = await createPeerConnection(CallConfig.iceServers());
    _pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_callId == null || _peerUsername == null) return;
      unawaited(_signalling.send(CallSignal(
        kind: 'ice',
        callId: _callId!,
        fromUser: _myUsername,
        toUser: _peerUsername!,
        payload: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      )));
    };
    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams[0];
        if (_state == CallState.connecting) _setState(CallState.inCall);
        notifyListeners();
      }
    };
    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          _state == CallState.connecting) {
        _setState(CallState.inCall);
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _fail('Call connection was lost.');
      }
    };
  }

  Future<void> _getLocalMedia() async {
    final video = _type == CallType.video;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video
          ? {
              'width': CallConfig.videoWidth,
              'height': CallConfig.videoHeight,
              'frameRate': CallConfig.videoFps,
            }
          : false,
    });
    localRenderer.srcObject = _localStream;
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    _videoOn = video;
  }

  Future<void> _onAnswer(CallSignal signal) async {
    if (_pc == null || signal.callId != _callId) return;
    final sdp = signal.payload['sdp'] as String?;
    if (sdp == null) return;
    await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'));
    _setState(CallState.connecting);
  }

  Future<void> _onRemoteIce(CallSignal signal) async {
    if (_pc == null || signal.callId != _callId) return;
    final candidate = signal.payload['candidate'] as String?;
    if (candidate == null) return;
    await _pc!.addCandidate(RTCIceCandidate(
      candidate,
      signal.payload['sdpMid'] as String?,
      signal.payload['sdpMLineIndex'] as int?,
    ));
  }

  // ---------- In-call controls ----------

  /// Mute / unmute the microphone. The other side sees you muted.
  void toggleMute() {
    _muted = !_muted;
    for (final t in _localStream?.getAudioTracks() ?? []) {
      t.enabled = !_muted;
    }
    notifyListeners();
  }

  /// Speaker on/off (earpiece vs loudspeaker).
  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await Helper.setSpeakerphoneOn(_speakerOn);
    notifyListeners();
  }

  /// Camera on/off during a video call. Audio keeps going.
  void toggleVideo() {
    if (_type != CallType.video) return;
    _videoOn = !_videoOn;
    for (final t in _localStream?.getVideoTracks() ?? []) {
      t.enabled = _videoOn;
    }
    notifyListeners();
  }

  /// Switch front / back camera. Best-effort: on phones without a
  /// second camera this is a no-op, never a crash.
  Future<void> switchCamera() async {
    try {
      final tracks = _localStream?.getVideoTracks() ?? [];
      if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
    } catch (_) {
      // No second camera (or not supported) — ignore silently.
    }
  }

  /// Start sharing THIS phone's screen with the other person.
  /// Android shows the system screen-capture prompt first — the
  /// share only starts if the user allows it there. Runs at
  /// [CallConfig.screenShareFps] on purpose (saves TURN data).
  /// The camera video track is replaced by the screen track, so
  /// the other side sees the screen instead of the camera.
  /// Returns false if the user cancels the system prompt.
  Future<bool> startScreenShare() async {
    if (_pc == null || _sharingScreen) return false;
    try {
      _screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {'frameRate': CallConfig.screenShareFps},
        'audio': false,
      });
      final screenTrack = _screenStream!.getVideoTracks().first;
      final senders = await _pc!.getSenders();
      final sender = senders
          .where((s) => s.track?.kind == 'video')
          .firstOrNull;
      if (sender != null) {
        await sender.replaceTrack(screenTrack);
      } else {
        await _pc!.addTrack(screenTrack, _screenStream!);
      }
      // If the user stops sharing from the system notification,
      // the track ends — stop cleanly instead of hanging.
      screenTrack.onEnded = () => unawaited(stopScreenShare());
      _sharingScreen = true;
      notifyListeners();
      return true;
    } catch (_) {
      // System prompt cancelled, or screen capture unavailable
      // on this phone — not an error, just no share.
      return false;
    }
  }

  /// Stop sharing the screen and go back to the camera (video
  /// calls) or to audio only. The call itself keeps going.
  Future<void> stopScreenShare() async {
    if (!_sharingScreen) return;
    try {
      final cameraTracks = _localStream?.getVideoTracks() ?? [];
      final senders = await _pc!.getSenders();
      final sender = senders
          .where((s) => s.track?.kind == 'video')
          .firstOrNull;
      if (sender != null && cameraTracks.isNotEmpty) {
        await sender.replaceTrack(cameraTracks.first);
      }
    } catch (_) {
      // If restoring the camera fails, the call still continues
      // as audio — never drop a call for a screen-share teardown.
    }
    for (final t in _screenStream?.getTracks() ?? []) {
      await t.stop();
    }
    await _screenStream?.dispose();
    _screenStream = null;
    _sharingScreen = false;
    notifyListeners();
  }

  // ---------- Ending ----------

  /// End the call and tell the other side. Safe to call twice.
  Future<void> endCall() async {
    if (_callId != null && _peerUsername != null) {
      try {
        await _signalling.send(CallSignal(
          kind: 'hangup',
          callId: _callId!,
          fromUser: _myUsername,
          toUser: _peerUsername!,
        ));
      } catch (_) {
        // Network already gone — the other side times out on its
        // own. Ending locally is what matters here.
      }
    }
    _endCallLocally();
  }

  void _endCallLocally() {
    _ringTimer?.cancel();
    _ringTimer = null;
    // Delete my own inbox node for this call, so no call record
    // stays in the free 1 GB store. Safe to call twice.
    if (_callId != null) {
      unawaited(_signalling.deleteCall(_callId!));
    }
    _setState(CallState.ended);
    unawaited(_cleanupMedia());
    // Back to idle after a beat so the UI can show "call ended".
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == CallState.ended) _setState(CallState.idle);
    });
  }

  void _fail(String message) {
    _error = message;
    _setState(CallState.failed);
    unawaited(_cleanupMedia());
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == CallState.failed) _setState(CallState.idle);
    });
  }

  Future<void> _cleanupMedia() async {
    try {
      await stopScreenShare();
    } catch (_) {}
    for (final t in _localStream?.getTracks() ?? []) {
      await t.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    await _pc?.close();
    _pc = null;
    _pendingOffer = null;
    _callId = null;
    _peerUsername = null;
    _peerName = null;
  }

  void _setState(CallState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    unawaited(_cleanupMedia());
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
