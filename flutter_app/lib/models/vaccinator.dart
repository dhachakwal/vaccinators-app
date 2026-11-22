/// One row of the `All Vaccinators Profile` tab.
/// Username is the mobile number or the OR code, exactly as in the sheet.
/// PIN: column O ("PIN") of the profile tab, set 22 Nov 2026 — the
/// last 4 digits of the vaccinator's username (Zain Islam: 1234,
/// no username on file). Login checks the entered PIN against it.
class Vaccinator {
  final String tehsil;
  final String uc;
  final String name;
  final String username;
  final String pin;
  final double openingRemaining;
  final double availed;

  const Vaccinator({
    required this.tehsil,
    required this.uc,
    required this.name,
    required this.username,
    this.pin = '',
    this.openingRemaining = 24,
    this.availed = 0,
  });

  factory Vaccinator.fromGvizRow(Map<String, dynamic> row) {
    String s(String k) => (row[k] ?? '').toString().trim();
    double num(String k) =>
        double.tryParse(s(k).replaceAll(',', '')) ?? double.nan;
    final remaining = num('remaining');
    final av = num('availed');
    // PIN cells are text (leading zeros matter: 0786, not 786).
    // If a cell lost its zero and came back numeric, restore it.
    final pinRaw = s('pin');
    final pin = pinRaw.isEmpty ? '' : pinRaw.padLeft(4, '0');
    return Vaccinator(
      tehsil: s('tehsil'),
      uc: s('uc'),
      name: s('name'),
      username: ApiHelpers.normUser(s('username')),
      pin: pin,
      openingRemaining:
          remaining.isNaN ? 24 : remaining,
      availed: av.isNaN ? 0 : av,
    );
  }

  Map<String, dynamic> toJson() => {
        'tehsil': tehsil,
        'uc': uc,
        'name': name,
        'username': username,
        'pin': pin,
        'openingRemaining': openingRemaining,
        'availed': availed,
      };

  factory Vaccinator.fromJson(Map<String, dynamic> j) => Vaccinator(
        tehsil: (j['tehsil'] ?? '').toString(),
        uc: (j['uc'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        pin: (j['pin'] ?? '').toString(),
        openingRemaining:
            (j['openingRemaining'] as num?)?.toDouble() ?? 24,
        availed: (j['availed'] as num?)?.toDouble() ?? 0,
      );
}

/// Normalisation copied from the web form: trailing ".0" dropped,
/// a 10+-digit mobile without a leading 0 gets one added.
class ApiHelpers {
  ApiHelpers._();

  static String normUser(String u) {
    var s = u.trim();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    if (RegExp(r'^\d+$').hasMatch(s) &&
        s.length >= 10 &&
        !s.startsWith('0')) {
      s = '0$s';
    }
    return s;
  }

  static String normUserKey(String u) {
    var s = u.trim().toLowerCase();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    if (RegExp(r'^\d+$').hasMatch(s)) {
      s = s.replaceFirst(RegExp(r'^0+'), '');
      if (s.isEmpty) s = '0';
    }
    return s;
  }

  /// Today's date in PKT (UTC+5), yyyy-MM-dd.
  static String todayYmdPkt() {
    final pkt = DateTime.now().toUtc().add(const Duration(hours: 5));
    final m = pkt.month.toString().padLeft(2, '0');
    final d = pkt.day.toString().padLeft(2, '0');
    return '${pkt.year}-$m-$d';
  }
}
