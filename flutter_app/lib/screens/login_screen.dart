import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';

/// Login: Tehsil -> UC -> Name (roster from All Vaccinators Profile),
/// then mobile + 4-digit PIN.
/// The PIN is checked against the roster: every vaccinator has a PIN
/// in column O ("PIN") of the profile tab (last 4 digits of their
/// username; Zain Islam 1234). A wrong PIN is refused — there is no
/// demo / without-login path (removed v1.0.5, user order 22 Nov 2026).
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
    // Real PIN check (v1.0.5): the entered PIN must match the PIN
    // on the vaccinator's roster row. No PIN on the row, or a
    // mismatch, refuses the login — fail closed, no demo path.
    if (v.first.pin.isEmpty || _pin.text.trim() != v.first.pin) {
      setState(() => _error = lang.t('loginWrongPin'));
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
          // EPI logo (v1.0.6) — the app finally has its own logo.
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/epi_logo.png',
                height: 96,
                width: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          ],
        ],
      ),
    );
  }
}
