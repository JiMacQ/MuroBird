import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen>
    with TickerProviderStateMixin {
  // ===== Grabación / archivo WAV =====
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath; // WAV final
  RandomAccessFile? _wavFile;
  int _wavDataBytes = 0;

  // Config stream PCM
  static const int _sr = 16000; // 16kHz
  static const int _bits = 16; // 16-bit PCM
  static const int _ch = 1; // mono
  Uint8List? _pcmCarry;

  // ===== Timer =====
  Timer? _timer;
  int _elapsed = 0; // segundos
  static const int _minSecondsToIdentify = 7;

  // ===== Onda en tiempo real (amplitud) =====
  StreamSubscription<Amplitude>? _ampSub;
  final int _bars = 64;
  final List<double> _levels = [];
  bool _usingFallbackWave = false;
  Timer? _fakeWaveTimer;
  double _lastDb = double.nan;

  // ===== Espectrograma (STFT por Goertzel) =====
  StreamSubscription<Uint8List>? _pcmSub;
  final List<double> _pcmBuf = []; // buffer PCM [-1..1]
  static const int _win = 512; // ventana
  static const int _hop = 128; // salto
  late final List<double> _hamming;
  static const int _specBins = 48; // bandas
  static const double _fMin = 100.0, _fMax = 8000.0;
  final int _maxColumns = 150;
  final List<List<double>> _specColumns =
      []; // cada columna son 48 valores [0..1]
  bool _specEnabled = false; // si logramos stream PCM

  // ===== Animación botón “Ave identificada” =====
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _levels.addAll(List.filled(_bars, 0));
    _hamming = List<double>.generate(
      _win,
      (n) => 0.54 - 0.46 * math.cos(2 * math.pi * n / (_win - 1)),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      lowerBound: 0.98,
      upperBound: 1.04,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _pcmSub?.cancel();
    _fakeWaveTimer?.cancel();
    _finalizeWavHeaderIfOpen(); // por si acaso
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ===== WAV helpers =====
  Future<String> _nextWavPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/recordings');
    if (!await recDir.exists()) await recDir.create(recursive: true);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '${recDir.path}/realtime_$ts.wav';
  }

  Future<void> _writeWavHeader(
    RandomAccessFile f, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
    required int dataLength,
  }) async {
    // RIFF header
    await f.writeFrom([0x52, 0x49, 0x46, 0x46]); // 'RIFF'
    await _writeInt32LE(f, 36 + dataLength); // chunk size
    await f.writeFrom([0x57, 0x41, 0x56, 0x45]); // 'WAVE'
    // fmt chunk
    await f.writeFrom([0x66, 0x6d, 0x74, 0x20]); // 'fmt '
    await _writeInt32LE(f, 16); // subchunk size
    await _writeInt16LE(f, 1); // PCM
    await _writeInt16LE(f, channels);
    await _writeInt32LE(f, sampleRate);
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    await _writeInt32LE(f, byteRate);
    final blockAlign = channels * bitsPerSample ~/ 8;
    await _writeInt16LE(f, blockAlign);
    await _writeInt16LE(f, bitsPerSample);
    // data chunk
    await f.writeFrom([0x64, 0x61, 0x74, 0x61]); // 'data'
    await _writeInt32LE(f, dataLength);
  }

  Future<void> _finalizeWavHeaderIfOpen() async {
    if (_wavFile == null) return;
    try {
      await _wavFile!.setPosition(4);
      await _writeInt32LE(_wavFile!, 36 + _wavDataBytes);
      await _wavFile!.setPosition(40);
      await _writeInt32LE(_wavFile!, _wavDataBytes);
      await _wavFile!.close();
    } catch (_) {}
    _wavFile = null;
  }

  Future<void> _writeInt16LE(RandomAccessFile f, int v) async {
    await f.writeFrom([v & 0xFF, (v >> 8) & 0xFF]);
  }

  Future<void> _writeInt32LE(RandomAccessFile f, int v) async {
    await f.writeFrom([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
  }

  // ===== Fallback onda (si amplitud falla) =====
  void _startFallbackWave() {
    _usingFallbackWave = true;
    _fakeWaveTimer?.cancel();
    final rng = math.Random();
    _fakeWaveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final v = (0.25 + rng.nextDouble() * 0.5); // 0.25..0.75
      setState(() {
        _levels.removeAt(0);
        _levels.add(v);
        _lastDb = double.nan;
      });
    });
  }

  void _stopFallbackWave() {
    _usingFallbackWave = false;
    _fakeWaveTimer?.cancel();
  }

  // ===== STFT / espectrograma =====
  void _onPcm(Uint8List chunk) {
    // 1) Prepend del byte sobrante previo (si lo hubo)
    Uint8List data;
    if (_pcmCarry != null && _pcmCarry!.isNotEmpty) {
      data = Uint8List(_pcmCarry!.length + chunk.length)
        ..setRange(0, _pcmCarry!.length, _pcmCarry!)
        ..setRange(_pcmCarry!.length, _pcmCarry!.length + chunk.length, chunk);
      _pcmCarry = null;
    } else {
      data = chunk;
    }

    // 2) Si la longitud es impar, guarda el último byte para el siguiente paquete
    if ((data.lengthInBytes & 1) == 1) {
      _pcmCarry = data.sublist(data.lengthInBytes - 1);
      data = data.sublist(0, data.lengthInBytes - 1);
    }

    // 3) Lee int16 little-endian de forma segura
    final bd = ByteData.sublistView(data); // offset 0 => seguro
    for (int i = 0; i < data.lengthInBytes; i += 2) {
      final s16 = bd.getInt16(i, Endian.little); // [-32768..32767]
      _pcmBuf.add(s16 / 32768.0); // [-1..1]
    }

    _processSpectrogram(); // genera columnas y repinta
  }

  void _processSpectrogram() {
    while (_pcmBuf.length >= _win) {
      final frame = _pcmBuf.sublist(0, _win);
      // overlap
      _pcmBuf.removeRange(0, _hop);

      // window
      for (int i = 0; i < _win; i++) {
        frame[i] = frame[i] * _hamming[i];
      }

      // Goertzel en bandas log entre fMin..fMax
      final column = List<double>.filled(_specBins, 0.0);
      for (int b = 0; b < _specBins; b++) {
        final f = _fMin * math.pow(_fMax / _fMin, b / (_specBins - 1));
        int k = (f * _win / _sr).round();
        if (k < 1) k = 1;
        if (k > (_win ~/ 2) - 1) k = (_win ~/ 2) - 1;

        final coeff = 2 * math.cos(2 * math.pi * k / _win);
        double s0 = 0, s1 = 0, s2 = 0;
        for (int n = 0; n < _win; n++) {
          s0 = frame[n] + coeff * s1 - s2;
          s2 = s1;
          s1 = s0;
        }
        final power = s1 * s1 + s2 * s2 - coeff * s1 * s2;
        // dB y normalización a [0..1]
        final db = 10 * math.log(power + 1e-12) / math.ln10; // ~[-120..0]
        const minDb = -80.0, maxDb = -20.0;
        final norm = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
        column[b] = norm;
      }

      _specColumns.add(column);
      if (_specColumns.length > _maxColumns) {
        _specColumns.removeAt(0);
      }
    }
    setState(() {}); // repinta espectrograma
  }

  // ===== START / STOP =====
  Future<void> _startRecording() async {
    // Permiso mic
    if (!await _recorder.hasPermission()) {
      final req = await Permission.microphone.request();
      if (!req.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de micrófono.')),
        );
        return;
      }
    }

    // Prepara archivo WAV y header
    final path = await _nextWavPath();
    final raf = await File(path).open(mode: FileMode.write);
    await _writeWavHeader(
      raf,
      sampleRate: _sr,
      channels: _ch,
      bitsPerSample: _bits,
      dataLength: 0,
    );
    _wavFile = raf;
    _currentPath = path;
    _wavDataBytes = 0;

    // Inicia stream PCM 16-bit para espectrograma y para guardar WAV
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sr,
          numChannels: _ch,
        ),
      );

      _specEnabled = true;
      _pcmSub?.cancel();
      _pcmSub = stream.listen((bytes) async {
        // Guarda en WAV
        await _wavFile?.writeFrom(bytes);
        _wavDataBytes += bytes.length;
        // Procesa espectrograma
        _onPcm(bytes);
      });
    } catch (e) {
      // Si la plataforma no soporta stream, desactiva espectrograma y muestra placeholder
      _specEnabled = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espectrograma no soportado en este dispositivo'),
          ),
        );
      }
    }

    // Timer
    _timer?.cancel();
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
    });

    // Amplitud → onda
    _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
          final db = amp.current.toDouble();
          _lastDb = db;
          final norm = ((db + 60) / 60).clamp(0.0, 1.0);
          setState(() {
            _levels.removeAt(0);
            _levels.add(norm);
          });
        }, onError: (_) => _startFallbackWave());

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndSearch() async {
    await _recorder.stop(); // corta stream PCM y amplitud
    _timer?.cancel();
    _ampSub?.cancel();
    await _pcmSub?.cancel();
    _fakeWaveTimer?.cancel();

    // Finaliza header WAV (rellena tamaños)
    await _finalizeWavHeaderIfOpen();

    setState(() => _isRecording = false);

    if (!mounted) return;
    Navigator.pushNamed(context, Routes.searching, arguments: _currentPath);
  }

  // ===== UI =====
  String _fmtHMS(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final canIdentify = _isRecording && _elapsed >= _minSecondsToIdentify;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              children: [
                // ===== ESPECTROGRAMA =====
                const _SectionHeader('ESPECTROGRAMA'),
                const SizedBox(height: 12),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black54, width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isRecording && _specEnabled
                      ? CustomPaint(
                          painter: _SpectrogramPainter(
                            columns: List<List<double>>.from(_specColumns),
                          ),
                        )
                      : Image.asset(
                          'assets/mock/spectrogram_demo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'imagen espectrograma',
                              style: TextStyle(color: Colors.black45),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 28),

                // ===== ONDA =====
                const _SectionHeader('ONDA DE SONIDO'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: _isRecording
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CustomPaint(
                            painter: _WaveformBars(
                              levels: List<double>.from(_levels),
                            ),
                          ),
                        )
                      : Center(
                          child: Image.asset(
                            'assets/mock/wave_demo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.graphic_eq,
                              size: 56,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 18),

                // ===== BOTÓN "AVE IDENTIFICADA" =====
                Center(
                  child: SizedBox(
                    height: 44,
                    child: ScaleTransition(
                      scale: canIdentify
                          ? _pulseCtrl
                          : const AlwaysStoppedAnimation(1.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canIdentify
                              ? kBrand
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          shape: const StadiumBorder(),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: canIdentify ? _stopRecordingAndSearch : null,
                        child: Text(
                          canIdentify
                              ? 'ave identificada'
                              : 'Estamos buscando aves…',
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ===== TIEMPO + texto =====
                Center(
                  child: Text(
                    _isRecording ? _fmtHMS(_elapsed) : '00:00:00',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _isRecording
                        ? 'Grabando… toca el micrófono\npara detener y buscar'
                        : 'Pulsa para empezar a captar el\nsonido del pájaro',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 16,
                      height: 1.25,
                    ),
                  ),
                ),

                const SizedBox(height: 6),
                if (_isRecording)
                  Center(
                    child: Text(
                      _usingFallbackWave
                          ? 'amplitud: simulada'
                          : 'amplitud: ${_lastDb.isNaN ? '...' : _lastDb.toStringAsFixed(1)} dB',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                // ===== MIC REDONDO =====
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      if (_isRecording) {
                        await _stopRecordingAndSearch();
                      } else {
                        await _startRecording();
                      }
                    },
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xFFE65C5C) : kBrand,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ===== X cerrar =====
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFBDBDBD),
                  shape: const CircleBorder(),
                  fixedSize: const Size(40, 40),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================== Painters ================== */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Colors.black54,
        letterSpacing: 1.0,
      ),
    );
  }
}

/// Barras (onda)
class _WaveformBars extends CustomPainter {
  final List<double> levels;
  _WaveformBars({required this.levels});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withOpacity(.04);
    canvas.drawRect(Offset.zero & size, bg);

    final paint = Paint()
      ..color = Colors.black.withOpacity(.78)
      ..style = PaintingStyle.fill;

    final n = levels.length;
    final barW = size.width / (n * 1.4);
    final gap = barW * 0.4;
    final midY = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x = i * (barW + gap);
      final lv = levels[i];
      final h = (math.pow(lv, 0.6) as double) * (size.height * 0.9);
      final rect = RRect.fromLTRBR(
        x,
        midY - h / 2,
        x + barW,
        midY + h / 2,
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
      if (x + barW + gap > size.width) break;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformBars oldDelegate) => true;
}

/// Espectrograma (columnas * bins)
class _SpectrogramPainter extends CustomPainter {
  final List<List<double>> columns; // cada valor 0..1 (oscuro↔claro)

  _SpectrogramPainter({required this.columns});

  @override
  void paint(Canvas canvas, Size size) {
    // fondo
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bg);

    if (columns.isEmpty) return;
    final bins = columns.first.length;
    final colW = size.width / math.max(columns.length, 1);
    final rowH = size.height / bins;

    // dibuja de izquierda a derecha (lo más nuevo a la derecha)
    for (int c = 0; c < columns.length; c++) {
      final col = columns[c];
      for (int r = 0; r < bins; r++) {
        final v = col[r].clamp(0.0, 1.0);
        final g = (v * 255).clamp(0, 255).toInt(); // escala gris
        final paint = Paint()..color = Color.fromARGB(255, g, g, g);
        final rect = Rect.fromLTWH(
          c * colW,
          size.height - (r + 1) * rowH,
          colW + 0.5,
          rowH + 0.5,
        );
        canvas.drawRect(rect, paint);
      }
    }

    // borde fino
    final border = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) => true;
}
