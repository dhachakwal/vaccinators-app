import 'dart:io';
import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/reports_service.dart';
import '../widgets/common.dart';

/// S12 — Daily Reports in-app (user order, 19 Nov 2026).
///
/// The same 11 daily reports the nightly pipeline sends on
/// WhatsApp at 3:00 AM PKT also arrive here, every morning —
/// read from `reports.json` on the EPI site (see
/// ReportsService). Each vaccinator sees ONLY their own UC's
/// reports + district-wide ones: the UC comes ONLY from [user]
/// (login) — there is NO UC picker, NO search, NO "all UCs" view
/// on this screen, so a vaccinator can never open another UC's
/// reports. PNGs open inside the app; PDFs open in the phone's
/// PDF viewer. "Save offline" keeps a copy on the phone.
///
/// Honest states: until the pipeline uploads the files and
/// writes reports.json, this screen shows "no reports yet" —
/// the app never generates a report itself and never pretends
/// one exists.
class ReportsScreen extends StatefulWidget {
  final Vaccinator user;
  final AppLanguage lang;
  const ReportsScreen(
      {super.key, required this.user, required this.lang});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsService _service = ReportsService();
  List<ReportDay> _days = [];
  // v1.0.6: my own submitted daily reports, day-wise.
  List<MySubmittedReport> _mine = [];
  bool _loading = true;
  bool _fromCache = false;
  bool _hadError = false;
  Set<String> _downloaded = {};
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (days, fromCache) =
        await _service.fetchForUc(widget.user.uc);
    final (mine, _) =
        await _service.fetchMySubmittedReports(widget.user);
    if (!mounted) return;
    final downloaded = <String>{};
    for (final d in days) {
      for (final it in d.items) {
        if (await _service.isDownloaded(it)) downloaded.add(it.id);
      }
    }
    if (!mounted) return;
    setState(() {
      _days = days;
      _mine = mine;
      _fromCache = fromCache;
      _hadError = days.isEmpty && fromCache;
      _downloaded = downloaded;
      _loading = false;
    });
  }

  Future<void> _saveOffline(DailyReportItem item) async {
    if (_downloading.contains(item.id)) return;
    setState(() => _downloading.add(item.id));
    try {
      await _service.download(item);
      if (!mounted) return;
      setState(() {
        _downloaded = {..._downloaded, item.id};
        _downloading.remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.t('reportsSaved'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _downloading.remove(item.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.t('reportsOpenFailed'))));
    }
  }

  Future<void> _open(DailyReportItem item) async {
    final lang = widget.lang;
    if (item.isPng) {
      File? file;
      try {
        file = await _service.ensureLocal(item);
      } catch (_) {
        file = null;
      }
      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.t('reportsOpenFailed'))));
        return;
      }
      setState(() => _downloaded = {..._downloaded, item.id});
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ReportImageScreen(
                  item: item,
                  file: file!,
                  lang: lang,
                )),
      );
      return;
    }
    // PDF — download (if not saved) and open in the phone's viewer.
    final ok = await _service.openPdf(item);
    if (!mounted) return;
    if (ok) {
      setState(() => _downloaded = {..._downloaded, item.id});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.t('reportsNoViewer'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final user = widget.user;
    final isUrdu = lang == AppLanguage.urdu;
    final today = _days.where((d) => d.isToday).toList();
    final past = _days.where((d) => !d.isToday).toList();
    return ScreenScaffold(
      title: lang.t('reportsTitle'),
      subtitle: '${user.name} — ${user.uc} · ${user.tehsil}',
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Privacy note — only my own UC + district reports.
              InfoBox(lang.t('reportsPrivacy')),
              const SizedBox(height: 12),
              if (_fromCache && !_loading)
                InfoBox(lang.t('reportsOffline')),
              if (_fromCache && !_loading) const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // v1.0.6: MY OWN submitted reports, day-wise, FIRST.
                _dayHeader(lang.t('reportsMine')),
                if (_mine.isEmpty)
                  InfoBox(lang.t('reportsMineEmpty'))
                else
                  for (final r in _mine) _mineRow(r, isUrdu),
                const SizedBox(height: 16),
                if (_hadError)
                  InfoBox(lang.t('reportsLoadFailed'), isError: true)
                else if (_days.isEmpty)
                  InfoBox(lang.t('reportsEmpty'))
                else ...[
                  if (today.isNotEmpty) ...[
                    _dayHeader(lang.t('reportsToday')),
                    for (final it in today.first.items) _row(it, isUrdu),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _dayHeader(lang.t('reportsPast')),
                    for (final d in past) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Text(
                          d.label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      for (final it in d.items) _row(it, isUrdu),
                    ],
                  ],
                ],
              ],
              const SizedBox(height: 12),
              InfoBox(lang.t('reportsPipelineNote')),
            ],
          ),
        ),
      ),
    );
  }

  /// One of my own submitted daily reports: date + antigen counts.
  Widget _mineRow(MySubmittedReport r, bool isUrdu) {
    final lang = widget.lang;
    final parts = <String>[
      'BCG ${r.bcg}',
      'Penta-1 ${r.pentaI}',
      'Penta-2 ${r.pentaII}',
      'Penta-3 ${r.pentaIII}',
      'MR-1 ${r.mr1}',
      'MR-2 ${r.mr2}',
      'DTP ${r.dtp}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  lang.t('totalChildren', {'n': '${r.total}'}),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.darkGreen),
                ),
              ],
            ),
            if (r.kitStation.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(r.kitStation, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 4),
            Text(parts.join('  ·  '),
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _dayHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      );

  Widget _row(DailyReportItem item, bool isUrdu) {
    final lang = widget.lang;
    final saved = _downloaded.contains(item.id);
    final busy = _downloading.contains(item.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(item.isPdf ? '📄' : '🖼️',
            style: const TextStyle(fontSize: 26)),
        title: Text(item.titleFor(isUrdu),
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: Text(
          item.isDistrictWide
              ? lang.t('reportsDistrict')
              : lang.t('reportsMyUc', {'uc': item.uc}),
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saved)
              const StatusChip(label: '✓', ok: true)
            else if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              IconButton(
                tooltip: lang.t('reportsDownload'),
                icon: const Icon(Icons.download),
                color: AppConfig.darkGreen,
                onPressed: () => _saveOffline(item),
              ),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppConfig.darkGreen),
          ],
        ),
        onTap: () => _open(item),
      ),
    );
  }
}

/// PNG viewer — the image opens INSIDE the app (pinch to zoom).
/// Shows the saved copy when present, otherwise the site URL.
class ReportImageScreen extends StatelessWidget {
  final DailyReportItem item;
  final File file;
  final AppLanguage lang;
  const ReportImageScreen({
    super.key,
    required this.item,
    required this.file,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isUrdu = lang == AppLanguage.urdu;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppConfig.darkGreen,
        foregroundColor: Colors.white,
        title: Text(item.titleFor(isUrdu),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, st) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  lang.t('reportsOpenFailed'),
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
