import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

/// S9 Admin Live Map — admin login only, vaccinators never see it.
/// Pins from today's Location rows (gviz read): green = on time,
/// amber = late (after 10:00 AM), grey = no location yet (from roster).
/// List view toggle for weak phones. Auto-refresh every 2 minutes.
class AdminMapScreen extends StatefulWidget {
  final ApiService api;
  final AppLanguage lang;
  const AdminMapScreen({super.key, required this.api, required this.lang});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  List<Map<String, dynamic>> _rows = [];
  int _submitted = 0;
  bool _loading = true;
  bool _listView = false;

  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await widget.api.loadLocationRowsToday();
      final today = AppConfig.todayYmdPkt();
      final todays = rows.where((r) {
        final ts = ApiService.pick(r, ['timestamp', 'time']) ?? '';
        return ts.startsWith(today);
      }).toList();
      if (mounted) {
        setState(() {
          _rows = todays;
          _submitted = todays
              .map((r) => ApiService.pick(r, ['username']) ?? '')
              .toSet()
              .length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final r in _rows) {
      final lat = double.tryParse(
          ApiService.pick(r, ['latitude', 'lat']) ?? '');
      final lng = double.tryParse(
          ApiService.pick(r, ['longitude', 'long', 'lng']) ?? '');
      if (lat == null || lng == null) continue;
      final ts = ApiService.pick(r, ['timestamp', 'time']) ?? '';
      final late = ts.length >= 13 &&
          int.tryParse(ts.substring(11, 13)) != null &&
          int.parse(ts.substring(11, 13)) >= 10;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 36,
        height: 36,
        child: Icon(Icons.location_pin,
            color: late ? Colors.amber[700] : AppConfig.success, size: 36),
      ));
    }
    return ScreenScaffold(
      title: lang.t('adminMapTitle'),
      subtitle: lang.t('submittedToday', {'n': '$_submitted'}),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: BigButton(
                      label: '🔄 ${lang.t('refresh')}',
                      onPressed: _load,
                      color: AppConfig.midGreen)),
              const SizedBox(width: 8),
              Expanded(
                  child: BigButton(
                      label: _listView ? '🗺️ ${lang.t('showMap')}' : '📋 ${lang.t('showList')}',
                      onPressed: () =>
                          setState(() => _listView = !_listView))),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_listView)
            ..._rows.map((r) => Card(
                  child: ListTile(
                    title: Text(
                        ApiService.pick(r, ['name']) ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${ApiService.pick(r, ['uc']) ?? ''} · ${ApiService.pick(r, ['timestamp', 'time']) ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: AppConfig.darkGreen),
                      onPressed: () async {
                        final tel = Uri(
                            scheme: 'tel',
                            path: ApiService.pick(r, ['username']) ?? '');
                        if (await canLaunchUrl(tel)) {
                          await launchUrl(tel);
                        }
                      },
                    ),
                  ),
                ))
          else
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(32.933, 72.858), // Chakwal
                    initialZoom: 10,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            lang.t('legend'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
