import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../models/vaccinator.dart';
import 'api_service.dart';

/// MESSAGE PARENTS — FREE (user question, 19 Nov 2026: can we send
/// free messages to parents from this app?).
///
/// ANSWER BUILT INTO THE DESIGN: true free SMS does not exist —
/// an SMS always costs the carrier. What IS free:
///  - **WhatsApp** — free beyond mobile data. The app builds the
///    message and opens the parent's chat in the vaccinator's own
///    WhatsApp (`wa.me/<number>?text=...`); the vaccinator taps
///    Send there. The message goes from the VACCINATOR's own
///    WhatsApp number — parents see that number, not a district
///    number. No server, no gateway, no cost to the district.
///  - **SMS composer** — fallback when WhatsApp is not installed.
///    The app opens the phone's own SMS composer, prefilled; the
///    SMS costs whatever the vaccinator's own mobile package
///    already charges (usually a bundle SMS, often free).
///
/// HARD RULES:
///  - **One message at a time, no bulk send.** WhatsApp bans bulk /
///    automated sending; a bulk sender gets the number banned. The
///    app never loops over parents — the vaccinator taps Send for
///    each parent, in their own WhatsApp.
///  - **No new parent database.** Parent numbers come ONLY from
///    the EXISTING EMR sheet (the same sheet the site's
///    Verification Calls module reads: 35 columns, Phone is
///    column 11 / header 'PhoneNumber' / 'Phone Number' /
///    'Cell #' / 'Cell'). Rows are read for the vaccinator's OWN
///    UC only (server-side gviz `where upper(D) = 'MY UC'`, like
///    My Data) — there is no UC picker and no other UC's children
///    are ever listed.
///  - **First name only** in the message text — no full family
///    details, no address, no MR number.
///  - The app never claims the message was delivered: WhatsApp /
///    SMS open in the other app and the vaccinator presses Send
///    there. The result reported here is only "opened" or "failed
///    to open".
///
/// HONEST LIMITS: (1) WhatsApp must be installed for the free
/// route — without it the app offers the SMS composer instead.
/// (2) Filling the message needs the parent's number in the EMR
/// sheet; a row with no phone shows "no number" and cannot be
/// messaged from the list. (3) The EMR sheet must be shared
/// "Anyone with the link can view" like the master sheet, or the
/// list shows "could not load". (4) The EMR tab name is tried in
/// the site's own order ('Nov-2026', 'Nov 2026', ... — see
/// AppConfig.emrMonthTabCandidates); a live run against the real
/// sheet is still needed to confirm the tab + headers.

/// One child row from the EMR sheet (own UC only).
class ParentChild {
  final String name;
  final String father;
  final String age;
  final String gender;
  final String phone;
  final String nextDue; // '' when every antigen is done.
  /// Last vaccination/record update (EMR LastUpdatedDate). Null
  /// when the sheet has none — the child was never recorded as
  /// vaccinated. Used for the due/defaulter filter (v1.0.6).
  final DateTime? lastUpdated;

