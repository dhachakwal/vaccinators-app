import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/sync_service.dart';
import '../widgets/common.dart';

/// S4 Daily Report + S5 Zero Entry (one "Report" tab, two sections).
/// Doses by antigen with + / - steppers. Total auto-calculated.
/// NOTE (honest): dailyReport / zeroEntry are NEW payload types —
/// the Apps Script does not handle them yet (see GOAL.md). The app
/// therefore queues them and says "queued", never "submitted".
/// One report per day: sending again replaces today's queued report.
/// All labels come from AppStrings (English or Urdu script).
class ReportScreen extends StatefulWidget {
  final Vaccinator user;
  final SyncService sync;
  final AppLanguage lang;
  const ReportScreen(
      {super.key, required this.user, required this.sync, required this.lang});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final Map<String, int> _doses = {
    for (final a in AppConfig.antigens) a: 0,
  };
  final _kit = TextEditingController();
  final _note = TextEditingController();
  String? _zeroReason;
  bool _busy = false;
  String? _message;
  bool _messageError = false;

  AppLanguage get lang => widget.lang;
  int get _total => _doses.values.fold(0, (a, b) => a + b);

  Future<void> _submitDaily() async {
    setState(() => _busy = true);
    final payload = <String, dynamic>{
      'type': 'dailyReport',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'date': AppConfig.todayYmdPkt(),
      'name': widget.user.name,
      'username': widget.user.username,
      'tehsil': widget.user.tehsil,
      'uc': widget.user.uc,
      'kitStation': _kit.text.trim(),
      for (final e in _doses.entries) e.key: e.value,
      'totalChildren': _total,
    };
    final result = await widget.sync.submit(payload);
    setState(() {
      _busy = false;
      _messageError = result == 'failed';
      _message = result == 'verified'
          ? lang.t('reportVerified')
          : lang.t('reportQueued');
    });
  }

  Future<void> _submitZero() async {
    if (_zeroReason == null) {
      setState(() {
        _message = lang.t('zeroChooseReason');
        _messageError = true;
      });
      return;
    }
    setState(() => _busy = true);
    final payload = <String, dynamic>{
      'type': 'zeroEntry',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'date': AppConfig.todayYmdPkt(),
      'name': widget.user.name,
      'username': widget.user.username,
      'tehsil': widget.user.tehsil,
      'uc': widget.user.uc,
      'reason': _zeroReason,
      'note': _note.text.trim(),
    };
    final result = await widget.sync.submit(payload);
    setState(() {
      _busy = false;
      _messageError = result == 'failed';
      _message = result == 'verified'
          ? lang.t('zeroVerified')
          : lang.t('zeroQueued');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('reportTitle'),
      subtitle:
          '${widget.user.uc} · ${widget.user.tehsil} — ${AppConfig.todayYmdPkt()}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lang.t('todayVacc'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _kit,
            decoration: InputDecoration(
              labelText: lang.t('kitStation'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ...AppConfig.antigens.map((a) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(a,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 30),
                        onPressed: _doses[a]! > 0
                            ? () => setState(() => _doses[a] = _doses[a]! - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 36,
                        child: Text('${_doses[a]}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            size: 30, color: AppConfig.darkGreen),
                        onPressed: () =>
                            setState(() => _doses[a] = _doses[a]! + 1),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          InfoBox(lang.t('totalChildren', {'n': '$_total'}),
              isSuccess: true),
          const SizedBox(height: 12),
          BigButton(
              label: '💉 ${lang.t('sendReport')}',
              onPressed: _busy ? null : _submitDaily),
          const Divider(height: 32),
          Text(lang.t('zeroTitle'),
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(lang.t('zeroDesc'),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _zeroReason,
            decoration: InputDecoration(
                labelText: lang.t('zeroReasonLabel'),
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'Leave', child: Text(lang.t('zeroReasonLeave'))),
              DropdownMenuItem(
                  value: 'Not Leave',
                  child: Text(lang.t('zeroReasonNotLeave'))),
            ],
            onChanged: (v) => setState(() => _zeroReason = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: lang.t('zeroNoteLabel'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: '🚫 ${lang.t('sendZero')}',
            onPressed: _busy ? null : _submitZero,
            color: AppConfig.danger,
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            InfoBox(_message!,
                isError: _messageError, isSuccess: !_messageError),
          ],
        ],
      ),
    );
  }
}
