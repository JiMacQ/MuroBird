import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/gbif_service.dart';
import '../services/species_gallery_service.dart';

class SpeciesGalleryGrid extends StatefulWidget {
  const SpeciesGalleryGrid({
    super.key,
    required this.scientificName,
    this.initialUrls = const [],
    this.limit = 12,
    this.debug = false,
  });

  final String scientificName;
  final List<String>
  initialUrls; // puedes pasar la(s) de Wikipedia si ya tienes
  final int limit;
  final bool debug;

  @override
  State<SpeciesGalleryGrid> createState() => _SpeciesGalleryGridState();
}

class _SpeciesGalleryGridState extends State<SpeciesGalleryGrid> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<String>> _load() async {
    // buscamos taxonKey para GBIF (si falla, Commons igual nos da varias)
    int? key;
    try {
      key = await GbifService.fetchSpeciesKey(widget.scientificName);
    } catch (_) {}

    final merged = <String>{}..addAll(widget.initialUrls);
    final more = await SpeciesGalleryService.fetch(
      scientificName: widget.scientificName,
      gbifTaxonKey: key,
      limit: widget.limit,
      debug: widget.debug,
    );
    merged.addAll(more);
    return merged.take(widget.limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: kBrand),
          );
        }
        final urls = snap.data ?? const [];
        if (urls.isEmpty) {
          return const Text(
            'Sin imágenes disponibles.',
            style: TextStyle(color: Colors.black54),
          );
        }

        return GridView.builder(
          itemCount: urls.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2x2 (o más filas)
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1, // cuadrado
          ),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEFEFEF),
                alignment: Alignment.center,
                child: const Text(
                  'Imagen no disponible',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
