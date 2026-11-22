import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/language_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';
import 'update_screen.dart';
import '../widgets/common.dart';

/// S8 My Profile — attendance, my reports, record (read-only),
/// app version + update check + logout, and the language switch
/// (Urdu script / English — exactly two options).
/// All labels come from AppStrings (English or Urdu script).
/// v1.0.6: Stateful — the queue count refreshes right after a
/// sync, so "Sync Now (0 remaining)" shows as soon as the data
/// is submitted instead of keeping the old number on screen.
class ProfileScreen extends StatefulWidget {
  final Vaccinator user;
  final StorageService storage;
  final SyncService sync;
  final AppLanguage lang;
  final LanguageService language;
  final VoidCallback onLogout;
  const ProfileScreen({
    super.key,
    required this.user,
    required this.storage,
    required this.sync,
    required this.lang,
    required this.language,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late int _pending;

  Vaccinator get user => widget.user;
  StorageService get storage => widget.storage;
  SyncService get sync => widget.sync;
  AppLanguage get lang => widget.lang;
  LanguageService get language => widget.language;

  @override
  void initState() {
    super.initState();
    _pending = storage.queue.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-read the count every time the tab is shown again, so a
    // report submitted from another tab is reflected here.
    _pending = storage.queue.length;
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('profileTitle'),
      subtitle: '${user.name} — ${user.uc} · ${user.tehsil}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${lang.t('ucLabel')}: ${user.uc}'),
                  Text('${lang.t('tehsil')}: ${user.tehsil}'),
                  Text('${lang.t('usernameMobile')}: ${user.username}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InfoBox(
            '${lang.t('lastLocation')}: ${storage.lastLocationAt ?? '—'}\n'
            '${lang.t('syncRemaining')}: $_pending\n'
            '${lang.t('leaveBalanceOpening')}: ${user.openingRemaining.toInt()} ${lang.t('remainingYear')}',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('language'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(lang.t('languageNote'),
                      style:
                          const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: BigButton(
                          label: 'اردو',
                          color: lang == AppLanguage.urdu
                              ? AppConfig.darkGreen
                              : Colors.grey,
                          onPressed: () =>
                              language.setLanguage(AppLanguage.urdu),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BigButton(
                          label: 'English',
                          color: lang == AppLanguage.english
                              ? AppConfig.darkGreen
                              : Colors.grey,
                          onPressed: () =>
                              language.setLanguage(AppLanguage.english),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: '🔄 ${lang.t('syncNow', {'n': '$_pending'})}',
            onPressed: () async {
              final (sent, pending) = await sync.syncAll();
              if (context.mounted) {
                setState(() => _pending = pending);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('syncResult',
                        {'sent': '$sent', 'pending': '$pending'}))));
              }
            },
            color: AppConfig.midGreen,
          ),
          const SizedBox(height: 10),
          BigButton(
            label: '⬆️ ${lang.t('updateCheck')}',
            onPressed: () async {
              final update = await UpdateService().check();
              if (!context.mounted) return;
              if (update == null) {
                // Server-down exception: say so, do not block.
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('updateCheckFailed'))));
              } else if (update.isNewer) {
                // Forced or optional — the update screen handles
                // both (forced has no Later button, optional does).
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          UpdateScreen(update: update, lang: lang)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('updateLatest'))));
              }
            },
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onLogout,
            child: Text(lang.t('logout'),
                style:
                    const TextStyle(color: AppConfig.danger, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          // ignore: prefer_const_constructors — version is dynamic.
          Text(
            lang.t('appVersion', {
              'v':
                  '${AppConfig.versionName} (${AppConfig.versionCode})',
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
