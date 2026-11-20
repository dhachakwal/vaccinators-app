import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

/// S10 Admin Late / Missing List — admin only.
/// People with no location by 10:00 AM: roster minus today's
/// Location submitters, minus today's Leave rows (shown in red).
/// Filter chips: All / Late / Missing / On Leave. Share via WhatsApp
/// as professional English text.
class AdminLateScreen extends StatefulWidget {
  final ApiService api;
  final AppLanguage lang;
  const AdminLateScreen({super.key, required this.api, required this.lang});

  @override
  State<AdminLateScreen> createState() => _AdminLateScreenState();
}

class _AdminLateScreenState extends State<AdminLateScreen> {
  List<Vaccinator> _missing = [];
  List<Vaccinator> _onLeave = [];
  // Fake-location attempts today, from the `MockLocation` tab
  // (type 'mockLocation'). Empty until the Apps Script adds the tab.
  List<Map<String, dynamic>> _mocked = [];
  bool _loading = true;
  String _filter = 'All';

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final roster = await widget.api.loadRoster();
      final locRows = await widget.api.loadLocationRowsToday();
      final leaveRows = await widget.api.loadLeaveRows();
      final mockRows = await widget.api.loadMockLocationRows();
      final today = AppConfig.todayYmdPkt();
      final submitted = locRows
          .where((r) =>
              (ApiService.pick(r, ['timestamp', 'time']) ?? '')
                  .startsWith(today))
          .map((r) =>
              ApiHelpers.normUserKey(ApiService.pick(r, ['username']) ?? ''))
          .toSet();
      final onLeaveKeys = leaveRows
          .where((r) {
            final raw =
                ApiService.pick(r, ['leave date', 'leavedate', 'date']) ?? '';
            return raw.contains(today);
          })
          .map((r) =>
              ApiHelpers.normUserKey(ApiService.pick(r, ['username']) ?? ''))
          .toSet();
      final missing = <Vaccinator>[];
      final leave = <Vaccinator>[];
      for (final v in roster) {
        final k = ApiHelpers.normUserKey(v.username);
        if (submitted.contains(k)) continue;
        if (onLeaveKeys.contains(k)) {
          leave.add(v);
        } else {
          missing.add(v);
        }
      }
      final todayMocked = mockRows.where((r) {
        final raw =
            ApiService.pick(r, ['timestamp', 'time']) ?? '';
        return raw.startsWith(today);
      }).toList();
      if (mounted) {
        setState(() {
          _missing = missing;
          _onLeave = leave;
          _mocked = todayMocked;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Vaccinator> get _shown {
    if (_filter == 'On Leave') return _onLeave;
    if (_filter == 'Missing') return _missing;
    if (_filter == 'Fake Location') return [];
    return [..._missing, ..._onLeave];
  }

  // Fake-location rows are raw sheet rows, not roster entries:
  // name / UC / Tehsil / time / reasons come straight from the tab.
  String _mockLine(Map<String, dynamic> r) {
    final name = ApiService.pick(r, ['name']) ?? '';
    final uc = ApiService.pick(r, ['union council', 'uc']) ?? '';
    final tehsil = ApiService.pick(r, ['tehsil']) ?? '';
    final time = ApiService.pick(r, ['timestamp', 'time']) ?? '';
    final reasons = ApiService.pick(r, ['reasons']) ?? '';
    final lat = ApiService.pick(r, ['latitude', 'lat']) ?? '';
    final lng = ApiService.pick(r, ['longitude', 'long', 'lng']) ?? '';
    return '$name — $uc · $tehsil\n$time\n$reasons\n$lat, $lng';
  }

  Future<void> _share() async {
    final lines = _missing
        .map((v) => '- ${v.name} (${v.uc}, ${v.tehsil})')
        .join('\n');
    final fakeLines = _mocked.map((r) {
      final name = ApiService.pick(r, ['name']) ?? '';
      final uc = ApiService.pick(r, ['union council', 'uc']) ?? '';
      return '- $name ($uc) — FAKE LOCATION';
    }).join('\n');
    final text = Uri.encodeComponent(
        'EPI Chakwal — Location Missing (10:00 AM, ${AppConfig.todayYmdPkt()})\n'
        'Missing: ${_missing.length} / 70\n$lines'
        '${_mocked.isEmpty ? '' : '\nFake location: ${_mocked.length}\n$fakeLines'}');
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('lateTitle'),
      subtitle: lang.t('lateSub', {'date': AppConfig.todayYmdPkt()}),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: ['All', 'Missing', 'On Leave', 'Fake Location'].map((f) {
              final selected = _filter == f;
              final label = f == 'All'
                  ? lang.t('filterAll')
                  : f == 'Missing'
                      ? lang.t('filterMissing')
                      : f == 'Fake Location'
                          ? lang.t('filterFake')
                          : lang.t('filterOnLeave');
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          InfoBox(
              lang.t('missingSummary', {
                'm': '${_missing.length}',
                'l': '${_onLeave.length}',
              }),
              isError: _missing.isNotEmpty),
          const SizedBox(height: 8),
          // Fake-location flag — the admin sees WHO tried it, when,
          // and with which mocked coordinates. Red, always visible
          // when there is at least one attempt today.
          if (_mocked.isNotEmpty)
            InfoBox(
              '⛔ ${lang.t('fakeSummary', {'n': '${_mocked.length}'})}',
              isError: true,
            ),
          const SizedBox(height: 8),
          BigButton(
              label: '📤 ${lang.t('shareWhatsApp')}',
              onPressed: _share,
              color: AppConfig.midGreen),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_filter == 'Fake Location')
            _mocked.isEmpty
                ? InfoBox(lang.t('fakeListEmpty'), isSuccess: true)
                : Column(
                    children: _mocked.map((r) {
                      return Card(
                        color: const Color(0xFFFFEBEE),
                        child: ListTile(
                          title: Text(
                              (ApiService.pick(r, ['name']) ?? ''),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(_mockLine(r)),
                          trailing: Chip(
                              label: Text(lang.t('filterFake'),
                                  style: const TextStyle(
                                      color: Colors.white)),
                              backgroundColor: AppConfig.danger),
                        ),
                      );
                    }).toList(),
                  )
          else if (_shown.isEmpty)
            InfoBox('${lang.t('allSent')} 🎉', isSuccess: true)
          else
            ..._shown.map((v) {
              final leave =
                  _onLeave.any((e) => e.username == v.username);
              return Card(
                child: ListTile(
                  title: Text(v.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${v.uc} · ${v.tehsil}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leave)
                        Chip(
                            label: Text(lang.t('filterOnLeave'),
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: AppConfig.danger)
                      else
                        IconButton(
                          icon: const Icon(Icons.call,
                              color: AppConfig.darkGreen),
                          onPressed: () async {
                            final tel = Uri(
                                scheme: 'tel', path: v.username);
                            if (await canLaunchUrl(tel)) {
                              await launchUrl(tel);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
