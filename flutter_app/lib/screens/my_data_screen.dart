import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/microplan_service.dart';
import '../services/my_data_service.dart';
import '../widgets/common.dart';

/// S11 — My Data (user order, 19 Nov 2026 — PRIVACY RULE).
///
/// Shows the site's data for the logged-in vaccinator's OWN UC
/// only: (a) my attendance, (b) my doses by antigen, (c) my UC
/// summary (outreach + fixed), (d) my service record, (e) my
/// leave status. The UC comes ONLY from [user] (login) — there is
/// NO UC picker, NO search box and NO "all UCs" view on this
/// screen, so a vaccinator can never open another UC's data.
/// All labels come from AppStrings (English or Urdu script).
class MyDataScreen extends StatefulWidget {
  final Vaccinator user;
  final AppLanguage lang;
  const MyDataScreen({super.key, required this.user, required this.lang});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final MyDataService _service = MyDataService();
  final MicroplanService _microplans = MicroplanService();
  late MyDataMonth _month;
  MyDataBundle? _bundle;
  bool _loading = true;
  bool _fromCache = false;

  // My Microplan (user order, 19 Nov 2026; files audited
  // 20 Nov 2026): ONLY my own UC's file, downloaded on demand.
  MicroplanItem? _microplan;
  bool _microplanLoading = true;
  bool _microplanDownloaded = false;
  bool _microplanBusy = false;
  double? _microplanProgress;

  @override
  void initState() {
    super.initState();
    _month = MyDataMonth.available().first;
    _load();
    _loadMicroplan();
  }

  @override
  void dispose() {
    _service.dispose();
    _microplans.dispose();
    super.dispose();
  }

  Future<void> _loadMicroplan() async {
    setState(() => _microplanLoading = true);
    final (item, _) = await _microplans.fetchForUc(widget.user.uc);
    final downloaded =
        item == null ? false : await _microplans.isDownloaded(item);
    if (!mounted) return;
    setState(() {
      _microplan = item;
      _microplanDownloaded = downloaded;
      _microplanLoading = false;
      _microplanProgress = null;
    });
  }

