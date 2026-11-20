import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

/// Persists the user's language choice (Urdu script or English).
/// Stored under key 'app_language' as 'ur' or 'en'.
/// Default is English until the user picks on first run; [hasChoice]
/// is false until then, so the app shows the language picker first.
class LanguageService extends ChangeNotifier {
  static const _kLanguage = 'app_language';

  AppLanguage _language = AppLanguage.english;
  bool _hasChoice = false;

  AppLanguage get language => _language;
  bool get hasChoice => _hasChoice;
  bool get isUrdu => _language == AppLanguage.urdu;

  /// Load the saved choice (if any). Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLanguage);
    if (code != null) {
      _language = AppLanguageInfo.fromCode(code);
      _hasChoice = true;
    }
    notifyListeners();
  }

  /// Save a new choice and rebuild the UI in that language.
  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    _hasChoice = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, lang.code);
    notifyListeners();
  }
}
