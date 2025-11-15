import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../ml/birdnet_service.dart';
import 'package:uuid/uuid.dart';
import '../history/history_store.dart';

/// Partes de un label del modelo (nombre común, científico e id normalizado)
class _LabelParts {
  final String common; // nombre común
  final String sci; // nombre científico
  final String speciesId; // id normalizado, ej: buteo_nitidus

  const _LabelParts({
    required this.common,
    required this.sci,
    required this.speciesId,
  });
}

class SearchingScreen extends StatefulWidget {
  const SearchingScreen({super.key});

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen> {
  String _status = 'Cargando modelo…';
  double _progress = 0.1;

  String? _audioPath;
  bool _started = false; // evita correr _run() más de una vez

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _audioPath = switch (args) {
      String s => s,
      Map m => m['audioPath'] as String?,
      _ => null,
    };

    _run();
  }

  /// Separa el label en nombre común / científico y genera un speciesId estable.
  _LabelParts _splitLabel(String label) {
    final l = label.trim();

    // 1) "Común (Latín)"
    final pm = RegExp(r'^(.*?)(?:\s*\(([^)]+)\))$').firstMatch(l);
    if (pm != null) {
      final common = (pm.group(1) ?? '').trim();
      final sci = (pm.group(2) ?? '').trim();
      final speciesId = sci
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      return _LabelParts(common: common, sci: sci, speciesId: speciesId);
    }

    // 2) Con guion bajo: "Taraba major_Batará Mayor", o al revés
    if (l.contains('_')) {
      final parts = l.split('_').map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        String a = parts.first, b = parts.sublist(1).join(' ');
        bool looksLatin(String s) =>
            RegExp(r'^[A-Z][a-zA-Z-]+\s+[a-z-]+$').hasMatch(s);
        String sci, common;
        if (looksLatin(a)) {
          sci = a;
          common = b;
        } else if (looksLatin(b)) {
          sci = b;
          common = a;
        } else {
          sci = a;
          common = b;
        }
        final speciesId = sci
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        return _LabelParts(common: common, sci: sci, speciesId: speciesId);
      }
    }

    // 3) Fallback: si no hay nada claro, usa la misma cadena como común y latín
    final sci = l;
    final speciesId = sci
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return _LabelParts(common: l, sci: sci, speciesId: speciesId);
  }

  Future<void> _run() async {
    final audioPath = _audioPath;
    try {
      setState(() => _status = 'Inicializando…');
      await BirdnetService.I.load();

      setState(() {
        _status = 'Analizando audio…';
        _progress = 0.55;
      });

      if (audioPath == null || !await File(audioPath).exists()) {
        throw 'Audio no encontrado';
      }

      final preds = await BirdnetService.I.predictFromWav(
        audioPath,
        segmentSeconds: 3,
        hopSeconds: 1,
        scoreThreshold: 0.20, // más permisivo para ver resultados
        topK: 5,
      );

      setState(() {
        _status = 'Preparando resultados…';
        _progress = 0.9;
      });

      // Determinar el origen (realtime vs uploaded) según argumentos
      HistorySource src = HistorySource.realtime;
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      if (rawArgs is Map && rawArgs['source'] == 'uploaded') {
        src = HistorySource.uploaded;
      }

      // Guardar en historial si hubo predicciones
      if (preds.isNotEmpty) {
        final top = preds.first;
        final parts = _splitLabel(top.label); // común, científico, speciesId
        final entry = HistoryEntry(
          id: const Uuid().v4(),
          speciesId: parts.speciesId, // ej: "buteo_nitidus"
          bird: parts.common, // ej: "Gavilán gris lineado"
          sci: parts.sci, // ej: "Buteo nitidus"
          confidence: top.score, // 0..1
          source: src, // realtime o uploaded
          dateTime: DateTime.now(),
          audioPath: audioPath, // para reproducir/reanalizar luego
          // thumb: si tienes portada local/asset, puedes setearla aquí
        );
        await HistoryStore.add(entry);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        Routes.result,
        arguments: {
          'audioPath': audioPath,
          'topBird': preds.isNotEmpty ? preds.first.label : 'Sin coincidencias',
          'candidates': preds
              .map(
                (p) => {
                  'name': p.label,
                  'confidence': p.score,
                  'start': p.startSec,
                  'end': p.endSec,
                },
              )
              .toList(),
        },
      );
    } catch (e, st) {
      // Logs útiles en consola
      // ignore: avoid_print
      print('Searching ERROR: $e\n$st');

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        Routes.result,
        arguments: {
          'audioPath': audioPath,
          'topBird': 'Error al analizar',
          'candidates': const [],
          'error': e.toString(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Buscando aves…',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 6,
                    value: _progress < 0.98 ? _progress : null,
                    color: kBrand,
                    backgroundColor: Colors.black12,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