  Future<void> _openMicroplan() async {
    final item = _microplan;
    if (item == null || _microplanBusy) return;
    setState(() {
      _microplanBusy = true;
      _microplanProgress = _microplanDownloaded ? null : 0;
    });
    bool ok;
    try {
      if (_microplanDownloaded) {
        ok = await _microplans.open(item);
      } else {
        await _microplans.download(item, onProgress: (rcv, total) {
          if (!mounted || total == null || total == 0) return;
          setState(() => _microplanProgress = rcv / total);
        });
        setState(() {
          _microplanDownloaded = true;
          _microplanProgress = null;
        });
        ok = await _microplans.open(item);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _microplanBusy = false;
      _microplanProgress = null;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.t(_microplanDownloaded
              ? 'microplanOpenFailed'
              : 'microplanDownloadFailed'))));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (bundle, fromCache) =
        await _service.fetchMyData(widget.user, _month);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _fromCache = fromCache;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final user = widget.user;
    final b = _bundle;
    return ScreenScaffold(
      title: lang.t('myDataTitle'),
      subtitle: '${user.name} — ${user.uc} · ${user.tehsil}',
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Privacy note — this screen shows ONLY my own UC.
              InfoBox(lang.t('myDataPrivacy')),
              const SizedBox(height: 12),
              // Month selector: current month + past months that
              // have Summary archive tabs (Out_YYYY-MM / Fix_YYYY-MM).
              // No UC selector exists on this screen — by design.
              Row(
                children: [
                  Text(lang.t('myDataMonth'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<MyDataMonth>(
                      value: _month,
                      isExpanded: true,
                      items: MyDataMonth.available()
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(lang == AppLanguage.urdu
                                    ? m.labelUr
                                    : m.labelEn),
                              ))
                          .toList(),
                      onChanged: (m) {
                        if (m == null) return;
                        setState(() => _month = m);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_fromCache && !_loading)
                InfoBox(lang.t('myDataOffline')),
              if (_fromCache && !_loading) const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (b == null || (b.hadError && b.attendance.isEmpty &&
                  b.records.isEmpty &&
                  b.outreachDoses.isEmpty &&
                  b.fixedDoses.isEmpty &&
                  b.leaves.isEmpty))
                InfoBox(lang.t('myDataLoadFailed'), isError: true)
              else ...[
                _microplanSection(),
                _section(
                  lang.t('myDataAttendance'),
                  lang.t('myDataPresentDays',
                      {'n': '${b.presentDays}'}),
                  b.attendance.isEmpty
                      ? Text(lang.t('myDataNoAttendance'))
                      : Column(
                          children: b.attendance
                              .map((d) => Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(d.date,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          '${lang.t('myDataCheckIn')} '
                                          '${d.checkIn.isEmpty ? '—' : d.checkIn} · '
                                          '${lang.t('myDataCheckOut')} '
                                          '${d.checkOut.isEmpty ? '—' : d.checkOut}',
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                  ))
                              .toList(),
                        ),
                ),
                _section(
                  lang.t('myDataDoses'),
                  lang.t('myDataTotal',
                      {'n': '${b.outreachTotal}'}),
                  b.outreachDoses.isEmpty
                      ? Text(lang.t('myDataNoDoses'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...b.appAntigenDoses.entries.map(
                              (e) => _doseRow(e.key, e.value),
                            ),
                            const SizedBox(height: 6),
                            ExpansionTile(
                              title: Text(lang.t('myDataAllAntigens'),
                                  style: const TextStyle(fontSize: 14)),
                              tilePadding: EdgeInsets.zero,
                              children: summaryAntigens
                                  .map((a) => _doseRow(
                                      a, b.outreachDoses[a] ?? 0))
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            Text(lang.t('myDataDailyReportNote'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                ),
                _section(
                  lang.t('myDataUcSummary'),
                  '${lang.t('myDataOutreach')}: ${b.outreachTotal}  ·  '
                  '${lang.t('myDataFixed')}: ${b.fixedTotal}  ·  '
                  '${lang.t('myDataCombined')}: '
                  '${b.outreachTotal + b.fixedTotal}',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.fixedFacilities.isEmpty)
                        Text(lang.t('myDataNoFixed'))
                      else
                        ...b.fixedFacilities.map(
                          (f) => _doseRow(f.$1, f.$2),
                        ),
                    ],
                  ),
                ),
                _section(
                  lang.t('myDataRecord'),
                  '',
                  b.records.isEmpty
                      ? Text(lang.t('myDataNoRecord'))
                      : Column(
                          children: b.records
                              .map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            StatusChip(
                                                label: r.type,
                                                ok: r.type
                                                        .toLowerCase()
                                                        .contains(
                                                            'appreciation')),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(r.subject,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${r.date} · ${r.refNo} · ${r.status}'
                                            '${r.issuedBy.isEmpty ? '' : ' · ${r.issuedBy}'}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
                _section(
                  lang.t('myDataLeave'),
                  lang.t('myDataBalance', {
                    'm': '${b.leaves.length}',
                    'max': '${AppConfig.monthlyLeaveMax}',
                    'remaining':
                        '${user.openingRemaining.toInt()}',
                  }),
                  b.leaves.isEmpty
                      ? Text(lang.t('myDataNoLeave'))
                      : Column(
                          children: b.leaves
                              .map((l) => Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(l.date,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(l.type),
                                    ],
                                  ))
                              .toList(),
                        ),
                ),
              ],
              const SizedBox(height: 12),
              BigButton(
                label: '🔄 ${lang.t('myDataRefresh')}',
                onPressed: _load,
                color: AppConfig.midGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// My Microplan — ONLY my own UC's file. Month-independent,
  /// so it sits above the monthly sections. The file is never
  /// baked into the APK: it downloads on demand (~700 KB) and
  /// then opens offline in the phone's spreadsheet viewer.
  Widget _microplanSection() {
    final lang = widget.lang;
    final item = _microplan;
    Widget body;
    if (_microplanLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (item == null) {
      body = Text(lang.t('microplanNotFound'));
    } else if (item.needsConversion) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.file} · ${item.sizeLabel}'),
          const SizedBox(height: 6),
          Text(lang.t('microplanConverting'),
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.vaccinator.isNotEmpty)
            Text('${lang.t('microplanVaccinator')}: ${item.vaccinator}'),
          if (item.population != null)
            _kvRow(lang.t('microplanPopulation'), '${item.population}'),
          if (item.villageCount != null)
            _kvRow(lang.t('microplanVillages'), '${item.villageCount}'),
          if (item.areaCount != null)
            _kvRow(lang.t('microplanAreas'), '${item.areaCount}'),
          if (item.sessionCount != null)
            _kvRow(lang.t('microplanSessions'), '${item.sessionCount}'),
          if (item.sheetCount != null)
            _kvRow(lang.t('microplanSheets'), '${item.sheetCount}'),
          _kvRow(lang.t('microplanFileSize'), item.sizeLabel),
          if (_microplanDownloaded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lang.t('microplanSaved'),
                  style: const TextStyle(
                      fontSize: 13, color: AppConfig.success)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lang.t('microplanNeedInternet'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          const SizedBox(height: 10),
          if (_microplanProgress != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: _microplanProgress),
                const SizedBox(height: 4),
                Text(lang.t('microplanDownloading', {
                  'pct': '${(_microplanProgress! * 100).round()}'
                })),
              ],
            )
          else
            BigButton(
              label: _microplanDownloaded
                  ? '📂 ${lang.t('microplanOpen')}'
                  : '⬇️ ${lang.t('microplanDownload', {'size': item.sizeLabel})}',
              onPressed: _microplanBusy ? null : _openMicroplan,
              color: AppConfig.darkGreen,
            ),
        ],
      );
    }
    return _section(
      lang.t('microplanTitle'),
      item == null
          ? ''
          : lang.t('microplanSub', {
              'uc': item.uc,
              'tehsil': item.tehsil,
              'year': '${item.year}',
            }),
      body,
    );
  }

  Widget _kvRow(String name, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _section(String title, String summary, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(summary,
                  style: const TextStyle(
                      fontSize: 14, color: AppConfig.darkGreen)),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _doseRow(String name, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name)),
          Text('$value',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
