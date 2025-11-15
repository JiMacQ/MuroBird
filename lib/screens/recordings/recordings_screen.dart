import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/routes.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final TextEditingController _search = TextEditingController();
  final List<_Recording> _all = [];
  final Set<String> _selected = {};

  // Repro
  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _player.onPlayerComplete.listen((event) {
      setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get selectionMode => _selected.isNotEmpty;

  List<_Recording> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((r) {
      final byQuery = q.isEmpty || r.name.toLowerCase().contains(q);
      return byQuery;
    }).toList();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _loading = true;
      _selected.clear();
    });

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/recordings');
    if (!await dir.exists()) {
      setState(() {
        _all.clear();
        _loading = false;
      });
      return;
    }

    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.wav'))
        .cast<File>()
        .toList();

    final items = <_Recording>[];
    for (final f in files) {
      try {
        final stat = await f.stat();
        final sizeBytes = stat.size;
        final dur = await _wavDuration(f); // calcula usando cabecera/fómula
        items.add(
          _Recording(
            id: f.path,
            path: f.path,
            name: _niceNameFromPath(f.path),
            dateTime: stat.modified,
            duration: dur,
            sizeMb: sizeBytes / (1024 * 1024),
            ext: '.wav',
          ),
        );
      } catch (_) {
        // ignorar archivos problemáticos
      }
    }

    // Orden: más nuevos primero
    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    setState(() {
      _all
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  }

  String _niceNameFromPath(String p) {
    final base = p.split(Platform.pathSeparator).last;
    return base.replaceAll('.wav', '');
  }

  Future<Duration> _wavDuration(File f) async {
    // Cálculo rápido para WAV PCM 16kHz, 16-bit, mono (como graba tu app)
    // duration = (dataBytes) / (sr * ch * (bits/8))
    const sr = 16000;
    const ch = 1;
    const bits = 16;
    final length = await f.length();
    final dataBytes = math.max<int>(0, length - 44); // 44 bytes header RIFF
    final secs = dataBytes / (sr * ch * (bits / 8));
    return Duration(milliseconds: (secs * 1000).round());
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _deleteOne(_Recording r) async {
    try {
      final f = File(r.path);
      if (await f.exists()) await f.delete();
      setState(() => _all.removeWhere((e) => e.id == r.id));
      if (_playingPath == r.path) {
        await _player.stop();
        setState(() => _playingPath = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grabación eliminada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo eliminar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    final toDelete = _all.where((e) => _selected.contains(e.id)).toList();
    for (final r in toDelete) {
      await _deleteOne(r);
    }
    _selected.clear();
    setState(() {});
  }

  Future<void> _shareOne(_Recording r) async {
    try {
      await Share.shareXFiles([XFile(r.path)], text: r.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo compartir: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _playOrPause(_Recording r) async {
    // Si ya está reproduciendo este, pausar
    if (_playingPath == r.path) {
      await _player.stop();
      setState(() => _playingPath = null);
      return;
    }

    // Si estaba otro sonando, deténlo
    if (_playingPath != null) {
      await _player.stop();
    }

    // Reproducir este
    await _player.play(DeviceFileSource(r.path));
    setState(() => _playingPath = r.path);
  }

  void _reanalyze(_Recording r) {
    Navigator.pushNamed(context, Routes.searching, arguments: r.path);
  }

  void _showDetails(_Recording r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, color: kBrand),
                SizedBox(width: 8),
                Text(
                  'Detalles',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Nombre', r.name),
            _kv('Fecha', r.dateTime.formatNice()),
            _kv('Duración', r.duration.formatNice()),
            _kv('Tamaño', '${r.sizeMb.toStringAsFixed(2)} MB'),
            _kv('Ruta', r.path),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ===== Encabezado con botón atrás =====
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: selectionMode ? 72 : 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            automaticallyImplyLeading: false,
            leadingWidth: 56,
            leading: IconButton(
              icon: Icon(
                selectionMode ? Icons.close : Icons.arrow_back_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                if (selectionMode) {
                  _clearSelection();
                } else {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    nav.pushReplacementNamed(Routes.home);
                  }
                }
              },
              tooltip: selectionMode ? 'Cancelar selección' : 'Atrás',
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selectionMode
                      ? Icons.checklist_rounded
                      : Icons.library_music_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  selectionMode
                      ? '${_selected.length} seleccionada(s)'
                      : 'Grabaciones',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            actions: [
              if (!selectionMode)
                IconButton(
                  onPressed: _loadRecordings,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Actualizar',
                ),
              if (selectionMode)
                IconButton(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Eliminar seleccionadas',
                ),
            ],
          ),

          // ===== Buscador =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // ===== Lista / vacío / cargando =====
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (items.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: const [
                    Icon(
                      Icons.library_music_outlined,
                      size: 64,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Sin grabaciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Graba en “Tiempo real” con el auto-guardado activo o vuelve luego.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final r = items[i];
                final selected = _selected.contains(r.id);
                final isPlaying = _playingPath == r.path;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _RecordingTile(
                    recording: r,
                    selected: selected,
                    isPlaying: isPlaying,
                    onTap: () {
                      if (selectionMode) {
                        _toggleSelect(r.id);
                      } else {
                        _playOrPause(r);
                      }
                    },
                    onLongPress: () => _toggleSelect(r.id),
                    onMore: () => _showDetails(r),
                    onDelete: () => _deleteOne(r),
                    onShare: () => _shareOne(r),
                    onReanalyze: () => _reanalyze(r),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

/* ============================ Widgets ============================= */

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.recording,
    required this.selected,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
    required this.onDelete,
    required this.onShare,
    required this.onReanalyze,
  });

  final _Recording recording;
  final bool selected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onReanalyze;

  @override
  Widget build(BuildContext context) {
    final iconSize = 20.0;
    final constraints = const BoxConstraints.tightFor(width: 34, height: 34);

    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // Avatar / check de selección / play
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kBrand : const Color(0xFFEFF6F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected
                      ? Icons.check
                      : (isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                  color: selected ? Colors.white : kBrand,
                ),
              ),
              const SizedBox(width: 12),

              // Título + subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recording.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recording.dateTime.formatNice()}  •  ${recording.duration.formatNice()}  •  ${recording.sizeMb.toStringAsFixed(2)} MB',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Acciones
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      tooltip: 'Más',
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz, color: kBrand),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      tooltip: 'Compartir',
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_rounded, color: kBrand),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      tooltip: 'Volver a analizar',
                      onPressed: onReanalyze,
                      icon: const Icon(
                        Icons.manage_search_rounded,
                        color: kBrand,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: constraints,
                      iconSize: iconSize,
                      tooltip: 'Eliminar',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: kBrand),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ============================== Modelo ============================== */

class _Recording {
  final String id;
  final String path;
  final String name;
  final DateTime dateTime;
  final Duration duration;
  final double sizeMb;
  final String ext;

  _Recording({
    required this.id,
    required this.path,
    required this.name,
    required this.dateTime,
    required this.duration,
    required this.sizeMb,
    required this.ext,
  });
}

/* ============================== Utils =============================== */

extension _FmtDT on DateTime {
  String formatNice() {
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    final y = year.toString();
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}

extension _FmtDur on Duration {
  String formatNice() {
    final h = inHours;
    final m = inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

Widget _kv(String key, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            key,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            softWrap: true,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    ),
  );
}
