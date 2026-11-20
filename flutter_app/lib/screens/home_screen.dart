import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'call_contacts_screen.dart';
import 'forms_screen.dart';
import 'message_parents_screen.dart';
import 'my_data_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';

/// Home: status at a glance + one-tap big cards.
/// Navigation is by callback so main.dart owns the tab state.
/// All labels come from AppStrings (English or Urdu script).
class HomeScreen extends StatelessWidget {
  final Vaccinator user;
  final ApiService api;
  final StorageService storage;
  final int pendingCount;
  final AppLanguage lang;
  final void Function(int tab) onGo;
  const HomeScreen({
    super.key,
    required this.user,
    required this.api,
    required this.storage,
    required this.pendingCount,
    required this.lang,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    final lastLoc = storage.lastLocationAt;
    return ScreenScaffold(
      title: lang.t('greeting', {'name': user.name}),
      subtitle: '${user.uc} · ${user.tehsil} — ${AppConfig.todayYmdPkt()}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip(
                      label: lastLoc == null
                          ? lang.t('locationNotSent')
                          : lang.t('locationSent'),
                      ok: lastLoc != null),
                  if (pendingCount > 0)
                    StatusChip(
                        label: lang.t(
                            'syncPending', {'n': '$pendingCount'}),
                        ok: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _card(context, '📍  ${lang.t('cardLocationTitle')}',
              lang.t('cardLocationSub'), () => onGo(1), false),
          _card(context, '💉  ${lang.t('cardReportTitle')}',
              lang.t('cardReportSub'), () => onGo(2), false),
          _card(context, '🚫  ${lang.t('cardZeroTitle')}',
              lang.t('cardZeroSub'), () => onGo(2), false),
          _card(context, '🏖️  ${lang.t('cardLeaveTitle')}',
              lang.t('cardLeaveSub'), () => onGo(3), false),
          _card(context, '📝  ${lang.t('cardFormsTitle')}',
              lang.t('cardFormsSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FormsScreen(lang: lang)),
            );
          }, false),
          // CALLS (V2, wired 19 Nov 2026): a Home card, NOT a 6th
          // bottom-nav tab — 5 tabs already crowd low-end phones
          // (same reason Forms is a card, not a tab). Opens the
          // contacts list (roster + admin); placing a call still
          // needs Firebase signalling — tapping a call button
          // shows that honestly, never a fake call.
          _card(context, '📞  ${lang.t('cardCallsTitle')}',
              lang.t('cardCallsSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CallContactsScreen(
                      api: api,
                      storage: storage,
                      user: user,
                      lang: lang)),
            );
          }, false),
          // MY DATA (19 Nov 2026): the vaccinator's OWN UC only
          // (attendance, doses, UC summary, service record,
          // leave) — no UC picker, no cross-UC view. See
          // my_data_screen.dart for the privacy enforcement.
          _card(context, '📊  ${lang.t('cardMyDataTitle')}',
              lang.t('cardMyDataSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      MyDataScreen(user: user, lang: lang)),
            );
          }, false),
          // MESSAGE PARENTS — FREE (user question, 19 Nov 2026):
          // WhatsApp (free beyond data) from the vaccinator's own
          // number, SMS composer as fallback. One message at a
          // time — no bulk send. Children list is OWN UC only
          // (EMR sheet) — see message_parents_screen.dart.
          _card(context, '💬  ${lang.t('cardMsgTitle')}',
              lang.t('cardMsgSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      MessageParentsScreen(user: user, lang: lang)),
            );
          }, false),
          // DAILY REPORTS IN-APP (user order, 19 Nov 2026):
          // the same 11 reports the nightly pipeline sends on
          // WhatsApp at 3:00 AM also arrive here every morning.
          // Only my own UC + district reports — see
          // reports_screen.dart for the privacy enforcement.
          _card(context, '📋  ${lang.t('cardReportsTitle')}',
              lang.t('cardReportsSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ReportsScreen(user: user, lang: lang)),
            );
          }, false),
          _card(context, '🔔  ${lang.t('cardNotifTitle')}',
              lang.t('cardNotifSub'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NotificationsScreen(lang: lang)),
            );
          }, false),
          const SizedBox(height: 12),
          InfoBox(lang.t('homeBgNote')),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, String sub,
      VoidCallback onTap, bool done) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(title,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: Icon(
            done ? Icons.check_circle : Icons.arrow_forward_ios,
            color: done ? AppConfig.success : AppConfig.darkGreen),
        onTap: onTap,
      ),
    );
  }
}