  const ParentChild({
    required this.name,
    required this.father,
    required this.age,
    required this.gender,
    required this.phone,
    required this.nextDue,
    this.lastUpdated,
  });

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'father': father,
        'age': age,
        'gender': gender,
        'phone': phone,
        'nextDue': nextDue,
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory ParentChild.fromJson(Map<String, dynamic> m) => ParentChild(
        name: (m['name'] ?? '').toString(),
        father: (m['father'] ?? '').toString(),
        age: (m['age'] ?? '').toString(),
        gender: (m['gender'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        nextDue: (m['nextDue'] ?? '').toString(),
        lastUpdated: m['lastUpdated'] == null
            ? null
            : DateTime.tryParse(m['lastUpdated'].toString()),
      );
}

enum MessageTemplate { due, missed, verification, custom }

enum MessageSendResult { whatsapp, sms, failed, invalidNumber }

/// EMR antigen columns in the site's order (EMR_COLS / EMR_ANTIGENS
/// in index.html). The first antigen with no dose is the next due.
/// [header] is the sheet header to match, [label] is what the
/// message shows.
const List<(String, String)> _emrAntigens = [
  ('bcg', 'BCG'),
  ('opv0', 'OPV-0'),
  ('opvI', 'OPV-1'),
  ('opvII', 'OPV-2'),
  ('opvIII', 'OPV-3'),
  ('pentaI', 'Penta-1'),
  ('pentaII', 'Penta-2'),
  ('pentaIII', 'Penta-3'),
  ('pneumoI', 'PCV-1'),
  ('pneumoII', 'PCV-2'),
  ('pneumoIII', 'PCV-3'),
  ('ipv', 'IPV-1'),
  ('measlesI', 'MR-1'),
  ('measlesII', 'MR-2'),
  ('hepB', 'Hep-B'),
  ('rota1', 'Rota-1'),
  ('rota2', 'Rota-2'),
  ('ipv2', 'IPV-2'),
  ('dpt', 'DTP'),
  ('tcv', 'TCV'),
];

class MessageService {
  final http.Client _client;
  MessageService([http.Client? client]) : _client = client ?? http.Client();

  void dispose() => _client.close();

  // ---------- Phone normalisation (Pakistani mobiles) ----------

  /// '0301-2345678' / '+92 301 2345678' / '923012345678' ->
  /// '923012345678' (what wa.me needs). Returns null when the
  /// number is not a plausible Pakistani mobile (3XX + 7 digits).
  static String? normalizePakistaniMobile(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('92') && d.length == 12) {
      // already country code
    } else if (d.startsWith('0') && d.length == 11) {
      d = '92${d.substring(1)}';
    } else if (d.length == 10 && d.startsWith('3')) {
      d = '92$d';
    } else {
      return null;
    }
    if (!d.startsWith('923') || d.length != 12) return null;
    return d;
  }

  // ---------- Templates (English + Urdu script, NO Roman Urdu) ----------

  /// Builds the message text in [lang]. Only the child's FIRST
  /// name goes in — never the full name, address or MR number.
  /// [date] is the due/missed date as the vaccinator typed it
  /// (dd-MM-yyyy); [customText] is used only for the custom
  /// template. [parentName] puts the parent's name first (v1.0.6).
  /// The signature is always 'EPI Chakwal' / 'ای پی آئی چکوال'.
  /// v1.0.6 (user order 22 Nov 2026): when [parentName] is given,
  /// the parent's name comes FIRST (on top), then the message in
  /// the user's own words — "your child has the [vaccine]
  /// injection due, please get the injection done" — with no date.
  static String buildMessage(
    MessageTemplate template,
    AppLanguage lang, {
    required String childFirstName,
    String parentName = '',
    String vaccine = '',
    String date = '',
    String customText = '',
  }) {
    final ur = lang == AppLanguage.urdu;
    final name = childFirstName.trim();
    final parent = parentName.trim();
    if (parent.isNotEmpty &&
        (template == MessageTemplate.due ||
            template == MessageTemplate.missed)) {
      if (template == MessageTemplate.due) {
        return ur
            ? '$parent صاحب،\nالسلام علیکم! آپ کے بچے $name کو $vaccine کا انجیکشن due ہے۔ برائے مہربانی انجیکشن لگوا جائیں۔ — ای پی آئی چکوال'
            : '$parent,\nAssalam-o-Alaikum! Your child $name is due for the $vaccine injection. Please get the injection done. — EPI Chakwal';
      }
      return ur
          ? '$parent صاحب،\nالسلام علیکم! آپ کے بچے $name کی $vaccine ویکسین رہ گئی ہے۔ برائے مہربانی جلد از جلد انجیکشن لگوا جائیں۔ — ای پی آئی چکوال'
          : '$parent,\nAssalam-o-Alaikum! Your child $name missed the $vaccine vaccine. Please get the injection done as soon as possible. — EPI Chakwal';
    }
    switch (template) {
      case MessageTemplate.due:
        return ur
            ? 'السلام علیکم، $name کی $vaccine ویکسین $date کو لگنی ہے۔ براہ کرم اپنے بچے کو قریبی ای پی آئی مرکز پر لے آئیں۔ — ای پی آئی چکوال'
            : 'Assalam-o-Alaikum, $name is due for the $vaccine vaccine on $date. Please bring your child to the nearest EPI centre. — EPI Chakwal';
      case MessageTemplate.missed:
        return ur
            ? 'السلام علیکم، $name کی $vaccine ویکسین $date کو رہ گئی ہے۔ براہ کرم جلد از جلد اپنے بچے کو قریبی ای پی آئی مرکز پر لے آئیں۔ — ای پی آئی چکوال'
            : 'Assalam-o-Alaikum, $name missed the $vaccine vaccine on $date. Please bring your child to the nearest EPI centre as soon as possible. — EPI Chakwal';
      case MessageTemplate.verification:
        return ur
            ? 'السلام علیکم، $name کی ویکسینیشن کے بارے میں آپ سے رابطہ کرنے کی کوشش کی گئی لیکن رابطہ نہیں ہو سکا۔ براہ کرم اس پیغام کا جواب دیں یا واپس کال کریں۔ — ای پی آئی چکوال'
            : 'Assalam-o-Alaikum, we tried to call you about $name\'s vaccination but could not reach you. Please reply to this message or call back. — EPI Chakwal';
      case MessageTemplate.custom:
        return customText.trim();
    }
  }

  // ---------- Sending (opens the other app — no gateway) ----------

  static Uri _whatsappUri(String waNumber, String text) => Uri.parse(
      'https://wa.me/$waNumber?text=${Uri.encodeComponent(text)}');

  static Uri _smsUri(String waNumber, String text) => Uri.parse(
      'sms:+$waNumber?body=${Uri.encodeComponent(text)}');

  /// Opens the parent's chat in the vaccinator's own WhatsApp with
  /// the message prefilled. Returns true when WhatsApp opened —
  /// the vaccinator still has to tap Send there. False when
  /// WhatsApp is not installed / cannot open (caller offers SMS).
  static Future<bool> openWhatsApp(String rawPhone, String text) async {
    final wa = normalizePakistaniMobile(rawPhone);
    if (wa == null) return false;
    final uri = _whatsappUri(wa, text);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the phone's own SMS composer, prefilled. The SMS costs
  /// whatever the vaccinator's mobile package charges.
  static Future<bool> openSms(String rawPhone, String text) async {
    final wa = normalizePakistaniMobile(rawPhone);
    if (wa == null) return false;
    final uri = _smsUri(wa, text);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// WhatsApp first (free), SMS composer as fallback. Returns what
  /// actually happened — never claims delivery.
  static Future<MessageSendResult> sendParentMessage(
      String rawPhone, String text) async {
    if (normalizePakistaniMobile(rawPhone) == null) {
      return MessageSendResult.invalidNumber;
    }
    if (await openWhatsApp(rawPhone, text)) {
      return MessageSendResult.whatsapp;
    }
    if (await openSms(rawPhone, text)) {
      return MessageSendResult.sms;
    }
    return MessageSendResult.failed;
  }

  // ---------- Children in MY UC (EMR sheet, read-only gviz) ----------

  /// gviz read (same parse as ApiService.readTab / MyDataService).
  Future<List<Map<String, dynamic>>> _readGviz(String url) async {
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Sheet read failed');
    final body = res.body;
    final a = body.indexOf('{');
    final b = body.lastIndexOf('}');
    if (a < 0 || b < 0) throw Exception('Bad gviz body');
    final data = jsonDecode(body.substring(a, b + 1)) as Map<String, dynamic>;
    final table = data['table'] as Map<String, dynamic>?;
    if (table == null) return [];
    final cols = (table['cols'] as List)
        .map((c) => ((c as Map)['label'] ?? '').toString().toLowerCase().trim())
        .toList();
    final rows = (table['rows'] as List?) ?? [];
    return rows.map((r) {
      final cells = ((r as Map)['c'] as List?) ?? [];
      final m = <String, dynamic>{};
      for (var i = 0; i < cols.length; i++) {
        final cell = i < cells.length ? cells[i] : null;
        dynamic v = '';
        if (cell is Map) {
          v = cell['v'] ?? cell['f'] ?? '';
        }
        m[cols[i]] = v;
      }
      return m;
    }).toList();
  }

  /// Is this antigen dose given? Mirrors the site's dose() logic:
  /// empty, 'no', 'n/a', 'na', '-' or 'null' (or a '#'-error
  /// value) means NOT given.
  static bool _doseGiven(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v == 'no' ||
        v == 'n/a' ||
        v == 'na' ||
        v == '-' ||
        v == 'null' ||
        v.contains('#')) {
      return false;
    }
    return true;
  }

  static String _nextDue(Map<String, dynamic> row) {
    for (final (header, label) in _emrAntigens) {
      final raw = ApiService.pick(row, [header.toLowerCase()]) ?? '';
      if (!_doseGiven(raw)) return label;
    }
    return '';
  }

  /// Parse an EMR date cell: gviz "Date(y,m,d)" (0-based month),
  /// ISO yyyy-MM-dd, or dd-MM-yyyy / dd/MM/yyyy. Null when the
  /// cell is empty or unparseable.
  static DateTime? _parseEmrDate(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty || s.contains('#')) return null;
    final dm = RegExp(r'Date\((\d+),(\d+),(\d+)').firstMatch(s);
    if (dm != null) {
      return DateTime(
        int.parse(dm.group(1)!),
        int.parse(dm.group(2)!) + 1,
        int.parse(dm.group(3)!),
      );
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final parts = s.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null && y > 1900) {
        return DateTime(y, m, d);
      }
    }
    return null;
  }

