import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ======= Encabezado (igual estilo que Configuración) =======
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            automaticallyImplyLeading: false,
            leadingWidth: 56,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Atrás',
              onPressed: () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushReplacementNamed(Routes.home);
                }
              },
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Acerca de MuroBird',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                children: [
                  // ===== Información general =====
                  const _Card(
                    title: 'Información',
                    icon: Icons.apps_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RowKV(label: 'Aplicación', value: 'MuroBird'),
                        SizedBox(height: 4),
                        _RowKV(label: 'Versión', value: '1.0 '),
                        SizedBox(height: 4),
                        _RowKV(label: 'Estado', value: 'Proyecto de tesis'),
                        SizedBox(height: 12),
                        Text(
                          'MuroBird es una app para identificar y explorar aves con búsqueda online y modo offline. '
                          'Permite trabajar con imágenes, audios y metadatos locales, integrando un paquete descargable '
                          'para funcionar sin conexión.',
                          style: TextStyle(height: 1.25),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Autor / Tesis =====
                  const _Card(
                    title: 'Autoría y propósito',
                    icon: Icons.account_circle_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RowKV(label: 'Creador', value: 'Justin Macías'),
                        SizedBox(height: 8),
                        Text(
                          'Este desarrollo corresponde a un proyecto de tesis orientado a crear una herramienta móvil '
                          'capaz de apoyar el reconocimiento de especies de aves y el acceso a su información, incluso '
                          'en contextos con conectividad limitada.',
                          style: TextStyle(height: 1.25),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Tecnologías =====
                  const _Card(
                    title: 'Tecnologías',
                    icon: Icons.developer_mode_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bullet('Flutter • Dart'),
                        _Bullet(
                          'Arquitectura con paquetes locales para modo offline',
                        ),
                        _Bullet(
                          'Gestión de descargas y verificación de assets',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Legal =====
                  _Card(
                    title: 'Información legal',
                    icon: Icons.policy_rounded,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          leading: const Icon(
                            Icons.privacy_tip_outlined,
                            color: kBrand,
                          ),
                          title: const Text(
                            'Política de privacidad',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.privacy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'MuroBird • v1.0\n© 2025',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ======================= Widgets locales ======================= */

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kBrand),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _RowKV extends StatelessWidget {
  const _RowKV({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: Colors.black54),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
