// lib/widgets/distribution_map_offline.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DistributionMapOffline extends StatefulWidget {
  const DistributionMapOffline({super.key, required this.geoJsonPath});
  final String geoJsonPath; // archivo local de la especie (range.geo.json)

  @override
  State<DistributionMapOffline> createState() => _DistributionMapOfflineState();
}

class _DistributionMapOfflineState extends State<DistributionMapOffline> {
  @override
  void didUpdateWidget(covariant DistributionMapOffline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geoJsonPath != widget.geoJsonPath) {
      // Limpia capas y reinicia cámara
      _polylines.clear();
      _polygons.clear();
      _markers.clear();
      _speciesBounds = null;
      _center = const LatLng(0, 0);
      _zoom = 1.8;

      // Recarga el GeoJSON de la nueva especie
      _loadSpeciesGeoJson().then((_) {
        if (!mounted) return;
        setState(() {});
        // Ajusta cámara al nuevo contenido
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
      });
    }
  }

  // --- Controlador de mapa (para centrar/zoom automático)
  final _mapCtrl = MapController();

  // --- Capa base mundial (polígonos muy livianos)
  final _worldPolygons = <Polygon>[];

  // --- Capas de la especie
  final _polylines = <Polyline>[];
  final _polygons = <Polygon>[];
  final _markers = <Marker>[];

  // Vista inicial de respaldo
  LatLng _center = const LatLng(0, 0);
  double _zoom = 1.8;

  // Bounds de la especie para hacer fit
  LatLngBounds? _speciesBounds;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadWorldBasemap(); // 1) fondo mundial
    await _loadSpeciesGeoJson(); // 2) capa de especie

    if (!mounted) return;
    setState(() {});

    // Ajusta la cámara al terminar de pintar el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
  }

  // ========================= (1) MUNDO OFFLINE =========================
  // Carga el mundo (asset): assets/maps/world_countries_110m.geojson
  Future<void> _loadWorldBasemap() async {
    try {
      final s = await rootBundle.loadString(
        'assets/maps/world_countries_110m.geojson',
      );
      final gj = jsonDecode(s);

      void addCountry(List rings) {
        final exterior = <LatLng>[];
        for (final c in (rings.first as List)) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          exterior.add(LatLng(lat, lon));
        }
        if (exterior.length >= 3) {
          _worldPolygons.add(
            Polygon(
              points: exterior,
              color: const Color(0xFFE3F2FD), // relleno muy claro
              borderColor: const Color(0xFF90CAF9), // borde celeste
              borderStrokeWidth: 0.8,
              isFilled: true,
            ),
          );
        }
      }

      void parseGeom(Map g) {
        final type = g['type'];
        final coordinates = g['coordinates'];
        if (type == 'Polygon') {
          addCountry(coordinates as List);
        } else if (type == 'MultiPolygon') {
          for (final poly in (coordinates as List)) {
            addCountry(poly as List);
          }
        }
      }

      if (gj['type'] == 'FeatureCollection') {
        for (final f in (gj['features'] as List? ?? const [])) {
          final g = f['geometry'];
          if (g is Map) parseGeom(g);
        }
      } else if (gj['type'] == 'Feature') {
        final g = gj['geometry'];
        if (g is Map) parseGeom(g);
      } else if (gj['type'] is String) {
        parseGeom(gj as Map);
      }
    } catch (_) {
      // Si falla, simplemente no dibujamos el mundo; quedará fondo sólido.
    }
  }

  // ====================== (2) CAPA DE LA ESPECIE =======================
  Future<void> _loadSpeciesGeoJson() async {
    try {
      final txt = await File(widget.geoJsonPath).readAsString();
      final gj = jsonDecode(txt);

      final acc = _BoundsAcc(); // acumulador de bounds

      void addPoint(List c) {
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        final p = LatLng(lat, lon);
        _markers.add(
          Marker(
            point: p,
            width: 6,
            height: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
        acc.extend(p);
      }

      void addLine(List coords) {
        final pts = <LatLng>[];
        for (final c in coords) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          final p = LatLng(lat, lon);
          pts.add(p);
          acc.extend(p);
        }
        if (pts.length >= 2) {
          _polylines.add(
            Polyline(points: pts, strokeWidth: 2.0, color: Colors.redAccent),
          );
        }
      }

      void addPolygon(List rings) {
        final exterior = <LatLng>[];
        for (final c in (rings.first as List)) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          final p = LatLng(lat, lon);
          exterior.add(p);
          acc.extend(p);
        }
        if (exterior.length >= 3) {
          _polygons.add(
            Polygon(
              points: exterior,
              borderColor: Colors.red.shade700,
              borderStrokeWidth: 1.5,
              color: Colors.red.withOpacity(.18),
              isFilled: true,
            ),
          );
        }
      }

      void parseGeom(Map g) {
        final type = g['type'];
        final coordinates = g['coordinates'];
        if (type == 'Point') {
          addPoint(coordinates as List);
        } else if (type == 'MultiPoint') {
          for (final pt in (coordinates as List)) addPoint(pt as List);
        } else if (type == 'LineString') {
          addLine(coordinates as List);
        } else if (type == 'MultiLineString') {
          for (final ln in (coordinates as List)) addLine(ln as List);
        } else if (type == 'Polygon') {
          addPolygon(coordinates as List);
        } else if (type == 'MultiPolygon') {
          for (final poly in (coordinates as List)) {
            addPolygon(poly as List);
          }
        }
      }

      if (gj['type'] == 'FeatureCollection') {
        for (final f in (gj['features'] as List? ?? const [])) {
          final g = f['geometry'];
          if (g is Map) parseGeom(g);
        }
      } else if (gj['type'] == 'Feature') {
        final g = gj['geometry'];
        if (g is Map) parseGeom(g);
      } else if (gj['type'] is String) {
        parseGeom(gj as Map);
      }

      // Determina centro/zoom inicial y guarda bounds para el fit
      _speciesBounds = acc.toLatLngBounds();
      if (_speciesBounds != null) {
        final c = _speciesBounds!.center;
        _center = LatLng(c.latitude, c.longitude);
        _zoom = 3.8;
      } else {
        _center = const LatLng(0, 0);
        _zoom = 1.8;
      }
    } catch (_) {
      _center = const LatLng(0, 0);
      _zoom = 1.8;
      _speciesBounds = null;
    }
  }

  // Mueve la cámara para encuadrar los datos
  void _fitToBounds() {
    if (_speciesBounds == null) return;
    final fit = CameraFit.bounds(
      bounds: _speciesBounds!,
      padding: const EdgeInsets.all(18),
    );
    final conf = fit.fit(_mapCtrl.camera);
    _mapCtrl.move(conf.center, conf.zoom);
  }

  // ============================== UI ==============================
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: FlutterMap(
        mapController: _mapCtrl, // <- importante
        options: MapOptions(
          initialCenter: _center,
          initialZoom: _zoom,
          backgroundColor: const Color(0xFFE6F4EA), // verde muy claro
          maxZoom: 10,
          minZoom: 1.2,
        ),
        children: [
          // Capa base mundial (offline)
          if (_worldPolygons.isNotEmpty) PolygonLayer(polygons: _worldPolygons),

          // Capas de la especie
          PolygonLayer(polygons: _polygons),
          PolylineLayer(polylines: _polylines),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
}

// ==== Helper interno para acumular bounds y convertir a LatLngBounds ====
class _BoundsAcc {
  double? north, south, east, west;

  void extend(LatLng p) {
    north = (north == null)
        ? p.latitude
        : (p.latitude > north! ? p.latitude : north);
    south = (south == null)
        ? p.latitude
        : (p.latitude < south! ? p.latitude : south);
    east = (east == null)
        ? p.longitude
        : (p.longitude > east! ? p.longitude : east);
    west = (west == null)
        ? p.longitude
        : (p.longitude < west! ? p.longitude : west);
  }

  bool get isValid =>
      north != null && south != null && east != null && west != null;

  LatLngBounds? toLatLngBounds() {
    if (!isValid) return null;
    return LatLngBounds(
      LatLng(south!, west!), // SW
      LatLng(north!, east!), // NE
    );
  }
}
