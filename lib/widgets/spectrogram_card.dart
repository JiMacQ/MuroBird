import 'package:flutter/material.dart';
import '../services/xeno_canto_service.dart';
import '../core/theme.dart';

class SpectrogramCard extends StatelessWidget {
  const SpectrogramCard({super.key, required this.scientificName});

  final String scientificName;

  @override
  Widget build(BuildContext context) {
    if (scientificName.trim().isEmpty) {
      return const Text(
        'Sin nombre científico para mostrar el espectrograma.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return FutureBuilder<String?>(
      future: XenoCantoService.fetchSpectrogramUrl(scientificName),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: kBrand),
          );
        }

        final url = snap.data;
        if (url == null) {
          return const Text(
            'No se encontró un espectrograma para esta especie.',
            style: TextStyle(color: Colors.black54),
          );
        }

        return Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: const Color(0xFFEFEFEF),
                alignment: Alignment.center,
                child: const Text(
                  'No fue posible cargar el espectrograma',
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
