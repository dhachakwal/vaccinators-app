import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// MY MICROPLAN in My Data (user order, 19 Nov 2026; files
/// received + audited 20 Nov 2026).
///
/// The 83 UC microplan workbooks (RED/REC 2026, 58 MB total) live
/// on the EPI site under `microplans/<Tehsil>/<file>` and are
/// listed in `microplans.json` (see files/microplans.json for the
/// exact format + the generator script in hidden_files/).
///
/// The app downloads ONLY the logged-in vaccinator's OWN UC file,
/// on demand — never the whole 58 MB, never baked into the APK.
/// The file is saved on the phone and opens in the phone's
/// spreadsheet viewer (Excel / Google Sheets); the app has no
/// built-in spreadsheet renderer and never pretends otherwise.
///
/// PRIVACY RULE (same as My Data — a rule, not a filter): the UC
/// comes ONLY from the login. The manifest is fetched whole (it is
/// a public site file, like forms.json), but the service returns
/// ONLY the entry matching my UC — every other UC's entry is
/// dropped in memory immediately, never cached as "mine", never
/// displayed. There is no UC picker and no way to open another
/// UC's file.
///
/// UC matching: the 83 files and the roster/site do not spell
/// every UC the same way (audit, 20 Nov 2026), so matching is by
/// normalised comparison — upper-case, non-alphanumerics stripped
/// — against the entry's `uc` AND its `aliases` (e.g. file
/// "Talagang-1" matches roster "TALAGANG URBAN I" via its alias;
/// file "Jand Awan" matches roster "JAND"). Aliases were built so
/// a near neighbour can never steal a match ("Lawa Urban" is NOT
/// an alias of "Lawa Rural").
///
/// The 2 old .xls files (Maingon, Dhermond) are listed in the
/// manifest with `needsConversion: true` — they must be converted
/// to .xlsx BEFORE publishing. The app never downloads or opens
/// them; it shows "being converted" instead.
///
/// Offline: the last fetched manifest is cached, and a downloaded
/// microplan stays on the phone — with no net the screen shows
/// the saved file with an offline note. A file never downloaded
/// cannot be opened offline, and the screen says so plainly.
class MicroplanItem {
  final String uc;
  final String tehsil;
  final String vaccinator;
  final String file;
  final String url;
  final int year;
  final int? sheetCount;
  final int? population;
  final int? villageCount;
  final int? areaCount;
  final int? sessionCount;
  final int sizeKb;
  final bool needsConversion;
  final List<String> aliases;

  const MicroplanItem({
    required this.uc,
    required this.tehsil,
    required this.vaccinator,
    required this.file,
    required this.url,
    required this.year,
    required this.sheetCount,
    required this.population,
    required this.villageCount,
    required this.areaCount,
    required this.sessionCount,
    required this.sizeKb,
    required this.needsConversion,
    required this.aliases,
  });

