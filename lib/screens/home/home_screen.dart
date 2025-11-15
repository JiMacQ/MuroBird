// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _offlinePrefEnabled = false; // preferencia local de modo offline
  bool _noInternet = false; // estado de conectividad del device
  late final Stream<List<ConnectivityResult>> _connStream;

  @override
  void initState() {
    super.initState();
    _loadOfflinePref();

    // Escucha cambios de conectividad (API nueva: Stream<List<ConnectivityResult>>)
    _connStream = Connectivity().onConnectivityChanged;
    _connStream.listen((results) {
      final noNet = results.contains(ConnectivityResult.none);
      if (mounted) setState(() => _noInternet = noNet);
    });

    // Estado inicial de conectividad
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _noInternet = (r == ConnectivityResult.none));
    });
  }

  Future<void> _loadOfflinePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool('offline_enabled') ??
          false; // cambia la clave si usas otra
      if (mounted) setState(() => _offlinePrefEnabled = enabled);
    } catch (_) {
      if (mounted) setState(() => _offlinePrefEnabled = false);
    }
  }

  bool get _showOfflineBanner => _offlinePrefEnabled || _noInternet;

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      index: null, // Home: FAB central
      child: CustomScrollView(
        slivers: [
          // ===== APP BAR (sin banner) =====
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            centerTitle: true,
            toolbarHeight: 88,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),

          // ===== CONTENIDO =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '¿Qué ave vamos a buscar hoy?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),

                  const SizedBox(height: 15),

                  // === LOTTIE SIN RECUADRO NI FONDO ===
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Lottie.asset(
                        'assets/mock/bird.json',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Separador — Selecciona una opción —
                  Row(
                    children: const [
                      Expanded(child: Divider(thickness: 2, color: kDivider)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'Selecciona una opción',
                          style: TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(thickness: 2, color: kDivider)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ===== Botón: Tiempo real =====
                  _ActionButton(
                    label: 'Tiempo real',
                    icon: Icons.wifi_tethering,
                    onTap: () => Navigator.pushNamed(context, Routes.realtime),
                    primary: true,
                  ),
                  const SizedBox(height: 16),

                  // ===== Botón: Subir audio =====
                  _ActionButton(
                    label: 'Subir audio',
                    icon: Icons.upload_rounded,
                    onTap: () => Navigator.pushNamed(context, Routes.upload),
                    primary: false,
                  ),

                  // ===== Banner OFFLINE debajo de los botones =====
                  if (_showOfflineBanner)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAEA), // rojo muy suave
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF6B6B), // rojo borde
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFB00020),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'modo offline activado',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB00020), // rojo texto
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón estilo "pill" moderno con sombra suave, icono a la izquierda
/// y chevron a la derecha. `primary=true` aplica un relleno en color marca.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? kBrand : Colors.white;
    final fg = primary ? Colors.white : kBrand;
    final border = primary ? Colors.transparent : kBrand.withOpacity(.35);
    final subtleBg = primary ? null : kBrand.withOpacity(.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: subtleBg ?? bg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: border, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono en círculo
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withOpacity(.15) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primary ? Colors.white24 : border,
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 28, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
