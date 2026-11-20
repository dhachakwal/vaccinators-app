import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Login: Tehsil -> UC -> Name (roster from All Vaccinators Profile),
/// then mobile + 4-digit PIN.
/// PIN note: the PIN column does not exist in the sheet yet (see
/// GOAL.md). Until it does, v1 accepts any 4-digit PIN on first login
/// and stores it locally; the admin PIN check is marked pending.
/// The roster itself is cached, so login works offline after day 1.
/// All labels come from AppStrings (English or Urdu script) —
// no Roman Urdu anywhere in this app (user order, 19 Nov 2026).
class LoginScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;
  final AppLanguage lang;
  final VoidCallback onLoggedIn;
  const LoginScreen({
    super.key,
    required this.api,
    required this.storage,
    required this.lang,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<Vaccinator> _roster = [];
  String? _tehsil, _uc, _name;
  final _mobile = TextEditingController();
  final _pin = TextEditingController();
  bool _loading = true;
  String? _error;

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    var list = widget.storage.roster;
    try {
      final fresh = await widget.api.loadRoster();
      if (fresh.isNotEmpty) {
        list = fresh;
        await widget.storage.saveRoster(fresh);
      }
    } catch (_) {
      // Offline: use the cache. Empty cache = show the error below.
    }
    if (mounted) {
      setState(() {
        _roster = list;
        _loading = false;
      });
    }
  }

  List<String> get _tehsils =>
      _roster.map((v) => v.tehsil).toSet().toList()..sort();
  List<String> get _ucs => _roster
      .where((v) => v.tehsil == _tehsil)
      .map((v) => v.uc)
      .toSet()
      .toList()
    ..sort();
  List<Vaccinator> get _names =>
      _roster.where((v) => v.tehsil == _tehsil && v.uc == _uc).toList();

  void _login() {
    final v = _names.where((e) => e.name == _name).toList();
    if (v.isEmpty) {
      setState(() => _error = lang.t('loginSelectError'));
      return;
    }
    if (_pin.text.trim().length != 4) {
      setState(() => _error = lang.t('loginPinError'));
      return;
    }
    widget.storage.saveLogin(v.first).then((_) => widget.onLoggedIn());
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: lang.t('loginTitle'),
      subtitle: '${lang.t('appSubtitle')} — ${lang.t('appTitle')}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(lang.t('loginInfo')),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_roster.isEmpty)
            InfoBox(lang.t('rosterEmpty'), isError: true)
          else ...[
            DropdownButtonFormField<String>(
              value: _tehsil,
              decoration: InputDecoration(
                  labelText: lang.t('tehsil'),
                  border: const OutlineInputBorder()),
              items: _tehsils
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() {
                    _tehsil = v;
                    _uc = null;
                    _name = null;
                  }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _uc,
              decoration: InputDecoration(
                  labelText: lang.t('uc'),
                  border: const OutlineInputBorder()),
              items: _ucs
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() {
                    _uc = v;
                    _name = null;
                  }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _name,
              decoration: InputDecoration(
                  labelText: lang.t('yourName'),
                  border: const OutlineInputBorder()),
              items: _names
                  .map((v) =>
                      DropdownMenuItem(value: v.name, child: Text(v.name)))
                  .toList(),
              onChanged: (v) {
                final sel = _names.firstWhere((e) => e.name == v);
                setState(() {
                  _name = v;
                  _mobile.text = sel.username;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: lang.t('mobile'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: lang.t('pin'),
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            BigButton(label: lang.t('loginButton'), onPressed: _login),
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoBox(_error!, isError: true),
            ],
            const SizedBox(height: 8),
            Text(
              lang.t('pinPendingNote'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
