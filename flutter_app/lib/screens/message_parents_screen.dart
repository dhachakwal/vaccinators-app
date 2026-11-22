import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/message_service.dart';
import '../widgets/common.dart';

/// S12 — Message Parents, FREE (user question, 19 Nov 2026).
///
/// Lists the children of the logged-in vaccinator's OWN UC only
/// (from the EMR sheet — the same source as the site's
/// Verification Calls module). There is NO UC picker and no other
/// UC's children are ever listed. Each row has a Message button
/// that opens a template picker: the vaccinator picks a template,
/// checks the preview, and taps "Send via WhatsApp" — the message
/// opens in their OWN WhatsApp, prefilled, and they tap Send
/// there. The message is free beyond mobile data. If WhatsApp is
/// not installed, the SMS composer opens instead (costs whatever
/// the vaccinator's mobile package charges).
///
/// HARD RULES (see MessageService): one message at a time — NO
/// bulk send (WhatsApp bans bulk automation); first name only in
/// the text; the app never claims delivery, only "opened".
/// All labels come from AppStrings (English or Urdu script).
class MessageParentsScreen extends StatefulWidget {
  final Vaccinator user;
  final AppLanguage lang;
  const MessageParentsScreen(
      {super.key, required this.user, required this.lang});

  @override
  State<MessageParentsScreen> createState() => _MessageParentsScreenState();
}

class _MessageParentsScreenState extends State<MessageParentsScreen> {
  final MessageService _service = MessageService();
  final _search = TextEditingController();
  List<ParentChild> _children = [];
  bool _loading = true;
  bool _fromCache = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (children, fromCache, failed) =
        await _service.fetchMyUcChildren(widget.user);
    if (!mounted) return;
    setState(() {
      _children = children;
      _fromCache = fromCache;
      _loadFailed = failed;
      _loading = false;
    });
  }

  List<ParentChild> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _children;
    return _children
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.father.toLowerCase().contains(q))
        .toList();
  }

  String _tomorrowYmd() {
    final t =
        DateTime.now().toUtc().add(const Duration(hours: 5, days: 1));
    final d = t.day.toString().padLeft(2, '0');
    final m = t.month.toString().padLeft(2, '0');
    return '$d-$m-${t.year}';
  }

  Future<void> _openComposer(ParentChild child) async {
    final lang = widget.lang;
    var template = MessageTemplate.due;
    final phoneCtrl = TextEditingController(text: child.phone);
    final vaccineCtrl =
        TextEditingController(text: child.nextDue.isEmpty ? 'BCG' : child.nextDue);
    final dateCtrl = TextEditingController(text: _tomorrowYmd());
    final customCtrl = TextEditingController();
    var preview = '';

    void rebuild(StateSetter setSheet) {
      preview = MessageService.buildMessage(
        template,
        lang,
        childFirstName: child.firstName,
        parentName: child.father,
        vaccine: vaccineCtrl.text.trim(),
        date: dateCtrl.text.trim(),
        customText: customCtrl.text,
      );
      setSheet(() {});
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (preview.isEmpty) rebuild(setSheet);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${child.name}'
                    '${child.father.isNotEmpty ? ' — ${lang.t('msgChildOf')} ${child.father}' : ''}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang.t('msgPhone'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(lang.t('msgTemplate'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...MessageTemplate.values.map((t) => RadioListTile(
                        title: Text(lang.t('msgTpl_${t.name}')),
                        value: t,
                        groupValue: template,
                        onChanged: (v) {
                          template = v ?? MessageTemplate.due;
                          rebuild(setSheet);
                        },
                      )),
                  if (template == MessageTemplate.due ||
                      template == MessageTemplate.missed) ...[
                    TextField(
                      controller: vaccineCtrl,
                      decoration: InputDecoration(
                        labelText: lang.t('msgVaccine'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => rebuild(setSheet),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateCtrl,
                      decoration: InputDecoration(
                        labelText: lang.t('msgDate'),
                        hintText: 'DD-MM-YYYY',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => rebuild(setSheet),
                    ),
                  ],
                  if (template == MessageTemplate.custom) ...[
                    TextField(
                      controller: customCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: lang.t('msgCustomHint'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => rebuild(setSheet),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(lang.t('msgPreview'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Card(
                    color: AppConfig.lightGreen,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(preview),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BigButton(
                    label: '💬 ${lang.t('msgSendWhatsApp')}',
                    color: AppConfig.success,
                    onPressed: () async {
                      final text = preview;
                      final phone = phoneCtrl.text.trim();
                      final ok = await MessageService.openWhatsApp(
                          phone, text);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(lang.t(ok
                              ? 'msgOpenedWhatsApp'
                              : 'msgWhatsAppMissing'))));
                    },
                  ),
                  const SizedBox(height: 10),
                  BigButton(
                    label: '✉️ ${lang.t('msgSendSms')}',
                    color: AppConfig.midGreen,
                    onPressed: () async {
                      final text = preview;
                      final phone = phoneCtrl.text.trim();
                      final ok =
                          await MessageService.openSms(phone, text);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(lang.t(
                              ok ? 'msgOpenedSms' : 'msgSendFailed'))));
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(lang.t('msgFreeNote'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
    phoneCtrl.dispose();
    vaccineCtrl.dispose();
    dateCtrl.dispose();
    customCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final shown = _filtered;
    return ScreenScaffold(
      title: lang.t('msgTitle'),
      subtitle: '${widget.user.name} — ${widget.user.uc} · ${widget.user.tehsil}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(lang.t('msgFreeNote')),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: lang.t('msgSearch'),
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadFailed)
            InfoBox(lang.t('msgLoadFail'))
          else if (_children.isEmpty)
            InfoBox(lang.t('msgNoChildren'))
          else ...[
            if (_fromCache) ...[
              InfoBox(lang.t('msgOffline')),
              const SizedBox(height: 8),
            ],
            Text(lang.t('msgCount', {'n': '${shown.length}'}),
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ...shown.map((c) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.name}'
                          '${c.father.isNotEmpty ? ' — ${lang.t('msgChildOf')} ${c.father}' : ''}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                            '${c.age.isNotEmpty ? '${c.age} · ' : ''}${c.gender} · ${c.phone.isNotEmpty ? c.phone : lang.t('msgNoPhone')}'),
                        if (c.nextDue.isNotEmpty)
                          Text(
                              '${lang.t('msgNextDue')}: ${c.nextDue}',
                              style: const TextStyle(
                                  color: AppConfig.midGreen)),
                        if (c.nextDue.isEmpty)
                          Text(lang.t('msgAllDone'),
                              style: const TextStyle(
                                  color: AppConfig.midGreen)),
                        const SizedBox(height: 8),
                        BigButton(
                          label: '💬 ${lang.t('msgMessage')}',
                          color: c.phone.isEmpty
                              ? Colors.grey
                              : AppConfig.darkGreen,
                          onPressed: c.phone.isEmpty
                              ? null
                              : () => _openComposer(c),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 12),
          BigButton(
            label: '🔄 ${lang.t('myDataRefresh')}',
            color: AppConfig.midGreen,
            onPressed: _load,
          ),
        ],
      ),
    );
  }
}
