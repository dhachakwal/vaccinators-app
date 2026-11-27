import 'dart:async';

import 'call_service.dart';

/// V2 CALLING — Firebase signalling STUB (27 Nov 2026).
///
/// The real Firebase Realtime Database signalling was removed
/// from the build with the rest of the calling packages (user
/// order, APK size — calling cannot work until the user's
/// Firebase project exists, design doc §10). This stub keeps
/// the same public API so the calling UI compiles unchanged:
/// [isConfigured] and [ensureInitialized] are always false, so
/// [CallService.signallingReady] stays false and the Contacts
/// screen honestly shows "Calling Not Set Up Yet".
///
/// TO RESTORE: copy the real implementation back from
/// hidden_files/call-code-backup-v1.0.7/ and re-add firebase_core
/// + firebase_database to pubspec.yaml (see call_service.dart).
class FirebaseRealtimeCallSignalling implements CallSignalling {
  /// Always false in this build — Firebase is not in the app.
  static bool get isConfigured => false;

  /// Always false in this build — see [isConfigured].
  static Future<bool> ensureInitialized() async => false;

  /// Realtime Database keys may not contain . # $ [ ] / or
  /// whitespace. Kept from the real implementation so the
  /// restore is a straight file swap.
  static String keyForUser(String username) =>
      username.trim().replaceAll(RegExp(r'[.#$\[\]/\s]'), '_');

  final String myUsername;
  final _controller = StreamController<CallSignal>.broadcast();

  FirebaseRealtimeCallSignalling({required this.myUsername});

  @override
  Stream<CallSignal> get incoming => _controller.stream;

  @override
  Future<void> send(CallSignal signal) async {
    throw StateError(
      'Call server is not set up yet — calling was removed from '
      'this build (APK size) and Firebase is not configured.',
    );
  }

  @override
  Future<void> deleteCall(String callId) async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
