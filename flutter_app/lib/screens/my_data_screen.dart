import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/microplan_service.dart';
import '../services/my_data_service.dart';
import '../services/reports_service.dart';
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
  final ReportsService _reports = ReportsService();
  late MyDataMonth _month;
  MyDataBundle? _bundle;
  bool _loading = true;
  bool _fromCache = false;
  // v1.0.6: my own submitted reports, as day -> total doses, for
  // the selected month (daily trend graph).
  Map<int, int> _dailyDoses = {};

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
    _reports.dispose();
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
    // Daily trend: my own submitted reports for the selected month.
    final daily = <int, int>{};
    try {
      final (mine, _) =
          await _reports.fetchMySubmittedReports(widget.user);
      for (final r in mine) {
        if (!r.date.startsWith(_month.key)) continue;
        final day = int.tryParse(r.date.split('-').last) ?? 0;
        if (day <= 0) continue;
        daily[day] = (daily[day] ?? 0) + r.total;
      }
    } catch (_) {
      // Trend is a bonus — a failure here never blocks My Data.
    }
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _fromCache = fromCache;
      _dailyDoses = daily;
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
                _summaryCard(b),
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
                            Text(lang.t('myDataDosesChart'),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ..._antigenBars(b.appAntigenDoses),
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
                  lang.t('myDataDailyTrend'),
                  '',
                  _dailyDoses.isEmpty
                      ? Text(lang.t('myDataNoTrend'))
                      : _trendChart(),
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

  /// v1.0.6 — Overall A-to-Z summary (user order 22 Nov 2026):
  /// total doses, days present, leave taken, service records.
  Widget _summaryCard(MyDataBundle b) {
    final lang = widget.lang;
    final total = b.outreachTotal + b.fixedTotal;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.t('myDataSummary'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _statTile(
                        '$total', lang.t('myDataTileDoses'))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statTile('${b.presentDays}',
                        lang.t('myDataTilePresent'))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _statTile('${b.leaves.length}',
                        lang.t('myDataTileLeave'))),
                const SizedBox(width: 8),
                Expanded(
                    child: _statTile('${b.records.length}',
                        lang.t('myDataTileRecords'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.darkGreen)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Horizontal bars for doses by antigen (no chart package —
  /// plain proportional bars, so the APK stays lean).
  List<Widget> _antigenBars(Map<String, int> doses) {
    final maxV = doses.values.fold<int>(0, (a, v) => v > a ? v : a);
    return doses.entries.map((e) {
      final frac = maxV > 0 ? e.value / maxV : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(e.key,
                  style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppConfig.midGreen),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text('${e.value}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Vertical bars: my own submitted doses per day this month.
  /// Days run 1..last day of the selected month (current month:
  /// only up to today).
  Widget _trendChart() {
    final nowPkt = DateTime.now().toUtc().add(const Duration(hours: 5));
    final lastDay = _month.isCurrent
        ? nowPkt.day
        : DateTime(_month.year, _month.month + 1, 0).day;
    final maxV = _dailyDoses.values.fold<int>(0, (a, v) => v > a ? v : a);
    final days = List<int>.generate(lastDay, (i) => i + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final v = _dailyDoses[d] ?? 0;
              final h = maxV > 0 ? (v / maxV) * 84 : 0.0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(v > 0 ? '$v' : '',
                        style: const TextStyle(fontSize: 9)),
                    Container(
                      height: v > 0 ? (h < 4 ? 4 : h) : 2,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: v > 0
                            ? AppConfig.midGreen
                            : const Color(0xFFE0E0E0),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: days
              .map((d) => Expanded(
                    child: Text(
                      d % 5 == 1 || d == lastDay ? '$d' : '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
