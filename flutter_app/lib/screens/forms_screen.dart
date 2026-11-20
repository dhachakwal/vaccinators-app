import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../services/forms_service.dart';
import '../widgets/common.dart';

/// DYNAMIC GOOGLE FORMS (user order, 19 Nov 2026).
/// The list comes from `forms.json` on the EPI site — never
/// hard-coded — so a new form reaches vaccinators with NO APK
/// update. Each form opens INSIDE the app in a WebView.
/// All labels come from AppStrings (English or Urdu script).
class FormsScreen extends StatefulWidget {
  final AppLanguage lang;
  const FormsScreen({super.key, required this.lang});

  @override
  State<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends State<FormsScreen> {
  final _service = FormsService();
  List<GoogleFormItem> _items = [];
  Set<String> _submitted = {};
  bool _loading = true;
  bool _fromCache = false;

  AppLanguage get lang => widget.lang;
  bool get isUrdu => lang == AppLanguage.urdu;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (items, fromCache) = await _service.fetchForms();
    final submitted = await _service.submittedIds();
    if (mounted) {
      setState(() {
        _items = items;
        _submitted = submitted;
        _fromCache = fromCache;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('formsTitle'),
      subtitle: lang.t('formsSub'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            InfoBox(lang.t('formsEmpty'))
          else ...[
            if (_fromCache) InfoBox(lang.t('formsOffline')),
            ..._items.map((f) {
              final submitted = _submitted.contains(f.id);
              final open = f.isOpen;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  title: Text(f.titleFor(isUrdu),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (f.descFor(isUrdu).isNotEmpty)
                        Text(f.descFor(isUrdu)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (f.required)
                            StatusChip(
                                label: lang.t('formsRequired'), ok: false),
                          if (submitted)
                            StatusChip(
                                label: lang.t('formsSubmitted'), ok: true)
                          else if (!open)
                            StatusChip(
                                label: f.isClosed
                                    ? lang.t('formsClosed')
                                    : lang.t('formsNotYetOpen'),
                                ok: false),
                          if (f.closeDate.isNotEmpty)
                            Text(
                              lang.t('formsDeadline',
                                  {'date': f.closeDate}),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: AppConfig.darkGreen),
                  onTap: open
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FormWebViewScreen(
                                    form: f, lang: lang)),
                          );
                          // Back from the form: refresh the
                          // submitted marks (the viewer may have
                          // marked this form submitted).
                          final ids = await _service.submittedIds();
                          if (mounted) setState(() => _submitted = ids);
                        }
                      : null,
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          BigButton(
            label: lang.t('refresh'),
            onPressed: _load,
            color: AppConfig.midGreen,
          ),
          const SizedBox(height: 12),
          InfoBox(lang.t('formsFillNote')),
        ],
      ),
    );
  }
}

/// One Google Form, opened INSIDE the app in a WebView.
/// Google Forms needs JavaScript (enabled) and internet — filling
/// a form offline is NOT possible, and the screen says so plainly.
/// Submit detection: Google Forms has NO reliable submit callback.
/// The app marks the form submitted locally when the WebView lands
/// on a `formResponse` confirmation page (heuristic), or when the
/// vaccinator taps "Mark as submitted". The real record is always
/// the form's own response sheet — the app never claims otherwise.
class FormWebViewScreen extends StatefulWidget {
  final GoogleFormItem form;
  final AppLanguage lang;
  const FormWebViewScreen(
      {super.key, required this.form, required this.lang});

  @override
  State<FormWebViewScreen> createState() => _FormWebViewScreenState();
}

class _FormWebViewScreenState extends State<FormWebViewScreen> {
  late final WebViewController _controller;
  final _service = FormsService();
  int _progress = 0;
  bool _loadError = false;
  bool _marked = false;

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (url) async {
            // Google Forms confirmation page after Submit.
            // Heuristic only — see the class comment above.
            if (url.contains('formResponse') && !_marked) {
              _marked = true;
              await _service.markSubmitted(widget.form.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.t('formsSubmittedThanks'))));
              }
            }
          },
          onWebResourceError: (error) {
            // No net / form unreachable — show the error state
            // instead of a blank WebView.
            if (mounted) setState(() => _loadError = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.form.formUrl));
  }

  Future<void> _markSubmitted() async {
    await _service.markSubmitted(widget.form.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.t('formsSubmittedThanks'))));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F4),
      appBar: AppBar(
        backgroundColor: AppConfig.darkGreen,
        foregroundColor: Colors.white,
        title: Text(form.titleFor(lang == AppLanguage.urdu),
            style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: lang.t('formsOpenBrowser'),
            onPressed: () async {
              final uri = Uri.parse(form.formUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100 && !_loadError)
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: const Color(0xFFC8E6C9),
              color: AppConfig.darkGreen,
            ),
          Expanded(
            child: _loadError
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InfoBox(lang.t('formsNeedsNet'), isError: true),
                        const SizedBox(height: 12),
                        BigButton(
                          label: lang.t('updateRetry'),
                          onPressed: () {
                            setState(() => _loadError = false);
                            _controller.reload();
                          },
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(lang.t('formsFillNote'),
                    style:
                        const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                BigButton(
                  label: lang.t('formsMarkSubmitted'),
                  onPressed: _markSubmitted,
                  color: AppConfig.midGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