  /// Due/defaulter rule (user order 22 Nov 2026): the child has a
  /// dose still pending (nextDue non-empty) AND has had no
  /// vaccination recorded this month — the list is current through
  /// the last day (the nightly EMR refresh), so a child vaccinated
  /// up to the last day is already excluded. A child with no
  /// LastUpdatedDate at all was never recorded as vaccinated, so
  /// they count as a defaulter.
  static bool _isDueDefaulter(ParentChild c, DateTime monthStart) {
    if (c.nextDue.isEmpty) return false;
    final u = c.lastUpdated;
    if (u == null) return true;
    return u.isBefore(monthStart);
  }

  static ParentChild _rowToChild(Map<String, dynamic> row) {
    final name = (ApiService.pick(row, ['name', 'child name']) ??
            ApiService.pick(row, ['firstname', 'first name']) ??
            '')
        .toString()
        .trim();
    final father = (ApiService.pick(row, ['fathername', 'father name']) ?? '')
        .toString()
        .trim();
    final phone = (ApiService.pick(row, [
              'phonenumber',
              'phone number',
              'relativephonenumber',
              'cell #',
              'cell'
            ]) ??
            '')
        .toString()
        .trim();
    return ParentChild(
      name: name,
      father: father,
      age: (ApiService.pick(row, ['age']) ?? '').toString().trim(),
      gender: (ApiService.pick(row, ['gender']) ?? '').toString().trim(),
      phone: phone,
      nextDue: _nextDue(row),
      lastUpdated:
          _parseEmrDate(ApiService.pick(row, ['lastupdateddate'])),
    );
  }

