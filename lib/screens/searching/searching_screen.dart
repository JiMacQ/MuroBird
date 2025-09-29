import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../ml/birdnet_service.dart';

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
