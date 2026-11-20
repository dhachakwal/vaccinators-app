import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/mock_location_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../widgets/common.dart';

/// Manual Live Location submit only — no Check-In / Check-Out (removed 19 Nov 2026, user order).
/// NEVER shows success until the sheet verifies the row.
/// Flow: Get My Location -> mock check -> Submit -> spinner -> green
/// only on verify, else red + Retry and the item stays in the queue.
/// All labels come from AppStrings (English or Urdu script).
///
/// ANTI-FAKE-LOCATION (MUST-HAVE, user order 19 Nov 2026):
/// every fix is mock-checked BEFORE it can be sent. While a mocked
/// fix is active the Send button is hidden and a blocking warning
/// is shown instead ("Turn off fake location"), with a button that
/// opens Location Settings and a "Check Again" button. The mocked
/// attempt is reported to the admin (type 'mockLocation', queued
/// offline like other payloads). A mocked fix never overwrites the
/// last verified fix, so the impossible-travel check stays honest.
class LocationScreen extends StatefulWidget {
  final Vaccinator user;
  final ApiService api;
  final StorageService storage;
  final SyncService sync;
  final LocationService location;
  final AppLanguage lang;
  const LocationScreen({
    super.key,
    required this.user,
    required this.api,
    required this.storage,
    required this.sync,
    required this.location,
    required this.lang,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _kit = TextEditingController();
  Position? _pos;
  bool _busy = false;
  String? _message;
  bool _messageError = false;
  MockLocationCheck? _mockCheck;
  bool _mockReported = false;

  AppLanguage get lang => widget.lang;
  bool get _isMocked => _mockCheck?.isMocked == true;

  Future<void> _getLocation() async {
    setState(() => _busy = true);
    final ok = await widget.location.ensurePermission();
    if (!ok) {
      setState(() {
        _busy = false;
        _message = lang.t('locPermError');
        _messageError = true;
      });
      return;
    }
    final prevTime = DateTime.tryParse(widget.storage.lastLocationAt ?? '');
    final checked = await widget.location.currentPositionChecked(
      previousLat: widget.storage.lastVerifiedLat,
      previousLng: widget.storage.lastVerifiedLng,
      previousTime: prevTime,
    );
    final p = checked.position;
    if (p == null) {
      setState(() {
        _busy = false;
        _pos = null;
        _mockCheck = null;
        _message = lang.t('locNotFound');
        _messageError = true;
      });
      return;
    }
    if (checked.check.isMocked) {
      // BLOCK: never store this fix as a real location, never let
      // it overwrite the last verified fix. Report once per attempt.
      if (!_mockReported) {
        _mockReported = true;
        await widget.sync.submit(MockLocationService.reportPayload(
          name: widget.user.name,
          username: widget.user.username,
          tehsil: widget.user.tehsil,
          uc: widget.user.uc,
          pos: p,
          check: checked.check,
        ));
      }
      setState(() {
        _busy = false;
        _pos = p;
        _mockCheck = checked.check;
        _message = lang.t('mockReported');
        _messageError = true;
      });
      return;
    }
    setState(() {
      _busy = false;
      _pos = p;
      _mockCheck = null;
      _mockReported = false;
      _message = null;
    });
  }

  /// Location is sent as type 'location' (the only location type
  /// the Apps Script handles today). See SyncService.
  Map<String, dynamic> _payload() {
    final p = _pos!;
    return {
      'type': 'location',
      'event': 'location',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'name': widget.user.name,
      'username': widget.user.username,
      'tehsil': widget.user.tehsil,
      'uc': widget.user.uc,
      'kitStation': _kit.text.trim(),
      'lat': p.latitude.toString(),
      'lng': p.longitude.toString(),
      'accuracy': p.accuracy.round().toString(),
      'maps': LocationService.mapsLink(p.latitude, p.longitude),
    };
  }

  Future<void> _submit() async {
    // Refuse even if the UI is somehow bypassed.
    if (_isMocked) {
      setState(() {
        _message = lang.t('mockBody');
        _messageError = true;
      });
      return;
    }
    if (_pos == null) {
      setState(() {
        _message = lang.t('locFirstGet');
        _messageError = true;
      });
      return;
    }
    if (_kit.text.trim().isEmpty) {
      setState(() {
        _message = lang.t('locKitEmpty');
        _messageError = true;
      });
      return;
    }
    setState(() => _busy = true);
    final result = await widget.sync.submit(_payload());
    if (result == 'verified') {
      final p = _pos!;
      await widget.storage.setLastVerifiedFix(
        lat: p.latitude,
        lng: p.longitude,
        iso: DateTime.now().toIso8601String(),
      );
      // First verified location starts background location (every 30 min).
      await LocationService.registerBackground({
        'name': widget.user.name,
        'username': widget.user.username,
        'tehsil': widget.user.tehsil,
        'uc': widget.user.uc,
        'kitStation': _kit.text.trim(),
      });
    }
    setState(() {
      _busy = false;
      _messageError = result != 'verified';
      _message = result == 'verified'
          ? lang.t('locSuccess', {'name': widget.user.name})
          : lang.t('locQueued');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('locTitle'),
      subtitle: '${widget.user.uc} · ${widget.user.tehsil}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _kit,
            decoration: InputDecoration(
              labelText: lang.t('kitStation'),
              hintText: lang.t('kitHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: '📍 ${lang.t('getLocation')}',
            onPressed: _busy ? null : _getLocation,
            color: AppConfig.midGreen,
          ),
          if (_isMocked) ...[
            const SizedBox(height: 12),
            InfoBox(
              '⛔ ${lang.t('mockTitle')}\n\n${lang.t('mockBody')}\n\n${lang.t('mockDetectedWhy', {'reasons': _mockCheck!.reasonKeys.map((k) => lang.t(k)).join(', ')})}',
              isError: true,
            ),
            const SizedBox(height: 12),
            BigButton(
              label: lang.t('mockOpenSettings'),
              onPressed: () => Geolocator.openLocationSettings(),
              color: AppConfig.danger,
            ),
            const SizedBox(height: 10),
            BigButton(
              label: '🔄 ${lang.t('mockCheckAgain')}',
              onPressed: _busy ? null : _getLocation,
            ),
          ] else ...[
            if (_pos != null) ...[
              const SizedBox(height: 12),
              InfoBox(
                  '${lang.t('locationReady')}\nLat: ${_pos!.latitude.toStringAsFixed(6)}\nLong: ${_pos!.longitude.toStringAsFixed(6)}\n${lang.t('accuracy', {'n': '${_pos!.accuracy.round()}'})}'),
            ],
            const SizedBox(height: 12),
            BigButton(
              label: '📍 ${lang.t('sendLocation')}',
              onPressed: _busy || _pos == null ? null : _submit,
              color: const Color(0xFF1565C0),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            InfoBox(_message!,
                isError: _messageError, isSuccess: !_messageError),
          ],
          const SizedBox(height: 12),
          InfoBox(lang.t('locNote')),
        ],
      ),
    );
  }
}
