// lib/screens/upload/upload_audio_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../ml/birdnet_service.dart';
import '../../widgets/blocking_loader.dart'; // 👈 NUEVO

class UploadAudioScreen extends StatefulWidget {
  const UploadAudioScreen({super.key});

  @override
  State<UploadAudioScreen> createState() => _UploadAudioScreenState();
}

class _UploadAudioScreenState extends State<UploadAudioScreen> {
  final List<PlatformFile> _picked = [];
  bool _busy = false;
  double _progress = 0;
  String? _error;

  Future<void> _pickFiles() async {
    if (_busy) return;
    setState(() => _error = null);

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: const ['wav'], // BirdNET requiere WAV PCM 16-bit
    );

    if (res == null) return;

    final files = res.files.where((f) => f.path != null).take(3).toList();
    setState(() {
      _picked
        ..clear()
        ..addAll(files);
    });
  }

  // --------- Análisis con BirdNET ---------

  Future<List<_Pred>> _analyzeOne(String path) async {
    if (!await File(path).exists()) return const [];
    final preds = await BirdnetService.I.predictFromWav(
      path,
      segmentSeconds: 3,
      hopSeconds: 1,
      scoreThreshold: 0.30,
      topK: 5,
    );
    return preds
        .map((p) => _Pred(p.label, p.score, p.startSec, p.endSec))
        .toList();
  }

  Map<String, dynamic> _mergeAndBuildArgs(List<List<_Pred>> all) {
    String norm(String s) =>
        s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

    final Map<String, _Pred> best = {};
    for (final list in all) {
      for (final p in list) {
        final k = norm(p.name);
        final prev = best[k];
        if (prev == null || p.confidence > prev.confidence) best[k] = p;
      }
    }

    final merged = best.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final topBird = merged.isNotEmpty ? merged.first.name : '';
    final candidates = merged.skip(1).map((p) {
      return {
        'name': p.name,
        'confidence': p.confidence,
        'start': p.start,
        'end': p.end,
      };
    }).toList();

    return {'topBird': topBird, 'candidates': candidates};
  }

  // 👇👇 AQUI VA EL LOADER BLOQUEANTE
  Future<void> _analyze() async {
    if (_picked.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });

    // Abre loader bloqueante (evita toques y botón atrás)
    showBlockingLoader(context, message: 'Analizando audios…');
    final started = DateTime.now();

    try {
      await BirdnetService.I.load();

      final results = <List<_Pred>>[];
      for (var i = 0; i < _picked.length; i++) {
        final p = _picked[i];
        final preds = await _analyzeOne(p.path!);
        results.add(preds);
        if (mounted) setState(() => _progress = (i + 1) / _picked.length);
      }

      final args = _mergeAndBuildArgs(results);

      // Duración mínima para que el loader no “parpadee”
      final elapsed = DateTime.now().difference(started);
      const minMs = 400;
      if (elapsed.inMilliseconds < minMs) {
        await Future.delayed(
          Duration(milliseconds: minMs - elapsed.inMilliseconds),
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // cierra loader
      Navigator.pushNamed(context, Routes.result, arguments: args);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cierra loader si hubo error
        setState(() => _error = 'Error al analizar: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAnalyze = _picked.isNotEmpty && !_busy;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Header con marca y bordes redondeados
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo_birby.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.podcasts_rounded, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'MuroBird',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            bottom: _busy
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                      minHeight: 3,
                    ),
                  )
                : null,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '¿Tienes un audio de algún ave?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¡Súbelo aquí!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Botón de selección de archivo
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Seleccionar archivo de audio (WAV)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _pickFiles,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Tabla dinámica con los archivos elegidos
                  _FilesTable(
                    rows: _picked
                        .map(
                          (f) => _FileRow('--:--', f.name),
                        ) // duración no calculada aquí
                        .toList(),
                    onDelete: (index) {
                      if (_busy) return;
                      setState(() => _picked.removeAt(index));
                    },
                  ),

                  const SizedBox(height: 28),

                  // Requisitos (nota: por ahora solo WAV para BirdNET)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Requisitos a seguir para el análisis:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '* Formato: WAV (PCM 16-bit)\n'
                      '* Tiempo (máx): 30 minutos\n'
                      '* Tiempo (mín): 30 segundos\n'
                      '* Máximo de audio por análisis: 3',
                      style: TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: canAnalyze ? _analyze : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Analizar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kBrand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 22,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =======================  WIDGETS DE LA TABLA  ======================= */

class _FilesTable extends StatelessWidget {
  const _FilesTable({required this.rows, required this.onDelete});

  final List<_FileRow> rows;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final compact = width < 380; // teléfonos angostos
        return _TableCore(rows: rows, compact: compact, onDelete: onDelete);
      },
    );
  }
}

class _TableCore extends StatelessWidget {
  const _TableCore({
    required this.rows,
    required this.compact,
    required this.onDelete,
  });

  final List<_FileRow> rows;
  final bool compact;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 12 : 14,
    );

    // SIN columna de Formato
    final timeFlex = 24;
    final nameFlex = 60;
    final actFlex = 16; // solo eliminar

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kBrand, width: 3),
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias, // evita que algo pinte fuera
      child: Column(
        children: [
          // Header verde
          Container(
            decoration: const BoxDecoration(
              color: kBrand,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            padding: EdgeInsets.symmetric(
              vertical: compact ? 10 : 14,
              horizontal: compact ? 10 : 12,
            ),
            child: Row(
              children: [
                _HeaderCell(
                  'Hora',
                  flex: timeFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Nombre del archivo',
                  flex: nameFlex,
                  style: headerStyle,
                  center: true,
                ),
                const _VSep(),
                _HeaderCell(
                  'Acción',
                  flex: actFlex,
                  style: headerStyle,
                  center: true,
                ),
              ],
            ),
          ),

          // Filas
          for (int i = 0; i < rows.length; i++) ...[
            _DataRow(
              index: i,
              row: rows[i],
              compact: compact,
              timeFlex: timeFlex,
              nameFlex: nameFlex,
              actFlex: actFlex,
              onDelete: onDelete,
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    required this.flex,
    required this.style,
    this.center = false,
  });

  final String text;
  final int flex;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style,
        ),
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: Colors.white);
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.index,
    required this.row,
    required this.compact,
    required this.timeFlex,
    required this.nameFlex,
    required this.actFlex,
    required this.onDelete,
  });

  final int index;
  final _FileRow row;
  final bool compact;
  final int timeFlex;
  final int nameFlex;
  final int actFlex;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final textStyleBold = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: compact ? 13 : 14,
    );
    final textStyle = TextStyle(fontSize: compact ? 13 : 14);

    // Botón compacto (solo eliminar)
    final iconSize = compact ? 18.0 : 20.0;
    final constraints = BoxConstraints.tightFor(
      width: compact ? 34 : 36,
      height: compact ? 34 : 36,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 8 : 10,
        horizontal: compact ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            flex: timeFlex,
            child: Text(row.time, style: textStyleBold),
          ),
          Expanded(
            flex: nameFlex,
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          Expanded(
            flex: actFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: constraints,
                iconSize: iconSize,
                onPressed: () => onDelete(index),
                icon: const Icon(Icons.delete_outline, color: kBrand),
                splashRadius: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow {
  final String time; // aquí usamos placeholder "--:--"
  final String name;
  const _FileRow(this.time, this.name);
}

/* =======================  MODELO LOCAL PARA MERGE  ======================= */

class _Pred {
  final String name;
  final double confidence;
  final double start;
  final double end;
  _Pred(this.name, this.confidence, this.start, this.end);
}
