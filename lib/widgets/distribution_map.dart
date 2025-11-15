import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/gbif_service.dart';

final Map<String, String> _headers = {
  'User-Agent':
      'MuroBird/1.0 (https://example.com; contacto: dev@murobird.app)',
  'Accept': 'image/png',
};

class DistributionMap extends StatefulWidget {
  const DistributionMap({
    super.key,
    required this.taxonKey,
    this.center = const LatLng(-1.8312, -78.1834),
    this.zoom = 3.8,
    this.showPoints = true,
    this.pointsLimit = 200,
  });

  final String taxonKey;
  final LatLng center;
  final double zoom;
  final bool showPoints;
  final int pointsLimit;

  @override
  State<DistributionMap> createState() => _DistributionMapState();
}

class _DistributionMapState extends State<DistributionMap> {
  final MapController _map = MapController();
  List<LatLng> _points = const [];

  @override
  void initState() {
    super.initState();
    if (widget.showPoints) _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final key = int.tryParse(widget.taxonKey);
      if (key == null) return;
      final occ = await GbifService.fetchOccurrences(
        key,
        limit: widget.pointsLimit,
      );

      final pts = <LatLng>[];
      for (final m in occ) {
        final lat = (m['decimalLatitude'] as num?)?.toDouble();
        final lon = (m['decimalLongitude'] as num?)?.toDouble();
        if (lat != null && lon != null) pts.add(LatLng(lat, lon));
      }

      if (!mounted) return;
      setState(() => _points = pts);

      if (_points.isNotEmpty) {
        final lats = _points.map((e) => e.latitude).toList()..sort();
        final lons = _points.map((e) => e.longitude).toList()..sort();
        final sw = LatLng(lats.first, lons.first);
        final ne = LatLng(lats.last, lons.last);
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(sw, ne),
            padding: const EdgeInsets.all(24),
          ),
        );
      } else {
        _map.move(const LatLng(20, 0), 2.5);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final overlayUrl =
        'https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png'
        '?taxonKey=${widget.taxonKey}&style=classic.point';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.murobird',
              tileProvider: NetworkTileProvider(headers: _headers),
              maxNativeZoom: 19,
            ),
            TileLayer(
              urlTemplate: overlayUrl,
              userAgentPackageName: 'com.example.murobird',
              tileProvider: NetworkTileProvider(headers: _headers),
              maxNativeZoom: 12,
              tileBuilder: (context, w, __) => Opacity(opacity: 0.85, child: w),
            ),
            if (_points.isNotEmpty)
              MarkerLayer(
                markers: _points
                    .map(
                      (p) => Marker(
                        point: p,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('© OpenStreetMap • © GBIF')],
              alignment: AttributionAlignment.bottomLeft,
            ),
          ],
        ),
      ),
    );
  }
}
