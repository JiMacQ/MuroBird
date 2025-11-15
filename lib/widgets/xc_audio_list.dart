import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../services/xeno_canto_service.dart';
import '../core/theme.dart';

class XCAudioList extends StatefulWidget {
  const XCAudioList({super.key, required this.items});
  final List<XCRecording> items;

  @override
  State<XCAudioList> createState() => _XCAudioListState();
}

class _XCAudioListState extends State<XCAudioList> {
  final _player = AudioPlayer();
  int? _playingIdx;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(int i) async {
    if (_playingIdx == i) {
      await _player.stop();
      setState(() => _playingIdx = null);
      return;
    }
    await _player.stop();
    final url = widget.items[i].fileUrl;
    await _player.play(UrlSource(url));
    setState(() => _playingIdx = i);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Text(
        'No se encontraron audios.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < widget.items.length; i++)
          Card(
            elevation: 0.5,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kBrand.withOpacity(.15),
                child: Icon(
                  _playingIdx == i
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  color: kBrand,
                ),
              ),
              title: Text(
                widget.items[i].title.isEmpty
                    ? 'Audio de referencia'
                    : widget.items[i].title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if (widget.items[i].quality != null)
                    'Calidad: ${widget.items[i].quality}',
                  if (widget.items[i].length != null)
                    'Duración: ${widget.items[i].length}',
                  if (widget.items[i].locality != null)
                    widget.items[i].locality!,
                ].join('  •  '),
              ),
              onTap: () => _toggle(i),
            ),
          ),
      ],
    );
  }
}
