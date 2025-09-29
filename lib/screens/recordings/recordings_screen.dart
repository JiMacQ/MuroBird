import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final TextEditingController _search = TextEditingController();
  RecordingSource _filter = RecordingSource.all;

  // Datos de ejemplo
  final List<_Recording> _all = [
    _Recording(
      id: 'r1',
      name: '2025-05-09_Manakin',
      dateTime: DateTime(2025, 5, 9, 7, 42),
      duration: const Duration(seconds: 38),
      sizeMb: 2.1,
      ext: '.m4a',
      source: RecordingSource.realtime,
    ),
    _Recording(
      id: 'r2',
      name: 'Bosque_norte_01',
      dateTime: DateTime(2025, 5, 7, 18, 5),
      duration: const Duration(seconds: 27),
      sizeMb: 1.6,
      ext: '.mp3',
      source: RecordingSource.uploaded,
    ),
    _Recording(
      id: 'r3',
      name: 'Humedal_sur_amanecer',
      dateTime: DateTime(2025, 5, 4, 5, 55),
      duration: const Duration(seconds: 31),
      sizeMb: 1.8,
      ext: '.wav',
      source: RecordingSource.realtime,
    ),
    _Recording(
      id: 'r4',
      name: 'Parque_central_02',
      dateTime: DateTime(2025, 4, 29, 16, 20),
      duration: const Duration(seconds: 44),
      sizeMb: 2.4,
      ext: '.mp3',
      source: RecordingSource.uploaded,
    ),
    _Recording(
      id: 'r5',
      name: 'Selva_baja_03',
      dateTime: DateTime(2025, 4, 15, 10, 15),
      duration: const Duration(seconds: 36),
      sizeMb: 2.0,
      ext: '.m4a',
      source: RecordingSource.realtime,
    ),
  ];

  final Set<String> _selected = {};

  List<_Recording> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((r) {
      final byFilter = _filter == RecordingSource.all || r.source == _filter;
      final byQuery = q.isEmpty || r.name.toLowerCase().contains(q);
      return byFilter && byQuery;
    }).toList();
  }

  bool get selectionMode => _selected.isNotEmpty;

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

  void _deleteSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      _all.removeWhere((e) => _selected.contains(e.id));
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Eliminadas ${_selected.length} grabaciones'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ===== Encabezado =====
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: selectionMode ? 72 : 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            leading: selectionMode
                ? IconButton(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close, color: Colors.white),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selectionMode
                      ? Icons.checklist_rounded
                      : Icons.graphic_eq_rounded,
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
            actions: selectionMode
                ? [
                    IconButton(
                      onPressed: _deleteSelected,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                      tooltip: 'Eliminar seleccionadas',
                    ),
                  ]
                : null,
          ),

          // ===== Buscador + Filtros =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                children: [
                  // Buscador
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filtros
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FilterChip(
                        label: 'Todo',
                        selected: _filter == RecordingSource.all,
                        onSelected: () =>
                            setState(() => _filter = RecordingSource.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Tiempo real',
                        icon: Icons.wifi_tethering_rounded,
                        selected: _filter == RecordingSource.realtime,
                        onSelected: () =>
                            setState(() => _filter = RecordingSource.realtime),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Subidos',
                        icon: Icons.upload_rounded,
                        selected: _filter == RecordingSource.uploaded,
                        onSelected: () =>
                            setState(() => _filter = RecordingSource.uploaded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ===== Lista =====
          if (items.isEmpty)
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
                      'Empieza en “Tiempo real” o sube un audio desde “Subir audio”.',
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _RecordingTile(
                    recording: r,
                    selected: selected,
                    onTap: () {
                      if (selectionMode) {
                        _toggleSelect(r.id);
                      } else {
                        // Abrimos Resultado como simulación de "reproducir"
                        Navigator.pushNamed(context, Routes.result);
                      }
                    },
                    onLongPress: () => _toggleSelect(r.id),
                    onMore: () => _showDetails(r),
                    onDelete: () {
                      setState(() => _all.removeWhere((e) => e.id == r.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Grabación eliminada'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onShare: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Compartir (demo)'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
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
              children: [
                const Icon(Icons.info_outline, color: kBrand),
                const SizedBox(width: 8),
                const Text(
                  'Detalles',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Nombre', r.name),
            _kv('Fecha', r.dateTime.formatNice()),
            _kv('Duración', r.duration.formatNice()),
            _kv(
              'Origen',
              r.source == RecordingSource.realtime ? 'Tiempo real' : 'Subido',
            ),
            _kv('Tamaño', '${r.sizeMb.toStringAsFixed(1)} MB'),
            _kv('Extensión', r.ext),
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
}

/* ============================ Widgets ============================= */

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.recording,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
    required this.onDelete,
    required this.onShare,
  });

  final _Recording recording;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;
  final VoidCallback onDelete;
  final VoidCallback onShare;

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
              // Avatar / check de selección
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kBrand : const Color(0xFFEFF6F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check : Icons.graphic_eq_rounded,
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
                      '${recording.dateTime.formatNice()}  •  ${recording.duration.formatNice()}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Acciones (compactas + FittedBox para evitar overflow)
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Text(label),
        ],
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: Colors.white,
      selectedColor: kBrand,
      side: BorderSide(color: selected ? kBrand : const Color(0xFFE0E0E0)),
      shape: const StadiumBorder(),
    );
  }
}

/* ============================== Modelo ============================== */

enum RecordingSource { all, realtime, uploaded }

class _Recording {
  final String id;
  final String name;
  final DateTime dateTime;
  final Duration duration;
  final double sizeMb;
  final String ext;
  final RecordingSource source;

  _Recording({
    required this.id,
    required this.name,
    required this.dateTime,
    required this.duration,
    required this.sizeMb,
    required this.ext,
    required this.source,
  });
}

/* ============================== Utils =============================== */

extension _Fmt on DateTime {
  String formatNice() {
    // dd/MM/yyyy HH:mm
    final d = day.toString().padLeft(2, '0');
    final m = month.toString().padLeft(2, '0');
    final y = year.toString();
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
    // Si prefieres 12h, ajusta aquí.
  }
}

extension _DurFmt on Duration {
  String formatNice() {
    final mm = inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

// --- Helper para una fila "clave : valor" en el bottom sheet ---
Widget _kv(String key, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110, // ancho fijo para alinear claves
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
