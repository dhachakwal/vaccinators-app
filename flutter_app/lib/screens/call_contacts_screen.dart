import 'dart:async';

import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/call_service.dart';
import '../services/storage_service.dart';
import 'call_screen.dart';
import '../widgets/common.dart';

/// V2 CALLING — contacts list (C1). WIRED 19 Nov 2026: reachable
/// from the "Calls" card on Home. The user reported "calling ka
/// option nai hai" — this screen IS that option.
///
/// Contacts (all-to-all, user decision 19 Nov 2026 — no tehsil
/// restriction):
/// - Admin row (username 'admin') — the district admin.
/// - Every vaccinator in the existing `All Vaccinators Profile`
///   roster (cached on the phone, refreshed when online), except
///   yourself. No new backend, no new sheet.
/// - Supervisors: there is NO supervisor list in the app's data
///   yet (supervisors are not rows in All Vaccinators Profile),
///   so they cannot be listed as contacts — the screen says so
///   honestly (callsSupervisorsEmpty) instead of inventing
///   names/numbers. Once the admin adds the supervisor list,
///   supervisors appear here like everyone else.
///
/// Each row has three buttons: Audio Call, Video Call, and
/// Screen Share (starts a call with screen share — the share
/// itself starts inside the call, see call_service.dart).
///
/// HONEST STATE: [CallService.signallingReady] is false until
/// Firebase is set up (google-services.json + Realtime
/// Database — design doc §10), so tapping any call button
/// shows the "calling setup pending" dialog — it never crashes
/// and never shows a fake "calling" screen. Once Firebase is
/// configured, _tryCall below starts a real call.
class CallContactsScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;
  final Vaccinator user;
  final AppLanguage lang;
  const CallContactsScreen({
    super.key,
    required this.api,
    required this.storage,
    required this.user,
    required this.lang,
  });

  @override
  State<CallContactsScreen> createState() => _CallContactsScreenState();
}

class _CallContact {
  final String name;
  final String username;
  final String detail;
  final String roleKey;
  const _CallContact({
    required this.name,
    required this.username,
    required this.detail,
    required this.roleKey,
  });
}

class _CallContactsScreenState extends State<CallContactsScreen> {
  List<_CallContact> _contacts = [];
  bool _loading = true;
  bool _offlineList = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Cached roster first, so the list opens offline after day 1.
    var roster = widget.storage.roster;
    if (roster.isNotEmpty) _applyRoster(roster, offline: false);
    try {
      final fresh = await widget.api.loadRoster();
      if (fresh.isNotEmpty) {
        await widget.storage.saveRoster(fresh);
        if (mounted) _applyRoster(fresh, offline: false);
      }
    } catch (_) {
      // No net: keep the cached list and say so.
      if (mounted) setState(() => _offlineList = roster.isNotEmpty);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyRoster(List<Vaccinator> roster, {required bool offline}) {
    final me = ApiHelpers.normUserKey(widget.user.username);
    final myName = widget.user.name.trim().toLowerCase();
    final list = <_CallContact>[
      _CallContact(
        name: widget.lang.t('roleAdmin'),
        username: 'admin',
        detail: 'EPI District Chakwal',
        roleKey: 'roleAdmin',
      ),
    ];
    final vacs = roster.where((v) {
      final key = ApiHelpers.normUserKey(v.username);
      if (me.isNotEmpty && key.isNotEmpty && key == me) return false;
      if (v.name.trim().toLowerCase() == myName) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final v in vacs) {
      final place = [v.uc, v.tehsil]
          .where((s) => s.trim().isNotEmpty)
          .join(' · ');
      list.add(_CallContact(
        name: v.name,
        username: v.username,
        detail: place,
        roleKey: 'roleVaccinator',
      ));
    }
    setState(() {
      _contacts = list;
      _offlineList = offline;
    });
  }

  List<_CallContact> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.detail.toLowerCase().contains(q))
        .toList();
  }

  /// Tapping a call button. First tries to initialise Firebase
  /// signalling; if it is not configured yet (no
  /// google-services.json — design doc §10), shows the honest
  /// pending state — never a fake call. Otherwise starts a real
  /// call and opens CallScreen. For shareScreen: starts a video
  /// call, then starts screen share once the call connects.
  Future<void> _tryCall(_CallContact contact, CallType type,
      {bool shareScreen = false}) async {
    // Capture these before the awaits (no BuildContext use
    // across async gaps).
    final lang = widget.lang;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ready = await CallService.ensureSignallingReady();
    if (!mounted) return;
    if (!ready || !CallService.signallingReady) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(lang.t('callSetupPendingTitle')),
          content: Text(lang.t('callSetupPending')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.t('okButton')),
            ),
          ],
        ),
      );
      return;
    }
    final call = CallService(
      signalling:
          FirebaseRealtimeCallSignalling(myUsername: widget.user.username),
      myUsername: widget.user.username,
    );
    final ok = await call.startCall(
      peerUsername: contact.username,
      peerName: contact.name,
      type: shareScreen ? CallType.video : type,
    );
    if (!ok) {
      messenger.showSnackBar(
          SnackBar(content: Text(lang.t('callFailed'))));
      return;
    }
    if (shareScreen) {
      // Start sharing as soon as the call connects.
      void onState() {
        if (call.inCall && !call.isSharingScreen) {
          call.removeListener(onState);
          unawaited(call.startScreenShare());
        }
      }

      call.addListener(onState);
    }
    navigator.push(
      MaterialPageRoute(
          builder: (_) => CallScreen(call: call, language: lang)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final shown = _filtered;
    final admin =
        shown.where((c) => c.roleKey == 'roleAdmin').toList();
    final vacs =
        shown.where((c) => c.roleKey == 'roleVaccinator').toList();
    return ScreenScaffold(
      title: lang.t('calls'),
      subtitle: lang.t('callContacts'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(lang.t('callNeedsInternet')),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: lang.t('callsSearch'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (_offlineList) ...[
            InfoBox(lang.t('callsOfflineList')),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_contacts.isEmpty)
            InfoBox(lang.t('callsRosterEmpty'), isError: true)
          else if (shown.isEmpty)
            InfoBox(lang.t('callsNoMatch'))
          else ...[
            _section(lang.t('callsAdminSection')),
            for (final c in admin) _row(c),
            _section(lang.t('callsVaccinatorsSection')),
            for (final c in vacs) _row(c),
          ],
          const SizedBox(height: 16),
          _section(lang.t('callsSupervisorsSection')),
          InfoBox(lang.t('callsSupervisorsEmpty')),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppConfig.darkGreen)),
    );
  }

  Widget _row(_CallContact c) {
    final lang = widget.lang;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppConfig.darkGreen,
              child: Text(
                c.name.characters.first,
                style:
                    const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    '${lang.t(c.roleKey)}${c.detail.isNotEmpty ? ' · ${c.detail}' : ''}',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            _callButton(
              icon: Icons.call,
              label: lang.t('audioCall'),
              color: AppConfig.darkGreen,
              onPressed: () => _tryCall(c, CallType.audio),
            ),
            const SizedBox(width: 6),
            _callButton(
              icon: Icons.videocam,
              label: lang.t('videoCall'),
              color: const Color(0xFF1565C0),
              onPressed: () => _tryCall(c, CallType.video),
            ),
            const SizedBox(width: 6),
            _callButton(
              icon: Icons.screen_share,
              label: lang.t('shareScreen'),
              color: AppConfig.gold,
              onPressed: () =>
                  _tryCall(c, CallType.video, shareScreen: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            onPressed: onPressed,
            child: Icon(icon, size: 22),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }
}
