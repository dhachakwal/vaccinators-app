import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// DYNAMIC GOOGLE FORMS (user order, 19 Nov 2026).
///
/// Sometimes the admin needs extra data from vaccinators and today
/// uses Google Forms. The app shows those forms INSIDE the app, and
/// a NEW form reaches vaccinators WITHOUT an APK update: the form
/// LIST is fetched from the server on every launch / refresh — it is
/// never hard-coded in the app.
///
/// Source: `forms.json` on the EPI site
/// (https://dhachakwal.github.io/EPI-Chakwal/forms.json).
/// The admin publishes a new form by editing ONLY that file
/// (see README Step 7) — no APK rebuild, no version bump.
///
/// Responses land in the Google Form's own response sheet
/// (standard Google Forms behaviour — no new code, no Apps Script).
/// The app never claims to know whether a form was really
/// submitted: Google Forms has no reliable submit callback, so the
/// app marks a form "Submitted" locally when (a) the WebView lands
/// on a `formResponse` confirmation URL (heuristic), or (b) the
/// vaccinator taps "Mark as submitted" — see FormWebViewScreen.
/// Offline: the cached list is shown, but filling a Google Form
/// NEEDS internet — offline fill is NOT possible with embedded
/// Google Forms. That limit is stated plainly on the screen.
class GoogleFormItem {
  final String id;
  final String title;
  final String titleUr;
  final String description;
  final String descriptionUr;
  final String formUrl;
  final String responsesUrl;
  final String openDate; // yyyy-MM-dd, empty = no start bound
  final String closeDate; // yyyy-MM-dd, empty = no end bound
  final bool required;

  const GoogleFormItem({
    required this.id,
    required this.title,
    required this.titleUr,
    required this.description,
    required this.descriptionUr,
    required this.formUrl,
    required this.responsesUrl,
    required this.openDate,
    required this.closeDate,
    required this.required,
  });

  factory GoogleFormItem.fromJson(Map<String, dynamic> j) => GoogleFormItem(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        titleUr: (j['titleUr'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        descriptionUr: (j['descriptionUr'] ?? '').toString(),
        formUrl: (j['formUrl'] ?? '').toString(),
        responsesUrl: (j['responsesUrl'] ?? '').toString(),
        openDate: (j['openDate'] ?? '').toString(),
        closeDate: (j['closeDate'] ?? '').toString(),
        required: j['required'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'titleUr': titleUr,
        'description': description,
        'descriptionUr': descriptionUr,
        'formUrl': formUrl,
        'responsesUrl': responsesUrl,
        'openDate': openDate,
        'closeDate': closeDate,
        'required': required,
      };

  /// Title in the vaccinator's language (Urdu script or English).
  String titleFor(bool isUrdu) =>
      isUrdu && titleUr.isNotEmpty ? titleUr : title;
  String descFor(bool isUrdu) =>
      isUrdu && descriptionUr.isNotEmpty ? descriptionUr : description;

  /// Open / closed / not-yet-open, from the PKT date.
  /// Empty openDate = already open; empty closeDate = never closes.
  bool get isOpen {
    final today = AppConfig.todayYmdPkt();
    if (openDate.isNotEmpty && today.compareTo(openDate) < 0) return false;
    if (closeDate.isNotEmpty && today.compareTo(closeDate) > 0) return false;
    return true;
  }

  bool get isClosed =>
      closeDate.isNotEmpty &&
      AppConfig.todayYmdPkt().compareTo(closeDate) > 0;
  bool get notYetOpen =>
      openDate.isNotEmpty &&
      AppConfig.todayYmdPkt().compareTo(openDate) < 0;
}

class FormsService {
  static const _kCache = 'forms_cache_json';
  static const _kSubmitted = 'forms_submitted_ids';

  /// Fetches the live list from the site. On any failure (no net,
  /// site down, bad file) returns the cached list instead — the
  /// caller shows the cached list with an offline note, never a
  /// blank screen. Returns ([items], [fromCache]).
  Future<(List<GoogleFormItem>, bool)> fetchForms() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.formsUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final list = (j is List ? j : (j['forms'] as List? ?? []));
        final items = list
            .map((e) => GoogleFormItem.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .where((f) => f.id.isNotEmpty && f.formUrl.isNotEmpty)
            .toList();
        // Required first, then open forms, then by closing date.
        items.sort((a, b) {
          if (a.required != b.required) return a.required ? -1 : 1;
          if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
          return a.closeDate.compareTo(b.closeDate);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCache, res.body);
        return (items, false);
      }
    } catch (_) {
      // Fall through to the cache below.
    }
    return (await cachedForms(), true);
  }

  /// Last successfully fetched list (empty before the first fetch).
  Future<List<GoogleFormItem>> cachedForms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw == null) return [];
      final j = jsonDecode(raw);
      final list = (j is List ? j : (j['forms'] as List? ?? []));
      return list
          .map((e) => GoogleFormItem.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .where((f) => f.id.isNotEmpty && f.formUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Locally submitted form ids (the app's own record only — the
  /// real record is the Google Form's response sheet).
  Future<Set<String>> submittedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kSubmitted) ?? []).toSet();
  }

  Future<void> markSubmitted(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_kSubmitted) ?? []).toSet()..add(id);
    await prefs.setStringList(_kSubmitted, ids.toList());
  }
}
