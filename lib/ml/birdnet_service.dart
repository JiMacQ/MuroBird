// lib/ml/birdnet_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class BirdnetPrediction {
  final String label;
  final double score;
  final double startSec;
  final double endSec;
  BirdnetPrediction(this.label, this.score, this.startSec, this.endSec);
}

class BirdnetService {
  static final BirdnetService I = BirdnetService._();
  BirdnetService._();

  Interpreter? _inter;
  late List<String> _labels;
  late List<int> _inShape; // ejemplo: [1, 144000]

  bool get isLoaded => _inter != null;

  Future<void> load() async {
    if (_inter != null) return;

    // 1) Carga labels
    final labelsRaw = await rootBundle.loadString(
      'assets/models/birdnet/labels/es.txt',
    );
    _labels = labelsRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (_labels.isEmpty) {
      throw 'Labels vacíos: assets/models/birdnet/labels/es.txt';
    }

    // 2) Carga modelo (bytes) + crea intérprete con fallback
    final modelData = await rootBundle.load(
      'assets/models/birdnet/audio-model-fp16.tflite',
    );
    final modelBytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );
    print('BirdNET model bytes: ${modelBytes.length}');

    try {
      final opt = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = false; // CPU/XNNPACK primero
      _inter = await Interpreter.fromBuffer(modelBytes, options: opt);
      print('Interpreter created with CPU/XNNPACK');
    } catch (_) {
      final opt = InterpreterOptions()..useNnApiForAndroid = true;
      _inter = await Interpreter.fromBuffer(modelBytes, options: opt);
      print('Interpreter created with NNAPI');
    }

