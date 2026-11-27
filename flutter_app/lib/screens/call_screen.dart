import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/app_strings.dart';
import '../services/call_service.dart';

/// V2 CALLING — in-call screen + incoming-call screen (skeleton UI).
///
/// Wired to [CallService] states only; it does not do any WebRTC
/// itself. Not yet tested end-to-end (see call_service.dart).
/// Language: English / Urdu script via [AppStrings] (call keys were
/// merged from call_strings.dart into app_strings.dart, 19 Nov 2026).
/// No Roman Urdu. No call history is shown or stored (privacy —
/// V2 records nothing).
///
/// WIRING (19 Nov 2026):
/// 1. DONE: "Calls" entry on Home opens [CallContactsScreen] —
///    contacts from the existing `All Vaccinators Profile` roster
///    + admin. Tapping a call button shows the honest
///    "calling setup pending" message until Firebase signalling
///    is connected (see [CallService.signallingReady]).
/// 2. TODO: show [IncomingCallScreen] over any screen when
///    [CallService.state] becomes `ringing` — needs a live
///    CallService in main.dart, which needs signalling first.
/// 3. TODO: push [CallScreen] when a call is accepted or started
///    (same signalling dependency).

/// In-call screen: remote video full-screen (video calls), audio
/// avatar view (audio calls), and the shared screen when either
/// side is sharing. Controls: mute, speaker, camera on/off,
/// switch camera, screen share, end call. Big buttons (min 48 px),
/// same dark-green + gold as the rest of the app.
class CallScreen extends StatelessWidget {
  final CallService call;
  final AppLanguage language;

  const CallScreen({super.key, required this.call, required this.language});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: call,
      builder: (context, _) {
        final lang = language;
        final sharing = call.isSharingScreen;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: AppConfig.darkGreen,
            title: Text(
              call.peerName ?? call.peerUsername ?? '',
              style: const TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Audio avatar view. (Video views return with the
                    // real calling code — see call_service.dart.)
                    Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: AppConfig.darkGreen,
                              child: Text(
                                (call.peerName ?? '?')
                                    .characters
                                    .first,
                                style: const TextStyle(
                                    fontSize: 44, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              lang.t('audioCall'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    if (sharing)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            lang.t('viewingScreen'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (sharing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: AppConfig.gold,
                  child: Text(
                    lang.t('sharingScreen'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              _CallControls(call: call, language: lang),
            ],
          ),
        );
      },
    );
  }
}

class _CallControls extends StatelessWidget {
  final CallService call;
  final AppLanguage language;

  const _CallControls({required this.call, required this.language});

  @override
  Widget build(BuildContext context) {
    final lang = language;
    final isVideo = call.type == CallType.video;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          _ControlButton(
            icon: call.isMuted ? Icons.mic_off : Icons.mic,
            label: lang.t(call.isMuted ? 'unmute' : 'mute'),
            onPressed: call.toggleMute,
          ),
          _ControlButton(
            icon: Icons.volume_up,
            label: lang.t('speaker'),
            active: call.isSpeakerOn,
            onPressed: () => unawaited(call.toggleSpeaker()),
          ),
          if (isVideo)
            _ControlButton(
              icon:
                  call.isVideoOn ? Icons.videocam : Icons.videocam_off,
              label: lang.t(
                  call.isVideoOn ? 'cameraOff' : 'cameraOn'),
              onPressed: call.toggleVideo,
            ),
          if (isVideo)
            _ControlButton(
              icon: Icons.switch_camera,
              label: '⇄',
              onPressed: () => unawaited(call.switchCamera()),
            ),
          _ControlButton(
            icon: Icons.screen_share,
            label: lang.t(
                call.isSharingScreen ? 'stopSharing' : 'shareScreen'),
            active: call.isSharingScreen,
            onPressed: () async {
              if (call.isSharingScreen) {
                await call.stopScreenShare();
              } else {
                final ok = await call.startScreenShare();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.t('screenSharePrompt'))));
                }
              }
            },
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: lang.t('endCall'),
            background: AppConfig.danger,
            onPressed: () => unawaited(call.endCall()),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color? background;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: background ??
                  (active ? AppConfig.gold : Colors.white24),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Incoming-call screen: shown over any screen while
/// [CallService.state] is `ringing`. Nothing is answered
/// automatically; microphone/camera stay off until Accept.
/// Accept / Decline are the only actions — big, thumb-reachable.
class IncomingCallScreen extends StatelessWidget {
  final CallService call;
  final AppLanguage language;

  const IncomingCallScreen(
      {super.key, required this.call, required this.language});

  @override
  Widget build(BuildContext context) {
    final lang = language;
    return Scaffold(
      backgroundColor: AppConfig.darkGreen,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white,
              child: Text(
                (call.peerName ?? '?').characters.first,
                style: const TextStyle(
                    fontSize: 44, color: AppConfig.darkGreen),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              call.peerName ?? call.peerUsername ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${lang.t('incomingCall')} · ${lang.t(call.type == CallType.video ? 'videoCall' : 'audioCall')}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AnswerButton(
                  icon: Icons.call_end,
                  label: lang.t('decline'),
                  background: AppConfig.danger,
                  onPressed: () => unawaited(call.declineCall()),
                ),
                _AnswerButton(
                  icon: Icons.call,
                  label: lang.t('accept'),
                  background: AppConfig.success,
                  onPressed: () => unawaited(call.acceptCall()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 34, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}
