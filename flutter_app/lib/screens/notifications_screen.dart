import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../l10n/app_strings.dart';
import '../widgets/common.dart';

/// S7 Notifications — read-only list, newest first.
/// Source: proposed `Announcements` tab, with fallback to a static
/// announcements.json on the EPI site so v1 works before the tab
/// exists. No reply / chat in v1 (chat is V2).
/// All labels come from AppStrings (English or Urdu script).
/// Announcement titles/bodies themselves come from the office
/// (in Urdu script or English — never Roman Urdu).
class Announcement {
  final String title;
  final String body;
  final String date;
  const Announcement(
      {required this.title, required this.body, required this.date});
}

class NotificationsScreen extends StatefulWidget {
  final AppLanguage lang;
  const NotificationsScreen({super.key, required this.lang});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Announcement> _items = [];
  bool _loading = true;

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.announcementsUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final list = (j is List ? j : (j['announcements'] as List? ?? []));
        _items = list
            .map((e) => Announcement(
                  title: (e['title'] ?? '').toString(),
                  body: (e['body'] ?? '').toString(),
                  date: (e['date'] ?? '').toString(),
                ))
            .toList();
      }
    } catch (_) {
      // No announcements file yet — empty list, not an error.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('notifTitle'),
      subtitle: lang.t('notifSub'),
      body: Column(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            InfoBox(lang.t('noNotif'))
          else
            ..._items.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(a.body),
                    trailing: Text(a.date,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                )),
        ],
      ),
    );
  }
}
