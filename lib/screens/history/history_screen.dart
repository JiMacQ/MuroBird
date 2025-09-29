import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();

  HistoryRange _range = HistoryRange.all;
  HistorySource _source = HistorySource.all;
  final Set<String> _selected = {};

  // -------- Datos de ejemplo (reemplaza por los tuyos cuando haya backend) -----
  final List<_HistoryItem> _items = [
    _HistoryItem(
      id: 'h1',
      bird: 'Colimbo grande',
      sci: 'Gavia immer',
      dateTime: DateTime.now().subtract(const Duration(minutes: 18)),
      confidence: 0.86,
      source: HistorySource.realtime,
      thumb: 'assets/mock/gallery1.jpg',
    ),
    _HistoryItem(
      id: 'h2',
      bird: 'Petirrojo europeo',
      sci: 'Erithacus rubecula',
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      confidence: 0.79,
      source: HistorySource.uploaded,
      thumb: 'assets/mock/gallery2.jpg',
    ),
    _HistoryItem(
      id: 'h3',
      bird: 'Reinita anaranjada',
      sci: 'Icterus galbula',
      dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      confidence: 0.91,
      source: HistorySource.realtime,
      thumb: 'assets/mock/gallery3.jpg',
    ),
    _HistoryItem(
      id: 'h4',
      bird: 'Tangara azulada',
      sci: 'Thraupis episcopus',
      dateTime: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      confidence: 0.73,
      source: HistorySource.uploaded,
      thumb: 'assets/mock/gallery4.jpg',
    ),
    _HistoryItem(
      id: 'h5',
      bird: 'Zorzal pálido',
      sci: 'Turdus leucomelas',
      dateTime: DateTime.now().subtract(const Duration(days: 8)),
      confidence: 0.68,
      source: HistorySource.realtime,
      thumb: 'assets/mock/gallery1.jpg',
    ),
    _HistoryItem(
      id: 'h6',
      bird: 'Cacique candela',
      sci: 'Hypopyrrhus pyrohypogaster',
      dateTime: DateTime.now().subtract(const Duration(days: 21)),
      confidence: 0.64,
      source: HistorySource.uploaded,
      thumb: 'assets/mock/gallery2.jpg',
    ),
  ];
  // ---------------------------------------------------------------------------

  bool get selectionMode => _selected.isNotEmpty;

  List<_HistoryItem> get _filtered {
    final q = _search.text.trim().toLowerCase();

    // por rango de tiempo
    DateTime? minDate;
    final now = DateTime.now();
    switch (_range) {
      case HistoryRange.today:
        minDate = DateTime(now.year, now.month, now.day);
        break;
      case HistoryRange.week:
        minDate = now.subtract(const Duration(days: 7));
        break;
      case HistoryRange.month:
        minDate = now.subtract(const Duration(days: 30));
        break;
      case HistoryRange.all:
        minDate = null;
        break;
    }

    return _items.where((e) {
      final okQuery =
          q.isEmpty ||
          e.bird.toLowerCase().contains(q) ||
          e.sci.toLowerCase().contains(q);
      final okRange = minDate == null || e.dateTime.isAfter(minDate);
      final okSource = _source == HistorySource.all || _source == e.source;
      return okQuery && okRange && okSource;
    }).toList()..sort(
      (a, b) => b.dateTime.compareTo(a.dateTime),
    ); // más recientes arriba
  }

  Map<DateTime, List<_HistoryItem>> _groupByDay(List<_HistoryItem> list) {
    final Map<DateTime, List<_HistoryItem>> map = {};
    for (final item in list) {
      final d = DateTime(
        item.dateTime.year,
        item.dateTime.month,
        item.dateTime.day,
      );
      map.putIfAbsent(d, () => []).add(item);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
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
  void _deleteSelected() {
    if (_selected.isEmpty) return;
    setState(() {
      _items.removeWhere((e) => _selected.contains(e.id));
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entradas eliminadas'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearAll() {
    setState(_items.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Historial vacío'),
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
    final filtered = _filtered;
    final grouped = _groupByDay(filtered);

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
                      : Icons.history_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  selectionMode
                      ? '${_selected.length} seleccionada(s)'
                      : 'Historial',
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
                      tooltip: 'Eliminar seleccionadas',
                      onPressed: _deleteSelected,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                  ]
                : [
                    IconButton(
                      tooltip: 'Vaciar historial',
                      onPressed: _items.isEmpty ? null : _clearAll,
                      icon: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
          ),

          // ===== Búsqueda + filtros =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar por ave o nombre científico',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _Chip(
                        label: 'Todo',
                        selected: _range == HistoryRange.all,
                        onTap: () => setState(() => _range = HistoryRange.all),
                      ),
                      _Chip(
                        label: 'Hoy',
                        selected: _range == HistoryRange.today,
                        onTap: () =>
                            setState(() => _range = HistoryRange.today),
                      ),
                      _Chip(
                        label: '7 días',
                        selected: _range == HistoryRange.week,
                        onTap: () => setState(() => _range = HistoryRange.week),
                      ),
                      _Chip(
                        label: '30 días',
                        selected: _range == HistoryRange.month,
                        onTap: () =>
                            setState(() => _range = HistoryRange.month),
                      ),
                      const SizedBox(width: 12),
                      _Chip(
                        label: 'Todos',
                        icon: Icons.all_inclusive,
                        selected: _source == HistorySource.all,
                        onTap: () =>
                            setState(() => _source = HistorySource.all),
                      ),
                      _Chip(
                        label: 'Tiempo real',
                        icon: Icons.wifi_tethering_rounded,
                        selected: _source == HistorySource.realtime,
                        onTap: () =>
                            setState(() => _source = HistorySource.realtime),
                      ),
                      _Chip(
                        label: 'Subidos',
                        icon: Icons.upload_rounded,
                        selected: _source == HistorySource.uploaded,
                        onTap: () =>
                            setState(() => _source = HistorySource.uploaded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ===== Lista agrupada =====
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: Column(
                  children: const [
                    Icon(
                      Icons.history_toggle_off,
                      size: 64,
                      color: Colors.black26,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Sin resultados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Aún no hay coincidencias para el filtro actual.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                // renderizamos secciones día por día
                final day = grouped.keys.elementAt(index);
                final dayItems = grouped[day]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(date: day),
                      for (final it in dayItems)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: _HistoryTile(
                            item: it,
                            selected: _selected.contains(it.id),
                            onTap: () {
                              if (selectionMode) {
                                _toggleSelect(it.id);
                              } else {
                                Navigator.pushNamed(context, Routes.result);
                              }
                            },
                            onLongPress: () => _toggleSelect(it.id),
                            onDelete: () {
                              setState(
                                () => _items.removeWhere((e) => e.id == it.id),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Entrada eliminada'),
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
                            onMore: () => _showDetails(it),
                          ),
                        ),
                    ],
                  ),
                );
              }, childCount: grouped.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  void _showDetails(_HistoryItem r) {
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
            _kv('Ave', r.bird),
            _kv('Nombre científico', r.sci),
            _kv('Fecha', r.dateTime.formatNice()),
            _kv('Confianza', '${(r.confidence * 100).toStringAsFixed(0)} %'),
            _kv(
              'Origen',
              r.source == HistorySource.realtime ? 'Tiempo real' : 'Subido',
            ),
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

/* ============================== Widgets ============================== */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = _dayLabel(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.black12)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.black12)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onDelete,
    required this.onMore,
  });

  final _HistoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onMore;

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // Avatar o check de selección
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? kBrand : null,
                  image: selected
                      ? null
                      : DecorationImage(
                          image: AssetImage(item.thumb),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),

              // Título + subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.bird,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.sci}  •  ${(item.confidence * 100).toStringAsFixed(0)} %  •  ${item.dateTime.formatHour()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Acciones compactas
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

/* =============================== Modelo ============================== */

enum HistoryRange { all, today, week, month }

enum HistorySource { all, realtime, uploaded }

class _HistoryItem {
  final String id;
  final String bird;
  final String sci;
  final DateTime dateTime;
  final double confidence; // 0..1
  final HistorySource source;
  final String thumb;

  _HistoryItem({
    required this.id,
    required this.bird,
    required this.sci,
    required this.dateTime,
    required this.confidence,
    required this.source,
    required this.thumb,
  });
}

/* ============================== Utilidades =========================== */

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
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

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(d.year, d.month, d.day);

  if (day == today) return 'HOY';
  if (day == yesterday) return 'AYER';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

extension _FmtDate on DateTime {
  String formatNice() {
    final dd = day.toString().padLeft(2, '0');
    final mm = month.toString().padLeft(2, '0');
    final yy = year.toString();
    final hh = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  String formatHour() {
    final hh = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    return '$hh:$mi';
  }
}

// Fila clave-valor para bottom sheet (igual que en grabaciones)
Widget _kv(String key, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
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
          child: Text(value, style: const TextStyle(color: Colors.black87)),
        ),
      ],
    ),
  );
}