  factory MicroplanItem.fromJson(Map<String, dynamic> j) => MicroplanItem(
        uc: (j['uc'] ?? '').toString(),
        tehsil: (j['tehsil'] ?? '').toString(),
        vaccinator: (j['vaccinator'] ?? '').toString(),
        file: (j['file'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt() ?? 2026,
        sheetCount: (j['sheetCount'] as num?)?.toInt(),
        population: (j['population'] as num?)?.toInt(),
        villageCount: (j['villageCount'] as num?)?.toInt(),
        areaCount: (j['areaCount'] as num?)?.toInt(),
        sessionCount: (j['sessionCount'] as num?)?.toInt(),
        sizeKb: (j['sizeKb'] as num?)?.toInt() ?? 0,
        needsConversion: j['needsConversion'] == true,
        aliases: ((j['aliases'] as List?) ?? [])
            .map((a) => a.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'uc': uc,
        'tehsil': tehsil,
        'vaccinator': vaccinator,
        'file': file,
        'url': url,
        'year': year,
        'sheetCount': sheetCount,
        'population': population,
        'villageCount': villageCount,
        'areaCount': areaCount,
        'sessionCount': sessionCount,
        'sizeKb': sizeKb,
        'needsConversion': needsConversion,
        'aliases': aliases,
      };

  /// "441 KB" / "1.6 MB" for the Download button.
  String get sizeLabel =>
      sizeKb >= 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '$sizeKb KB';

  /// True when this entry is the logged-in vaccinator's own UC —
  /// normalised comparison against `uc` and every alias.
  bool matchesUc(String myUc) {
    final mine = MicroplanService.normalizeUc(myUc);
    if (mine.isEmpty) return false;
    if (MicroplanService.normalizeUc(uc) == mine) return true;
    return aliases
        .any((a) => MicroplanService.normalizeUc(a) == mine);
  }
}

class MicroplanService {
  static const _kCache = 'microplans_cache_json';

  final http.Client _client;
  MicroplanService([http.Client? client]) : _client = client ?? http.Client();

  void dispose() => _client.close();

  /// Upper-case, non-alphanumerics stripped: "Talagang-1" ->
  /// "TALAGANG1", "TALAGANG URBAN I" -> "TALAGANGURBANI".
  /// The alias list bridges the spellings that still differ
  /// after this (see the manifest generator).
  static String normalizeUc(String uc) =>
      uc.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  MicroplanItem? _findIn(String raw, String myUc) {
    try {
      final j = jsonDecode(raw);
      final list = (j is Map ? (j['microplans'] as List? ?? []) : <dynamic>[]);
      for (final e in list) {
        final item = MicroplanItem.fromJson(
            Map<String, dynamic>.from(e as Map));
        if (item.url.isEmpty) continue;
        if (item.matchesUc(myUc)) return item;
      }
    } catch (_) {
      // Bad manifest — treated as "not found", never a crash.
    }
    return null;
  }

  /// Fetches the live manifest and returns ONLY my own UC's
  /// entry. On any failure (no net, site down, bad file, not
  /// published yet) returns the cached entry, filtered the same
  /// way — never another UC's file. Returns (item, fromCache);
  /// item is null when no entry matches my UC at all.
  Future<(MicroplanItem?, bool)> fetchForUc(String myUc) async {
    try {
      final res = await _client
          .get(Uri.parse(AppConfig.microplansUrl))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCache, res.body);
        return (_findIn(res.body, myUc), false);
      }
    } catch (_) {
      // Fall through to the cache below.
    }
    return (await _cachedForUc(myUc), true);
  }

  /// Last successfully fetched manifest's entry for my UC.
  Future<MicroplanItem?> _cachedForUc(String myUc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw == null) return null;
      return _findIn(raw, myUc);
    } catch (_) {
      return null;
    }
  }

  // ---------- Offline file ----------

  Future<Directory> _microplansDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mp = Directory('${dir.path}/microplans');
    if (!await mp.exists()) {
      await mp.create(recursive: true);
    }
    return mp;
  }

  Future<File> _localFile(MicroplanItem item) async {
    final dir = await _microplansDir();
    final safe = normalizeUc(item.uc).toLowerCase();
    return File('${dir.path}/microplan_${safe}_${item.year}.xlsx');
  }

  Future<bool> isDownloaded(MicroplanItem item) async {
    try {
      return await (await _localFile(item)).exists();
    } catch (_) {
      return false;
    }
  }

  /// Downloads ONLY this UC's file (about 700 KB on average —
  /// never the whole 58 MB). Reports progress as (received,
  /// total). Throws on any failure — the caller shows Retry,
  /// never a fake "saved" state. Refuses .xls files flagged
  /// needsConversion: those must be converted before publishing.
  Future<File> download(
    MicroplanItem item, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (item.needsConversion) {
      throw StateError('Microplan needs xlsx conversion first');
    }
    final req = http.Request('GET', Uri.parse(item.url));
    final res = await _client.send(req).timeout(
          const Duration(minutes: 5),
        );
    if (res.statusCode != 200) {
      throw HttpException('Microplan download failed: HTTP ${res.statusCode}');
    }
    final total = res.contentLength == -1 ? null : res.contentLength;
    final file = await _localFile(item);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    return file;
  }

  /// Returns the local file to open — the saved copy if present,
  /// otherwise downloads it now (needs internet). Returns null
  /// when the file cannot be obtained.
  Future<File?> ensureLocal(MicroplanItem item) async {
    try {
      final file = await _localFile(item);
      if (await file.exists()) return file;
      return await download(item);
    } catch (_) {
      return null;
    }
  }

  /// Opens the microplan with the phone's spreadsheet viewer
  /// (downloads it first if it is not saved yet). Returns false
  /// when the file could not be obtained or no app on the phone
  /// can open it — the caller tells the vaccinator to install a
  /// spreadsheet app.
  Future<bool> open(MicroplanItem item) async {
    final file = await ensureLocal(item);
    if (file == null) return false;
    final result = await OpenFilex.open(file.path,
        type:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    return result.type == ResultType.done;
  }
}
