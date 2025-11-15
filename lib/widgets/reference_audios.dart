import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/theme.dart';
import '../services/xeno_canto_service.dart';

class ReferenceAudios extends StatefulWidget {
  const ReferenceAudios({
    super.key,
    required this.scientificName,
    this.limit = 6,
  });

  final String scientificName;
  final int limit;

  @override
  State<ReferenceAudios> createState() => _ReferenceAudiosState();
}

class _ReferenceAudiosState extends State<ReferenceAudios> {
  late final AudioPlayer _player;
  String? _currentUrl;
  bool _isLoading = false;

  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  late Future<List<XCRecording>> _future;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _pos = Duration.zero;
        _isLoading = false;
        // deja _currentUrl tal cual para poder re-reproducir
      });
    });

    _future = XenoCantoService.fetchBySpecies(
      widget.scientificName,
      limit: widget.limit,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  bool get _isPlaying => _player.state == PlayerState.playing;

  Future<void> _toggle(String url) async {
    try {
      setState(() => _isLoading = true);

      // Si se elige otro audio, cambia de fuente
      if (_currentUrl != url) {
        await _player.stop();
        _currentUrl = url;
        await _player.setSourceUrl(url);
        await _player.resume();
      } else {
        // Si es el mismo, toggle play/pause
        if (_isPlaying) {
          await _player.pause();
        } else {
          // Si estaba al final, vuelve al inicio
          if (_dur > Duration.zero && _pos >= _dur) {
            await _player.seek(Duration.zero);
          }
          await _player.resume();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _metaLine(XCRecording r) {
    final bits = <String>[];
    if (r.quality != null && r.quality!.isNotEmpty)
      bits.add('Calidad: ${r.quality!}');
    if (r.length != null && r.length!.isNotEmpty)
      bits.add('Duración: ${r.length!}');
    if (r.locality != null && r.locality!.isNotEmpty) bits.add(r.locality!);
    return bits.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<XCRecording>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: LinearProgressIndicator(color: kBrand),
          );
        }
        final items = snap.data ?? const <XCRecording>[];
        if (items.isEmpty) {
          return const Text(
            'No hay audios de referencia disponibles.',
            style: TextStyle(color: Colors.black54),
          );
        }

        return Column(
          children: [
            for (final r in items)
              _AudioTile(
                recording: r,
                isCurrent: r.fileUrl == _currentUrl,
                isPlaying: _isPlaying && r.fileUrl == _currentUrl,
                isLoading: _isLoading && r.fileUrl == _currentUrl,
                meta: _metaLine(r),
                progress: (r.fileUrl == _currentUrl && _dur.inMilliseconds > 0)
                    ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(
                        0.0,
                        1.0,
                      )
                    : 0.0,
                onTap: () => _toggle(r.fileUrl),
              ),
          ],
        );
      },
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.recording,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLoading,
    required this.meta,
    required this.progress,
    required this.onTap,
  });

  final XCRecording recording;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLoading;
  final String meta;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent ? const Color(0xFFE7F3F0) : const Color(0xFFF5F7F7);
    final icon = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: kBrand),
          )
        : Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white);

    return Card(
      elevation: 0.5,
      color: bg,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: kBrand, child: icon),
            title: Text(
              recording.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: isCurrent ? progress : 0.0,
                  minHeight: 3,
                  color: kBrand,
                  backgroundColor: Colors.black12,
                ),
                const SizedBox(height: 6),
                Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
