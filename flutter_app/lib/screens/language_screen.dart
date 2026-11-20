import 'package:flutter/material.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../services/language_service.dart';
import '../widgets/common.dart';

/// First-run language picker — exactly two options, no Roman Urdu:
/// اردو (Urdu, proper script) or English.
/// Shown before login when no language has been chosen yet.
/// The picker itself is bilingual so it is usable either way.
class LanguageScreen extends StatelessWidget {
  final LanguageService language;
  final VoidCallback onPicked;
  const LanguageScreen({
    super.key,
    required this.language,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Vaccinators App',
      subtitle: 'EPI District Chakwal',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'اپنی زبان منتخب کریں',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your language',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          BigButton(
            label: 'اردو',
            onPressed: () async {
              await language.setLanguage(AppLanguage.urdu);
              onPicked();
            },
          ),
          const SizedBox(height: 12),
          BigButton(
            label: 'English',
            onPressed: () async {
              await language.setLanguage(AppLanguage.english);
              onPicked();
            },
            color: AppConfig.midGreen,
          ),
          const SizedBox(height: 24),
          const InfoBox(
            'آپ اسے بعد میں اپنی پروفائل سے بدل سکتے ہیں۔\nYou can change this later from your Profile.',
          ),
        ],
      ),
    );
  }
}