  static String _cacheKey(Vaccinator user) =>
      'msg_children_${user.username}_${user.uc}';

  /// Children of the logged-in vaccinator's OWN UC, from the EMR
  /// sheet's current-month tab. Server-side gviz filter
  /// (`where upper(D) = 'MY UC'` — UC is column D) so other UCs'
  /// rows never leave the server; the list is then mapped by
  /// header name (resilient to column order). Tries the site's own
  /// tab-name order for the current month. Returns (children,
  /// fromCache, error). The cache holds ONLY the filtered own-UC
  /// list.
  Future<(List<ParentChild>, bool, bool)> fetchMyUcChildren(
      Vaccinator user) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _cacheKey(user);
    List<ParentChild> fromCache() {
      try {
        final raw = prefs.getString(key);
        if (raw == null || raw.isEmpty) return [];
        final list = jsonDecode(raw) as List;
        return list
            .map((e) =>
                ParentChild.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
      } catch (_) {
        return [];
      }
    }

    try {
      final tabs = AppConfig.emrMonthTabCandidates();
      for (final tab in tabs) {
        try {
          final safe = user.uc.replaceAll("'", "\\'");
          final tq =
              "select * where upper(D) = '${safe.toUpperCase()}'";
          final rows = await _readGviz(
              AppConfig.gvizUrlFor(AppConfig.emrSheetId, tab, tq));
          // Same guard as the site: a real month tab has rows and
          // at least 10 columns; otherwise try the next tab name.
          if (rows.isEmpty) continue;
          // v1.0.6: DUE/DEFAULTER ONLY (user order 22 Nov 2026) —
          // a pending dose + no vaccination this month (list is
          // current through the last day). Fully-vaccinated and
          // recently-vaccinated children are NOT listed.
          final nowPkt =
              DateTime.now().toUtc().add(const Duration(hours: 5));
          final monthStart = DateTime(nowPkt.year, nowPkt.month, 1);
          final children = rows
              .map(_rowToChild)
              .where((c) => c.name.isNotEmpty)
              .where((c) => _isDueDefaulter(c, monthStart))
              .toList();
          if (children.isEmpty) continue;
          children.sort((a, b) {
            final au = a.lastUpdated;
            final bu = b.lastUpdated;
            if (au == null && bu == null) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
            if (au == null) return -1;
            if (bu == null) return 1;
            final byDate = au.compareTo(bu);
            return byDate != 0
                ? byDate
                : a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          await prefs.setString(key,
              jsonEncode(children.map((c) => c.toJson()).toList()));
          return (children, false, false);
        } catch (_) {
          // Try the next tab name.
        }
      }
      // No tab matched — fall back to the cached own-UC list.
      final cached = fromCache();
      if (cached.isNotEmpty) return (cached, true, false);
      return (<ParentChild>[], false, true);
    } catch (_) {
      final cached = fromCache();
      if (cached.isNotEmpty) return (cached, true, false);
      return (<ParentChild>[], false, true);
    }
  }
}
