import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ======= Encabezado =======
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
                Icon(Icons.privacy_tip_outlined, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Política de privacidad',
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
                  // ===== Introducción =====
                  const _Card(
                    title: 'Introducción',
                    icon: Icons.info_outline,
                    child: Text(
                      'Esta política de privacidad describe cómo MuroBird maneja los datos del usuario, '
                      'tanto en modo online como offline. La aplicación se enfoca en ofrecer una experiencia '
                      'educativa y científica respetando la privacidad y seguridad de los usuarios.',
                      style: TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Datos recopilados =====
                  const _Card(
                    title: 'Datos recopilados',
                    icon: Icons.data_usage_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MuroBird recopila únicamente los datos necesarios para su funcionamiento:',
                          style: TextStyle(height: 1.3),
                        ),
                        SizedBox(height: 8),
                        _Bullet(
                          'Grabaciones de audio realizadas por el usuario (para análisis de cantos).',
                        ),
                        _Bullet(
                          'Preferencias locales como idioma, tema y configuración offline.',
                        ),
                        _Bullet(
                          'Datos de conexión o estado de red (solo para comprobar disponibilidad).',
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No se recopilan datos personales, credenciales ni información sensible.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Uso de la información =====
                  const _Card(
                    title: 'Uso de la información',
                    icon: Icons.manage_search_rounded,
                    child: Text(
                      'Los datos almacenados se utilizan únicamente para mejorar la funcionalidad interna de la aplicación, '
                      'como mantener el historial de búsquedas, conservar grabaciones locales o verificar la instalación '
                      'del paquete offline. No se transmiten ni comparten con terceros.',
                      style: TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Modo offline =====
                  const _Card(
                    title: 'Modo offline',
                    icon: Icons.cloud_off_rounded,
                    child: Text(
                      'El modo offline de MuroBird permite el uso de recursos descargados (imágenes, audios y mapas) sin conexión. '
                      'Todo el contenido descargado se guarda únicamente en el dispositivo del usuario y puede ser eliminado '
                      'en cualquier momento desde el panel de configuración.',
                      style: TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Derechos del usuario =====
                  const _Card(
                    title: 'Derechos del usuario',
                    icon: Icons.security_rounded,
                    child: Text(
                      'El usuario puede revisar, eliminar o restablecer los datos locales cuando lo desee. '
                      'No se realiza ningún tipo de seguimiento ni almacenamiento en servidores externos. '
                      'El control total de la información pertenece al usuario.',
                      style: TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Contacto =====
                  const _Card(
                    title: 'Contacto',
                    icon: Icons.mail_outline_rounded,
                    child: Text(
                      'Para comentarios o consultas sobre esta política, puede comunicarse con el desarrollador: '
                      '\n\nCreador: Justin Macías\nProyecto de tesis — 2025\nEmail: justinmacias@gmail.com',
                      style: TextStyle(height: 1.3),
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

/* ======================= Widgets reutilizables ======================= */

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
