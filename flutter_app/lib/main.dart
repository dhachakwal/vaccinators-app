import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config.dart';
import 'l10n/app_strings.dart';
import 'models/vaccinator.dart';
import 'screens/admin_late_screen.dart';
import 'screens/admin_map_screen.dart';
import 'screens/home_screen.dart';
import 'screens/language_screen.dart';
import 'screens/leave_screen.dart';
import 'screens/location_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_screen.dart';
import 'screens/update_screen.dart';
import 'services/api_service.dart';
import 'services/language_service.dart';
import 'services/location_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/update_service.dart';

/// Vaccinators App v1 — EPI District Chakwal.
/// Language rule (user order, 19 Nov 2026 — STANDING): NO Roman
/// Urdu anywhere. Exactly two languages: English, or Urdu in proper
/// Urdu script. The user picks on first run (LanguageScreen) and can
/// change it later in Profile. Urdu switches the app to RTL via
/// flutter_localizations.
/// Entry point: Workmanager for background location, then language
/// picker (first run) -> login (saved) or home with 5 bottom tabs:
/// Home / Location / Report / Leave / Profile. Admin screens are
/// reached from Profile when the logged-in user is the admin.
/// Calls (V2, wired 19 Nov 2026): a "Calls" card on Home opens the
/// contacts list (roster + admin) — NOT a 6th bottom tab, 5 tabs
/// already crowd low-end phones. Placing a call still needs
/// Firebase signalling; tapping a call button shows the honest
/// "calling setup pending" message (see CallService.signallingReady),
/// never a fake call and never a crash.
/// FORCED UPDATE (user order, 19 Nov 2026 — STANDING RULE): the
/// update check runs on EVERY launch BEFORE login/home. A newer
/// version on the site blocks the app with a full-screen update
/// screen (UpdateScreen) — first update, then the app runs. Only
/// an update marked `optional: true` in version.json may be
/// skipped ("Later"). If version.json cannot be reached at all,
/// the app opens normally with a small note (server-down exception).
/// Offline-queue sync runs on every launch (after the update check,
/// and only when no forced update is pending).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Do NOT initialise Workmanager here: LocationService
  // .registerBackground() initialises it (once, with the real
  // dispatcher) after login / first location. Initialising twice crashes.
  runApp(const VaccinatorsApp());
}

class VaccinatorsApp extends StatefulWidget {
  const VaccinatorsApp({super.key});

  @override
  State<VaccinatorsApp> createState() => _VaccinatorsAppState();
}

class _VaccinatorsAppState extends State<VaccinatorsApp> {
  final _language = LanguageService();
  bool _langReady = false;

  @override
  void initState() {
    super.initState();
    _language.load().then((_) {
      if (mounted) setState(() => _langReady = true);
    });
    _language.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _language.removeListener(_onLanguageChanged);
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_langReady) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final lang = _language.language;
    // Urdu: fontFamily 'Noori Nastaliq' first, bundled Noto Nastaliq
    // Urdu as fallback (see assets/fonts/README.md — the Noori file
    // itself is supplied by the user; until then Noto renders).
    // English: default system font. Nastaliq needs tall lines, so
    // the Urdu text theme uses height 1.9 (descenders must not clip).
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.darkGreen),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConfig.darkGreen,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConfig.darkGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
    // NOTE: fontFamily is a ThemeData *constructor* parameter, not a
    // copyWith parameter — the earlier copyWith version did not
    // compile (flutter analyze: undefined_named_parameter). So the
    // Urdu theme is built as its own ThemeData, same values as base.
    final theme = lang == AppLanguage.urdu
        ? ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: AppConfig.darkGreen),
            useMaterial3: true,
            fontFamily: 'Noori Nastaliq',
            fontFamilyFallback: const ['Noto Nastaliq Urdu'],
            appBarTheme: const AppBarTheme(
              backgroundColor: AppConfig.darkGreen,
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.darkGreen,
                foregroundColor: Colors.white,
              ),
            ),
            textTheme: _urduTextTheme(baseTheme.textTheme),
          )
        : baseTheme;
    return MaterialApp(
      title: 'Vaccinators App — EPI Chakwal',
      debugShowCheckedModeBanner: false,
      // Urdu (ur) switches layout to RTL automatically.
      locale: lang.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ur')],
      theme: theme,
      home: RootScreen(language: _language),
    );
  }
}

/// Urdu text theme: same styles as the base theme, but every slot
/// gets line height 1.9 so Nastaliq descenders are never clipped.
TextTheme _urduTextTheme(TextTheme base) {
  TextStyle? h(TextStyle? s) => s?.copyWith(height: 1.9);
  return base.copyWith(
    displayLarge: h(base.displayLarge),
    displayMedium: h(base.displayMedium),
    displaySmall: h(base.displaySmall),
    headlineLarge: h(base.headlineLarge),
    headlineMedium: h(base.headlineMedium),
    headlineSmall: h(base.headlineSmall),
    titleLarge: h(base.titleLarge),
    titleMedium: h(base.titleMedium),
    titleSmall: h(base.titleSmall),
    bodyLarge: h(base.bodyLarge),
    bodyMedium: h(base.bodyMedium),
    bodySmall: h(base.bodySmall),
    labelLarge: h(base.labelLarge),
    labelMedium: h(base.labelMedium),
    labelSmall: h(base.labelSmall),
  );
}

class RootScreen extends StatefulWidget {
  final LanguageService language;
  const RootScreen({super.key, required this.language});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  late final ApiService _api;
  late SyncService _sync; // not final: _boot() re-runs after the update screen returns.
  StorageService? _storage;
  Vaccinator? _user;
  int _tab = 0;
  // v1.0.1 (open lag): tabs the user already visited. Only the
  // active tab — plus visited ones, so their state survives — is
  // in the widget tree. Building all five screens eagerly on
  // every launch cost the first frame.
  final Set<int> _visitedTabs = {0};
  bool _ready = false;
  AppUpdate? _pendingUpdate;

