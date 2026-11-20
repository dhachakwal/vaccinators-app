import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';

/// FORCED IN-APP UPDATE (user order, 19 Nov 2026 — STANDING RULE):
/// when a newer version is on the EPI site, the vaccinator must
/// update FIRST — the old version does not open at all. The update
/// happens right here: one big button downloads the APK with a
/// progress bar, then opens the Android installer automatically.
/// No Play Store, no hunting for a link.
///
/// - Mandatory update (version.json `optional` absent/false):
///   this screen is NON-DISMISSIBLE — PopScope blocks the back
///   button and there is no "Later" button. The app stays on this
///   screen until the new APK is installed (or the download fails,
///   in which case Retry is shown — the old version still does
///   not open).
/// - Optional update (`optional: true` in version.json): the same
///   screen, but a "Later" button is shown and the back button
///   works — the vaccinator may keep using the old version.
/// - Server-down exception: this screen is only shown when
///   version.json WAS reached and says a newer version exists.
///   If version.json cannot be reached at all, UpdateService.check()
///   returns null and main.dart opens the app normally with a small
///   note — a site outage must never lock 70 vaccinators out.
/// - Safety: login + offline queue live in SharedPreferences.
///   Installing the new APK replaces the app binary only — storage
///   is NOT cleared, so after the update the app opens straight in,
///   no re-login.
enum _UpdatePhase { idle, downloading, downloaded, error }

class UpdateScreen extends StatefulWidget {
  final AppUpdate update;
  final AppLanguage lang;
  const UpdateScreen({super.key, required this.update, required this.lang});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  _UpdatePhase _phase = _UpdatePhase.idle;
  double _progress = 0;
  int _received = 0;
  int? _total;
  String? _error;

  AppLanguage get lang => widget.lang;
  AppUpdate get update => widget.update;
  bool get _forced => !update.optional;

  String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);

  Future<void> _startUpdate() async {
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
      _received = 0;
      _total = null;
      _error = null;
    });
    try {
      final file = await UpdateService().downloadApkFile(
        update.apkUrl,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
            if (total != null && total > 0) _progress = received / total;
          });
        },
      );
      if (!mounted) return;
      setState(() => _phase = _UpdatePhase.downloaded);
      final ok = await UpdateService().openInstaller(file);
      if (!mounted) return;
      if (!ok) {
        // Installer did not open (e.g. "install unknown apps" not
        // allowed yet for this app). Stay on this screen with the
        // instruction — the old version still does not open.
        setState(() {
          _phase = _UpdatePhase.error;
          _error = lang.t('updateOpenInstallerFailed');
        });
      }
      // If the installer opened, Android takes over: the user taps
      // Install, the APK replaces this app, and the new version
      // opens straight into the app (login + queue survive).
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.error;
        _error = lang.t('updateFailed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mandatory: no back button, no swipe-back, no dismiss.
    // Optional: back button + "Later" work normally.
    return PopScope(
      canPop: !_forced,
      child: Scaffold(
        appBar: AppBar(
          title: Text(lang.t('updateTitle')),
          automaticallyImplyLeading: !_forced,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.system_update,
                  size: 72, color: AppConfig.darkGreen),
              const SizedBox(height: 16),
              Text(
                lang.t('newVersionTitle', {'v': update.versionName}),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                lang.t('updateFirstBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.t('updateWhatsNew'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(_whatsNew()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_phase == _UpdatePhase.downloading) ...[
                LinearProgressIndicator(value: _total == null ? null : _progress),
                const SizedBox(height: 8),
                Text(
                  _total == null
                      ? lang.t('updateDownloading')
                      : lang.t('updateSize', {
                          'received': _mb(_received),
                          'total': _mb(_total!),
                        }),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(lang.t('updateDownloading'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ] else if (_phase == _UpdatePhase.downloaded) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(lang.t('updateDownloaded'), textAlign: TextAlign.center),
              ] else ...[
                BigButton(
                  label: '⬇️ ${lang.t('updateNow')}',
                  onPressed: _startUpdate,
                ),
                if (_phase == _UpdatePhase.error && _error != null) ...[
                  const SizedBox(height: 12),
                  InfoBox(_error!, isError: true),
                  const SizedBox(height: 12),
                  BigButton(
                    label: '🔄 ${lang.t('updateRetry')}',
                    onPressed: _startUpdate,
                    color: AppConfig.midGreen,
                  ),
                ],
                if (!_forced) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(lang.t('later')),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              InfoBox(lang.t('updateInstallNote')),
            ],
          ),
        ),
      ),
    );
  }

  /// What's new in the vaccinator's own language: Urdu script when
  /// the app is in Urdu and `whatsNewUr` is set, else English.
  String _whatsNew() {
    if (lang == AppLanguage.urdu && update.whatsNewUr.isNotEmpty) {
      return update.whatsNewUr;
    }
    return update.whatsNew.isNotEmpty
        ? update.whatsNew
        : lang.t('newVersionBody');
  }
}
