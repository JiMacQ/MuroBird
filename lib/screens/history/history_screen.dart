import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/theme.dart';
import 'history_store.dart'; // ← usamos el store real

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  // colección agregada
  List<CollectionItem> _items = [];
  bool _loading = true;

  /// mini caché de imágenes
  final Map<String, String?> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(); // recarga al volver
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final col = await HistoryStore.buildCollection();
    setState(() {
      _items = col;
      _loading = false;
    });
  }

  // === Miniaturas: intenta es→en, originalimage antes que thumbnail y filtra SVG/data ===
  Future<String?> _fetchThumb(String title) async {
    if (_thumbCache.containsKey(title)) return _thumbCache[title];

    Future<String?> tryLang(String lang, String q) async {
      final url =
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(q)}';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;

      final m = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      String? pick(Map<String, dynamic> x, String k) =>
          (x[k] is Map) ? (x[k]['source'] as String?) : null;

      final original = pick(m, 'originalimage');
      final thumb = pick(m, 'thumbnail');
      String? best = original ?? thumb;

      if (best == null) return null;
      final u = best.toLowerCase();
      if (u.startsWith('data:')) return null;
      if (u.endsWith('.svg') || u.contains('format=svg')) return null;
      return best;
    }

    // Probar primero en español (suele traer mejor portada), luego en inglés
    final q = title.trim();
    String? img = await tryLang('es', q) ?? await tryLang('en', q);

    _thumbCache[title] = img;
    return img;
  }

  Future<String?> _thumbFor(CollectionItem e) async {
    return await _fetchThumb(e.scientificName) ??
        await _fetchThumb(e.commonName);
  }

  Future<bool> _handleBack(BuildContext context) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed('/'); // ajusta a tu home
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleBack(context),
      child: Scaffold(
        backgroundColor: kBg,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: kBrand,
              pinned: true,
              toolbarHeight: 96,
              centerTitle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              automaticallyImplyLeading: false,
              leadingWidth: 56,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => _handleBack(context),
                tooltip: 'Atrás',
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.menu_book_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Mi colección',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Actualizar',
                ),
              ],
            ),

            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_items.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: _EmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 3.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BirdCard(
                      item: _items[i],
                      thumbFuture: _thumbFor(_items[i]),
                    ),
                    childCount: _items.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ============================ Widgets ============================= */

class _BirdCard extends StatelessWidget {
  const _BirdCard({required this.item, required this.thumbFuture});

  final CollectionItem item;
  final Future<String?> thumbFuture;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 3 / 2,
              child: FutureBuilder<String?>(
                future: thumbFuture,
                builder: (context, snap) {
                  final waiting =
                      snap.connectionState == ConnectionState.waiting;
                  final url = snap.data;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFFEFEFEF)),
                      if (url != null && url.isNotEmpty)
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          loadingBuilder: (c, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 36,
                              color: Colors.black26,
                            ),
                          ),
                        )
                      else if (waiting)
                        const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.black26,
                            size: 36,
                          ),
                        ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            iconSize: 20,
                            tooltip: 'Más',
                            onPressed: () => _showInfo(context, item),
                            icon: const Icon(Icons.more_horiz, color: kBrand),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                item.commonName.isNotEmpty
                    ? item.commonName
                    : item.scientificName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: .2,
                  color: Color(0xFF2F3B39),
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, CollectionItem e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        String fmtDate(DateTime? d) {
          if (d == null) return '—';
          String two(int x) => x.toString().padLeft(2, '0');
          return '${two(d.day)}/${two(d.month)}/${d.year} '
              '${two(d.hour)}:${two(d.minute)}';
        }

        return Padding(
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
                    'Información breve',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv('Ave', e.commonName.isNotEmpty ? e.commonName : '—'),
              _kv(
                'Nombre científico',
                e.scientificName.isNotEmpty ? e.scientificName : '—',
              ),
              _kv('Vistas', e.views.toString()),
              _kv(
                'Mejor confianza',
                e.bestConfidence != null
                    ? '${e.bestConfidence!.toStringAsFixed(0)} %'
                    : '—',
              ),
              _kv('Última vez', fmtDate(e.lastSeen)),
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
        );
      },
    );
  }
}

Widget _kv(String key, String value) => Padding(
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
      Expanded(child: Text(value, softWrap: true)),
    ],
  ),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Column(
    children: const [
      Icon(
        Icons.collections_bookmark_outlined,
        size: 64,
        color: Colors.black26,
      ),
      SizedBox(height: 10),
      Text(
        'Sin aves guardadas',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 6),
      Text(
        'Tu colección mostrará el nombre y una foto de Internet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      ),
    ],
  );
}
