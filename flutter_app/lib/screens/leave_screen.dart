import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/common.dart';

/// S6 Leave — same rules as the web form, unchanged:
/// today only, max 2/month, 24/year, attachment mandatory.
/// Balance is computed from the Leave tab + opening balance.
/// Success is shown ONLY after sheet verification (leave type).
/// All labels come from AppStrings (English or Urdu script).
class LeaveScreen extends StatefulWidget {
  final Vaccinator user;
  final ApiService api;
  final StorageService storage;
  final SyncService sync;
  final AppLanguage lang;
  const LeaveScreen({
    super.key,
    required this.user,
    required this.api,
    required this.storage,
    required this.sync,
    required this.lang,
  });

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  XFile? _file;
  bool _busy = false;
  String? _message;
  bool _messageError = false;
  int _monthUsed = 0;
  int _yearUsed = 0;
  bool _balanceLoading = true;

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final rows = await widget.api.loadLeaveRows();
      final key = ApiHelpers.normUserKey(widget.user.username);
      final nm = widget.user.name.trim().toLowerCase();
      final today = AppConfig.todayYmdPkt();
      final month = today.substring(0, 7);
      final seen = <String>{};
      var m = 0, y = 0;
      for (final r in rows) {
        final rn = (ApiService.pick(r, ['name']) ?? '').trim().toLowerCase();
        final ru = ApiHelpers.normUserKey(
            ApiService.pick(r, ['username']) ?? '');
        final raw = ApiService.pick(r, ['leave date', 'leavedate', 'date']) ?? '';
        final match =
            RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(raw);
        final ymd = match?.group(1) ?? '';
        if (ymd.isEmpty || ymd.compareTo('2026-09-01') < 0) continue;
        if (!((key.isNotEmpty && ru.isNotEmpty && key == ru) ||
            (nm.isNotEmpty && rn.isNotEmpty && nm == rn))) continue;
        if (!seen.add(ymd)) continue;
        y++;
        if (ymd.startsWith(month)) m++;
      }
      if (mounted) {
        setState(() {
          _monthUsed = m;
          _yearUsed = y;
        });
      }
    } catch (_) {
      // Offline: balance unknown — still allow submit; the server
      // rules are enforced again when the row is verified.
    }
    if (mounted) setState(() => _balanceLoading = false);
  }

  Future<void> _pickFile() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 72,
    );
    if (f != null) setState(() => _file = f);
  }

  Future<void> _submit() async {
    if (_file == null) {
      setState(() {
        _message = lang.t('leavePhotoRequired');
        _messageError = true;
      });
      return;
    }
    if (_monthUsed >= AppConfig.monthlyLeaveMax) {
      setState(() {
        _message = lang.t('leaveLimitReached',
            {'max': '${AppConfig.monthlyLeaveMax}'});
        _messageError = true;
      });
      return;
    }
    setState(() => _busy = true);
    final bytes = await File(_file!.path).readAsBytes();
    final payload = <String, dynamic>{
      'type': 'leave',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'name': widget.user.name,
      'username': widget.user.username,
      'tehsil': widget.user.tehsil,
      'uc': widget.user.uc,
      'leaveDate': AppConfig.todayYmdPkt(),
      'leaveType': 'Casual',
      'reason': 'Casual Leave',
      'attachmentName': 'leave.jpg',
      'attachmentMime': 'image/jpeg',
      'attachmentBase64':
          'data:image/jpeg;base64,${base64Encode(bytes)}',
    };
    final result = await widget.sync.submit(payload);
    setState(() {
      _busy = false;
      _messageError = result != 'verified';
      _message = result == 'verified'
          ? lang.t('leaveVerified')
          : lang.t('leaveQueued');
      if (result == 'verified') _file = null;
    });
    if (result == 'verified') _loadBalance();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.user.openingRemaining - _yearUsed)
        .clamp(0, AppConfig.yearlyLeaveMax)
        .toInt();
    return ScreenScaffold(
      title: lang.t('leaveTitle'),
      subtitle: '${widget.user.name} — ${AppConfig.todayYmdPkt()}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(_balanceLoading
              ? lang.t('balanceLoading')
              : lang.t('balanceText', {
                  'm': '$_monthUsed',
                  'max': '${AppConfig.monthlyLeaveMax}',
                  'remaining': '$remaining',
                })),
          const SizedBox(height: 12),
          Text(lang.t('leaveDateLabel'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(AppConfig.todayYmdPkt(),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          BigButton(
            label: _file == null
                ? '📷 ${lang.t('takePhoto')}'
                : '📷 ${lang.t('retakePhoto')}',
            onPressed: _busy ? null : _pickFile,
            color: AppConfig.midGreen,
          ),
          const SizedBox(height: 12),
          BigButton(
              label: '📝 ${lang.t('sendLeave')}',
              onPressed: _busy ? null : _submit,
              color: AppConfig.danger),
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
