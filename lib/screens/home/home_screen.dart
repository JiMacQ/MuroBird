import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/bottom_nav_scaffold.dart';
import '../../widgets/pill_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      index: null, // Home: FAB central
      child: CustomScrollView(
        slivers: [
          // ===== APP BAR CENTRADO CON LOGO + TÍTULO =====
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
                // <- LOGO (imagen)
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

                  const SizedBox(height: 22),

                  // ONDA: más alta y ancha
                  Container(
                    height: 120, // << antes ~72
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kDivider, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Image.asset(
                        // usa tu imagen de la onda del mock
                        'assets/mock/wave_home.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.graphic_eq,
                          color: kBrand.withOpacity(.6),
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36), // más aire como en el mock
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

                  // Botones grandes estilo maqueta
                  PillButton(
                    icon: Icons.wifi_tethering,
                    label: 'Tiempo real',
                    borderWidth: 3.6,
                    fontSize: 20,
                    iconSize: 24,
                    radius: 28,
                    onTap: () => Navigator.pushNamed(context, Routes.realtime),
                  ),
                  const SizedBox(height: 18),
                  PillButton(
                    icon: Icons.upload_rounded,
                    label: 'Subir audio',
                    borderWidth: 3.6,
                    fontSize: 20,
                    iconSize: 22,
                    radius: 28,
                    onTap: () => Navigator.pushNamed(context, Routes.upload),
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