    _inShape = _inter!.getInputTensor(0).shape; // [1, 144000]
    print('BirdNET loaded. inputShape=$_inShape labels=${_labels.length}');
  }

  /* ======================= WAV helpers ======================= */

  _Wav _parseWav(Uint8List data) {
    if (data.lengthInBytes < 44) throw 'WAV muy corto';
    final bd = ByteData.sublistView(data);
    String tag(int off) => String.fromCharCodes(data.sublist(off, off + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') throw 'No es RIFF/WAVE';

    int cursor = 12;
    int? sr, ch, bits, dataOff, dataLen;
    while (cursor + 8 <= data.lengthInBytes) {
      final id = tag(cursor);
      final size = bd.getUint32(cursor + 4, Endian.little);
      final next = cursor + 8 + size;
      if (id == 'fmt ') {
        final fmt = bd.getUint16(cursor + 8, Endian.little);
        ch = bd.getUint16(cursor + 10, Endian.little);
        sr = bd.getUint32(cursor + 12, Endian.little);
        bits = bd.getUint16(cursor + 22, Endian.little);
        if (fmt != 1) throw 'WAV no PCM';
      } else if (id == 'data') {
        dataOff = cursor + 8;
        dataLen = size;
        break;
      }
      cursor = next;
    }
    if (sr == null ||
        ch == null ||
        bits == null ||
        dataOff == null ||
        dataLen == null) {
      throw 'Chunks WAV incompletos';
    }
    if (bits != 16) throw 'Solo PCM 16-bit';

    final raw = data.sublist(dataOff, math.min(dataOff + dataLen, data.length));
    final even = raw.length & ~1;
    final bdData = ByteData.sublistView(raw.sublist(0, even));

    final s16 = <double>[];
    for (int i = 0; i < even; i += 2) {
      s16.add(bdData.getInt16(i, Endian.little) / 32768.0);
    }

    if (ch! == 2) {
      // Promedio L/R -> mono
      final mono = <double>[];
      for (int i = 0; i < s16.length; i += 2) {
        final r = (i + 1 < s16.length) ? s16[i + 1] : 0.0;
        mono.add((s16[i] + r) * 0.5);
      }
      return _Wav(mono, sr!, 1);
    }
    return _Wav(s16, sr!, ch!);
  }

  List<double> _resampleLinear(List<double> x, int srFrom, int srTo) {
    if (srFrom == srTo) return x;
    final ratio = srTo / srFrom;
    final outLen = (x.length * ratio).floor();
    final y = List<double>.filled(outLen, 0);
    for (int i = 0; i < outLen; i++) {
      final pos = i / ratio;
      final p0 = pos.floor();
      final p1 = math.min(p0 + 1, x.length - 1);
      final t = pos - p0;
      y[i] = x[p0] * (1 - t) + x[p1] * t;
    }
    return y;
  }

  List<double> _segmentExactLength(List<double> x, int offset, int neededLen) {
    // Devuelve un vector de exactamente neededLen:
    // - Si falta, rellena con 0.
    // - Si sobra, recorta.
    final end = math.min(offset + neededLen, x.length);
    final out = List<double>.filled(neededLen, 0.0);
    final copyLen = math.max(0, end - offset);
    if (copyLen > 0) {
      for (int i = 0; i < copyLen; i++) {
        out[i] = x[offset + i];
      }
    }
    return out;
  }

  /* ======================= Inferencia ======================= */

  Future<List<BirdnetPrediction>> predictFromWav(
    String wavPath, {
    int segmentSeconds = 3, // debe coincidir con 144000/48000
    int hopSeconds = 1,
    double scoreThreshold = 0.35,
    int topK = 3,
  }) async {
    if (_inter == null) await load();

    final data = await File(wavPath).readAsBytes();
    final wav = _parseWav(data);

    // 1) A mono 48 kHz
    var mono = wav.samples;
    var sr = wav.sampleRate;
    if (sr != 48000) mono = _resampleLinear(mono, sr, 48000);
    sr = 48000;

    // 2) Prepara ventanas EXACTAMENTE del tamaño que pide el modelo
    //    inputShape típico: [1, 144000] -> 3.0 s * 48000
    if (_inShape.length != 2 || _inShape.first != 1) {
      throw 'Modelo inesperado: inputShape=$_inShape (se esperaba [1, N])';
    }
    final neededLen = _inShape.last;
    final hop = hopSeconds * sr;
    final seg =
        segmentSeconds * sr; // debería igualar neededLen (pero por si acaso)
    final step = hop;
    final realSeg = neededLen; // obedecemos exactamente al modelo

    final out = <BirdnetPrediction>[];

    for (int i = 0; i + 1 <= mono.length; i += step) {
      final window = _segmentExactLength(mono, i, realSeg);
      // Input esperado: [1, neededLen]
      final Float32List inVec = Float32List.fromList(
        window.map((e) => e.toDouble()).toList(),
      );
      final input = [inVec];

      // Output típico: [1, num_classes]
      final outT = _inter!.getOutputTensor(0);
      final numClasses = outT.shape.last;
      final output = List.generate(
        1,
        (_) => List<double>.filled(numClasses, 0.0),
      );

      _inter!.run(input, output);
      final probs = output[0];

      // Top por score
      final idxs = List<int>.generate(probs.length, (k) => k)
        ..sort((a, b) => probs[b].compareTo(probs[a]));

      int added = 0;
      for (final idx in idxs) {
        final p = probs[idx];
        if (p < scoreThreshold) break;
        final name = idx < _labels.length ? _labels[idx] : 'Clase $idx';
        final start = i / sr;
        final end = (i + realSeg) / sr;
        out.add(BirdnetPrediction(name, p, start, end));
        if (++added >= topK) break;
      }

      // corta si la siguiente ventana completa ya se sale mucho
      if (i + step >= mono.length && i > 0) break;
    }

    // 3) Agregación por especie (máximo score)
    final Map<String, BirdnetPrediction> best = {};
    for (final p in out) {
      final ex = best[p.label];
      if (ex == null || p.score > ex.score) best[p.label] = p;
    }
    final list = best.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return list.take(topK).toList();
  }
}

class _Wav {
  final List<double> samples;
  final int sampleRate;
  final int channels;
  _Wav(this.samples, this.sampleRate, this.channels);
}
