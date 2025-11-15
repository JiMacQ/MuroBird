// lib/screens/result/result_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/theme.dart';
import '../../services/wiki_bird_service.dart';
import '../../services/gbif_service.dart';
import '../../widgets/distribution_map.dart';
import '../../widgets/reference_audios.dart';
import '../../widgets/species_gallery_grid.dart';
import '../../widgets/spectrogram_card.dart';

// OFFLINE
import 'dart:io';
import '../../offline/offline_prefs.dart';
import '../../offline/offline_manager.dart';
import '../../offline/offline_models.dart';
import '../../widgets/distribution_map_offline.dart';
import 'package:flutter/painting.dart'
    show PaintingBinding; // <- para limpiar caché de imágenes

/// ---------------- helpers binomiales / limpieza ----------------
String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');
String? _asLatin(String text) {
  final t = _stripHtml(text).replaceAll('*', ' ').trim();
  final m = RegExp(r'\b([A-Z][a-zA-Z-]+)\s+([a-z-]+)\b').firstMatch(t);
  if (m == null) return null;
  return '${m.group(1)!} ${m.group(2)!}';
}

String _cleanLabel(String raw) {
  final noTags = _stripHtml(raw);
  final norm = noTags
      .replaceAll('*', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final latin = _asLatin(norm);
  return latin ?? norm;
}

/// Acepta URL http(s) o ruta local; si no, placeholder.
ImageProvider _imgProvider(String? src) {
  if (src == null || src.isEmpty) {
    return const AssetImage('assets/mock/placeholder.jpg');
  }
  final s = src.toLowerCase();
  if (s.startsWith('http')) {
    // filtra svg / data
    if (s.startsWith('data:'))
      return const AssetImage('assets/mock/placeholder.jpg');
    if (s.endsWith('.svg') || s.contains('format=svg')) {
      return const AssetImage('assets/mock/placeholder.jpg');
    }
    return NetworkImage(src);
  }
  // ¿archivo local?
  final f = File(src);
  if (f.existsSync()) return FileImage(f);
  return const AssetImage('assets/mock/placeholder.jpg');
}

bool _isSupportedNetImage(String url) {
  final u = url.toLowerCase();
  if (u.startsWith('data:')) return false;
  if (u.endsWith('.svg') || u.contains('format=svg')) return false;
  return u.startsWith('http');
}

/// normaliza para comparar duplicados
String _norm(String s) => _cleanLabel(
  s,
).replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

bool _already(List<_Candidate> xs, String name) =>
    xs.any((e) => _norm(e.name) == _norm(name));

/// ---------------------------------------------------------------

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final List<_Candidate> _views; // máx 3
  int _current = 0;
  // <--- pega aquí
  Future<dynamic> _loadDetails(String currentName) async {
    final offline = await OfflinePrefs.enabled;
    final ready = await OfflineManager.isReady();
    if (offline && ready) {
      final m = await OfflineManager.findByScientificName(currentName);
      if (m == null) return null;
      final adapted = await OfflineManager.adaptAssets(m);
      return OfflineBirdDetails.fromDb(adapted);
    } else {
      return await WikiBirdService.fetch(currentName);
    }
  }
  // <--- hasta aquí

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = (ModalRoute.of(context)!.settings.arguments ?? {}) as Map;
    final rawTopBird = (args['topBird'] ?? '') as String;
    final topBird = _cleanLabel(rawTopBird);
    final List raw = (args['candidates'] ?? []) as List;

    // arma vistas: principal + coincidencias (sin duplicar) hasta 3
    final List<_Candidate> tmp = [];
    if (topBird.isNotEmpty && !_already(tmp, topBird)) {
      tmp.add(_Candidate(name: topBird, score: 1.0));
    }
    for (final c in raw) {
      final nm = _cleanLabel((c['name'] as String?) ?? '');
      if (nm.isEmpty) continue;
      if (_already(tmp, nm)) continue; // evita duplicados exactos
      tmp.add(
        _Candidate(
          name: nm,
          score: (c['confidence'] as num?)?.toDouble() ?? 0.0,
          start: (c['start'] as num?)?.toDouble(),
          end: (c['end'] as num?)?.toDouble(),
        ),
      );
      if (tmp.length >= 3) break;
    }
    _views = tmp.where((e) => e.name.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentName = _views[_current].name;

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<dynamic>(
        key: ValueKey(
          'fb-$currentName',
        ), // <- fuerza reconstrucción al cambiar de especie
        future: _loadDetails(currentName), // <- evita capturar valores viejos

        builder: (context, snap) {
          final waiting =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final data = snap.data;

          final bool isOffline = data is OfflineBirdDetails;
          final OfflineBirdDetails? off = isOffline
              ? data as OfflineBirdDetails
              : null;
          final BirdDetails? onl = !isOffline ? data as BirdDetails? : null;

          // ===== DEBUG: verifica que cambian los archivos por especie =====
          if (isOffline && off != null) {
            debugPrint('[OFF] $currentName | $off');
            debugPrint(' cover: ${off.coverImage}');
            debugPrint(
              ' spec : ${off.spectrograms.isNotEmpty ? off.spectrograms.first : "-"}',
            );
            debugPrint(' geo  : ${off.distributionGeoJson}');
            debugPrint(' audio: ${off.audios}');
          } else {
            debugPrint('[ONLINE] $currentName');
          }
          // ===== FIN DEBUG =================================================

          // título y nombre científico unificados
          final sciName = isOffline
              ? off!.scientificName
              : (_asLatin(onl?.displayTitle ?? '') ??
                        _asLatin(onl?.scientificName ?? '') ??
                        _asLatin(currentName) ??
                        '')
                    .trim();

          final displayTitle = isOffline
              ? (off!.displayTitle.isNotEmpty ? off.displayTitle : currentName)
              : (_cleanLabel(onl?.displayTitle ?? currentName));

          // imagen principal (hero) y miniatura
          final heroSrc = isOffline
              ? (off!.coverImage ?? '')
              : (onl?.mainImage ?? '');
          final hero = (heroSrc.isNotEmpty) ? heroSrc : null;

          final List<String> galNet = (onl?.gallery ?? [])
              .whereType<String>()
              .where(_isSupportedNetImage)
              .toList();

          final thumbUrl =
              hero ??
              (isOffline
                  ? (off!.gallery.isNotEmpty ? off.gallery.first : null)
                  : (galNet.isNotEmpty ? galNet.first : null));

          // cachea para usar en los avatares laterales
          if (thumbUrl != null && _views[_current].lastMainImage == null) {
            _views[_current].lastMainImage = thumbUrl;
          }

          // índices vecinos para los laterales
          final leftIndex = (_current - 1) >= 0 ? _current - 1 : null;
          final rightIndex = (_current + 1) < _views.length
              ? _current + 1
              : null;

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    key: ValueKey('head-$sciName'), // ← NUEVO
                    index: _current,
                    total: _views.length,
                    onBack: () => Navigator.pop(context),
                    onPickIndex: (i) {
                      setState(() => _current = i);

                      // ← IMPORTANTE: limpiar caché de imágenes al cambiar de especie
                      PaintingBinding.instance.imageCache.clear();
                      PaintingBinding.instance.imageCache.clearLiveImages();
                    },

                    onShare: () {
                      final uri = Uri.parse(
                        'https://www.google.com/search?q=$currentName ave',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    // imágenes (aceptan ruta local o url)
                    mainImage: hero,
                    sideLeftImage: leftIndex != null
                        ? _views[leftIndex].lastMainImage
                        : null,
                    sideRightImage: rightIndex != null
                        ? _views[rightIndex].lastMainImage
                        : null,

                    // textos del pill
                    displayTitle: displayTitle,
                    alsoKnown: '—', // por ahora sin aliases
                    scientific: sciName,
                    familyTitle: (sciName.isNotEmpty
                        ? sciName.split(' ').first
                        : (_asLatin(currentName)?.split(' ').first ?? '')),
                    familySci: '',
                  ),
                ),

                // loader fino bajo el header
                if (waiting)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LinearProgressIndicator(color: kBrand),
                    ),
                  ),

                // ====================== CONTENIDO ======================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionRow(
                          icon: Icons.menu_book_rounded,
                          title: 'Descripción',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOffline
                              ? ((off!.descriptionEs ??
                                        off.descriptionEn ??
                                        'Sin descripción.')
                                    .trim())
                              : ((onl?.summary ??
                                        'No encontramos una descripción para esta especie. Intenta con otro nombre o revisa tu grabación.')
                                    .trim()),
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 22),

                        const _SectionRow(
                          icon: Icons.podcasts_rounded,
                          title: 'Audios de referencia',
                        ),
                        const SizedBox(height: 8),
                        if (isOffline && (off!.audios.isNotEmpty))
                          _LocalAudioList(
                            key: ValueKey('aud-off-${off.audios.join("|")}'),
                            files: off.audios,
                          )
                        else if (sciName.isNotEmpty)
                          ReferenceAudios(
                            key: ValueKey('aud-$sciName'),
                            scientificName: sciName,
                            limit: 6,
                          )
                        else
                          const Text(
                            'No hay audios de referencia disponibles.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        const SizedBox(height: 24),

                        // --- Espectrograma ---
                        const _SectionRow(
                          icon: Icons.show_chart,
                          title: 'Espectrograma',
                        ),
                        const SizedBox(height: 10),
                        if (isOffline && off!.spectrograms.isNotEmpty)
                          Image.file(
                            File(off.spectrograms.first),
                            key: ValueKey('spec-off-${off.spectrograms.first}'),
                            height: 160,
                            fit: BoxFit.cover,
                          )
                        else
                          SpectrogramCard(
                            key: ValueKey('spec-$sciName'),
                            scientificName: sciName,
                          ),
                        const SizedBox(height: 24),

                        const _SectionRow(
                          icon: Icons.public_rounded,
                          title: 'Mapa de distribución',
                        ),
                        const SizedBox(height: 10),
                        if (isOffline &&
                            (off!.distributionGeoJson?.isNotEmpty ?? false))
                          DistributionMapOffline(
                            key: ValueKey('map-off-${off.distributionGeoJson}'),
                            geoJsonPath: off!.distributionGeoJson!,
                          )
                        else
                          FutureBuilder<int?>(
                            key: ValueKey('map-$sciName'),
                            future: sciName.isNotEmpty
                                ? GbifService.fetchSpeciesKey(sciName)
                                : Future.value(null),
                            builder: (context, snapGbif) {
                              if (snapGbif.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: LinearProgressIndicator(color: kBrand),
                                );
                              }
                              final speciesKey = snapGbif.data;
                              if (speciesKey == null) {
                                return const Text(
                                  'No encontramos el taxón en GBIF.',
                                  style: TextStyle(color: Colors.black54),
                                );
                              }
                              return DistributionMap(
                                key: ValueKey('dist-$speciesKey'),
                                taxonKey: speciesKey.toString(),
                                showPoints: true,
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        const _SectionRow(
                          icon: Icons.photo_camera_back_rounded,
                          title: 'Galería',
                        ),
                        const SizedBox(height: 10),

                        // ======= OFFLINE =======
                        if (isOffline) ...[
                          (() {
                            // Combinar cover + gallery y evitar duplicados
                            final imgs = <String>[];
                            if (off!.coverImage != null &&
                                off.coverImage!.isNotEmpty) {
                              imgs.add(off.coverImage!);
                            }
                            imgs.addAll(off.gallery.where((e) => e.isNotEmpty));

                            // Unicos
                            final seen = <String>{};
                            final finalList = <String>[];
                            for (final p in imgs) {
                              if (seen.add(p)) finalList.add(p);
                            }

                            if (finalList.isEmpty) {
                              return const Text(
                                'Sin imágenes disponibles.',
                                style: TextStyle(color: Colors.black54),
                              );
                            }

                            return GridView.builder(
                              key: ValueKey('gal-off-${finalList.join("|")}'),
                              itemCount: finalList.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: _imgProvider(finalList[i]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          })(),
                        ]
                        // ======= ONLINE =======
                        else ...[
                          SpeciesGalleryGrid(
                            key: ValueKey('gal-$sciName'),
                            scientificName: sciName,
                            initialUrls: galNet,
                            limit: 12,
                            debug: false,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // ============ Otras coincidencias como “chips” navegables ============
                        const _SectionRow(
                          icon: Icons.pets_rounded,
                          title: 'Otras coincidencias',
                        ),
                        const SizedBox(height: 8),
                        if (_views.length <= 1)
                          const Text(
                            'No se encontraron más especies.',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(_views.length, (i) {
                              final v = _views[i];
                              return ChoiceChip(
                                selected: i == _current,
                                label: Text(
                                  v.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                selectedColor: kBrand.withOpacity(.15),
                                onSelected: (_) => setState(() => _current = i),
                              );
                            }),
                          ),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===== Header (gradiente + avatares + pill + indicadores 1..3) =====
class _Header extends StatelessWidget {
  const _Header({
    super.key, // ✅ agrega esta línea
    required this.index,
    required this.total,
    required this.onBack,
    required this.onPickIndex,
    required this.onShare,
    required this.mainImage,
    required this.sideLeftImage,
    required this.sideRightImage,
    required this.displayTitle,
    required this.alsoKnown,
    required this.scientific,
    required this.familyTitle,
    required this.familySci,
  });

  final int index, total;
  final VoidCallback onBack, onShare;
  final ValueChanged<int> onPickIndex;
  final String? mainImage, sideLeftImage, sideRightImage;

  final String displayTitle;
  final String alsoKnown;
  final String scientific;
  final String familyTitle; // usamos género cuando no hay familia
  final String familySci; // puede ir vacío

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 408,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // gradiente
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFACF0E4), Color(0xFF78B4D6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // back
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(.85),
                shape: const CircleBorder(),
                fixedSize: const Size(44, 44),
              ),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: kBrand, size: 24),
            ),
          ),
          // avatares laterales
          if (sideLeftImage != null)
            Positioned(
              left: -28,
              top: 70,
              child: _SideAvatar(imageSrc: sideLeftImage!),
            ),
          if (sideRightImage != null)
            Positioned(
              right: -28,
              top: 70,
              child: _SideAvatar(imageSrc: sideRightImage!),
            ),

          // avatar principal (círculo real y centrado)
          Positioned(
            top: 36,
            left: 0,
            right: 0,
            child: Center(child: _MainAvatar(imageSrc: mainImage)),
          ),

          // indicadores 1..N (máx 3)
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                total,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _IndexDot(
                    label: '${i + 1}',
                    selected: i == index,
                    onTap: () => onPickIndex(i),
                  ),
                ),
              ),
            ),
          ),

          // tarjeta tipo “pill” con textos
          Positioned(
            left: 12,
            right: 12,
            top: 248,
            child: _TitlePill(
              titleLeading: displayTitle,
              titleFamily: familyTitle.isNotEmpty ? familyTitle : '—',
              familySci: familySci,
              alsoKnown: alsoKnown.isNotEmpty ? alsoKnown : '—',
              scientific: scientific.isNotEmpty ? scientific : '—',
              onShare: onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideAvatar extends StatelessWidget {
  const _SideAvatar({super.key, required this.imageSrc});
  final String imageSrc;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image(
        key: ValueKey('side-$imageSrc'), // ← NUEVO
        image: _imgProvider(imageSrc),
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _MainAvatar extends StatelessWidget {
  const _MainAvatar({super.key, this.imageSrc});
  final String? imageSrc;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 156,
      child: ClipOval(
        child: Image(
          key: ValueKey('main-${imageSrc ?? "none"}'), // ← NUEVO
          image: _imgProvider(imageSrc),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _IndexDot extends StatelessWidget {
  const _IndexDot({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? kBrand : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TitlePill extends StatelessWidget {
  const _TitlePill({
    required this.titleLeading,
    required this.titleFamily,
    required this.familySci,
    required this.alsoKnown,
    required this.scientific,
    required this.onShare,
  });

  final String titleLeading, titleFamily, familySci, alsoKnown, scientific;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // título
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        height: 1.25,
                      ),
                      children: [
                        TextSpan(
                          text: '$titleLeading, ',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const TextSpan(text: 'una especie de '),
                        TextSpan(
                          text: '$titleFamily ',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (familySci.isNotEmpty)
                          TextSpan(
                            text: '($familySci)',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                      children: [
                        const TextSpan(text: 'También conocido como: '),
                        TextSpan(
                          text: alsoKnown,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                      children: [
                        const TextSpan(text: 'Nombre científico: '),
                        TextSpan(
                          text: scientific,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // share
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              splashRadius: 20,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección (fila con ícono)
class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Modelo simple para las vistas 1..3
class _Candidate {
  _Candidate({required this.name, required this.score, this.start, this.end});

  final String name;
  final double score;
  final double? start, end;

  // cache: última imagen principal resuelta para usar en avatares laterales
  String? lastMainImage;
}

// ---- pequeña extensión segura ----
extension _SplitFirst on String {
  String? get firstOrNull {
    final p = trim().split(RegExp(r'\s+'));
    return p.isEmpty ? null : p.first;
  }
}

/// ================= Audios locales =================
class _LocalAudioList extends StatefulWidget {
  const _LocalAudioList({super.key, required this.files}); // <- añade super.key
  final List<String> files;
  @override
  State<_LocalAudioList> createState() => _LocalAudioListState();
}

class _LocalAudioListState extends State<_LocalAudioList> {
  final _player = AudioPlayer();
  String? _current;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  @override
  void didUpdateWidget(covariant _LocalAudioList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files.join('|') != widget.files.join('|')) {
      // Cambió la especie / archivos: resetea el player y estado
      _player.stop();
      _current = null;
      _pos = Duration.zero;
      _dur = Duration.zero;
      _state = PlayerState.stopped;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
    _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _dur = d);
    });
    _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String path) async {
    if (_current == path && _state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (_current != path) {
      _current = path;
      _pos = Duration.zero;
      _dur = Duration.zero;
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } else {
      await _player.resume();
    }
    setState(() {});
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) {
      return const Text(
        'No hay audios de referencia disponibles.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      children: widget.files.map((path) {
        final selected = _current == path;
        final playing = selected && _state == PlayerState.playing;
        final name = path.split('/').last;

        final pos = selected ? _pos : Duration.zero;
        final dur = selected
            ? (_dur == Duration.zero ? Duration(seconds: 1) : _dur)
            : const Duration(seconds: 1);
        final value =
            pos.inMilliseconds.clamp(0, dur.inMilliseconds) /
            dur.inMilliseconds;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _toggle(path),
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black12,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value.isNaN ? 0 : value,
                  onChanged: selected && _dur > Duration.zero
                      ? (v) async {
                          final target = Duration(
                            milliseconds: (v * _dur.inMilliseconds).round(),
                          );
                          await _player.seek(target);
                        }
                      : null,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(pos),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _fmt(selected ? _dur : Duration.zero),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