  AppLanguage get lang => widget.language.language;

  @override
  void initState() {
    super.initState();
    _api = ApiService();
    _boot();
  }

  Future<void> _boot() async {
    final storage = await StorageService.init();
    _sync = SyncService(_api, storage);
    if (!mounted) return;
    // v1.0.1 (open lag): show the app as soon as local storage is
    // ready — do NOT wait for the network update check first. On
    // slow field data the check held the app on a spinner for up
    // to 15 s, which felt like the app was frozen on open.
    setState(() {
      _storage = storage;
      _user = storage.login;
      _ready = true;
    });
    // 1. Offline-queue sync runs in the background.
    unawaited(_sync.syncAll());
    // 2. Update check runs in the background too. A FORCED update
    // still blocks the app — it just takes over once the check
    // returns, instead of holding the launch. A failed check (no
    // net / site down) opens the app normally with a small note
    // (server-down exception, unchanged).
    final update = await UpdateService().check();
    if (!mounted) return;
    if (update != null && update.isForced) {
      setState(() => _pendingUpdate = update);
      return;
    }
    if (update != null && update.isNewer) {
      // Optional update only (isForced is false here): the
      // vaccinator may press "Later" and keep using this version.
      _showOptionalUpdateDialog(update);
    } else if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.t('updateCheckFailed'))));
    }
  }

  void _showOptionalUpdateDialog(AppUpdate update) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('newVersionTitle', {'v': update.versionName})),
        content: Text(
            update.whatsNew.isNotEmpty ? update.whatsNew : lang.t('newVersionBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('later')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUpdateScreen(update);
            },
            child: Text(lang.t('downloadNow')),
          ),
        ],
      ),
    );
  }

  void _openUpdateScreen(AppUpdate update) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => UpdateScreen(update: update, lang: lang)),
    ).then((_) {
      // Coming back from an optional update screen: re-check, so a
      // skipped optional update is offered again next launch, and a
      // forced update that appeared meanwhile still blocks.
      if (mounted) _boot();
    });
  }

  void _goToTab(int t) => setState(() {
        _tab = t;
        _visitedTabs.add(t);
      });

  /// Builds one tab only when it is visited; unvisited tabs are a
  /// cheap placeholder, so they cost nothing on launch. Once a tab
  /// is built it stays in the IndexedStack, so its state survives
  /// tab switches.
  Widget _buildTab(int i) {
    if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
    final user = _user;
    final storage = _storage;
    if (user == null || storage == null) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return HomeScreen(
          user: user,
          api: _api,
          storage: storage,
          pendingCount: storage.queue.length,
          lang: lang,
          onGo: _goToTab,
        );
      case 1:
        return LocationScreen(
          user: user,
          api: _api,
          storage: storage,
          sync: _sync,
          location: LocationService(),
          lang: lang,
        );
      case 2:
        return ReportScreen(user: user, sync: _sync, lang: lang);
      case 3:
        return LeaveScreen(
            user: user,
            api: _api,
            storage: storage,
            sync: _sync,
            lang: lang);
      case 4:
        return ProfileScreen(
          user: user,
          storage: storage,
          sync: _sync,
          lang: lang,
          language: widget.language,
          onLogout: _logout,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // Admin = the district user. v1 rule: username "admin" — replace
  // with the real admin username when the admin login is set up.
  bool get _isAdmin => _user?.username.toLowerCase() == 'admin';

  void _logout() async {
    await _storage?.logout();
    await LocationService.cancelBackground();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _storage == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(lang.t('appTitle')),
            ],
          ),
        ),
      );
    }
    // FORCED update blocks everything — even the language picker
    // and login. The update screen uses the saved language, or
    // English until the user picks one.
    if (_pendingUpdate != null) {
      return UpdateScreen(update: _pendingUpdate!, lang: lang);
    }
    // First run: no language chosen yet -> picker, before login.
    if (!widget.language.hasChoice) {
      return LanguageScreen(
        language: widget.language,
        onPicked: () => setState(() {}),
      );
    }
    final user = _user;
    if (user == null) {
      return LoginScreen(
        api: _api,
        storage: _storage!,
        lang: lang,
        onLoggedIn: () => setState(() => _user = _storage!.login),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _buildTab(0),
          _buildTab(1),
          _buildTab(2),
          _buildTab(3),
          _buildTab(4),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConfig.darkGreen,
        unselectedItemColor: Colors.grey,
        onTap: _goToTab,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: lang.t('navHome')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.location_on),
              label: lang.t('navLocation')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.vaccines), label: lang.t('navReport')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.beach_access),
              label: lang.t('navLeave')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person), label: lang.t('navProfile')),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppConfig.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.map),
              label: Text(lang.t('adminMap')),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AdminMapScreen(api: _api, lang: lang)),
                );
              },
            )
          : null,
      drawer: _isAdmin
          ? Drawer(
              child: ListView(
                children: [
                  DrawerHeader(
                    decoration:
                        const BoxDecoration(color: AppConfig.darkGreen),
                    child: Text(lang.t('adminTitle'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.map),
                    title: Text(lang.t('liveMap')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AdminMapScreen(api: _api, lang: lang)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.list),
                    title: Text(lang.t('lateTitle')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AdminLateScreen(api: _api, lang: lang)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: Text(lang.t('notifTitle')),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                NotificationsScreen(lang: lang)),
                      );
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
