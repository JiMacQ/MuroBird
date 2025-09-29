import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Encabezado verde consistente con el resto
          SliverAppBar(
            backgroundColor: kBrand,
            pinned: true,
            toolbarHeight: 96,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.podcasts_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Ayuda',
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Cómo empezar
                  _SectionCard(
                    icon: Icons.rocket_launch_rounded,
                    title: 'Cómo empezar',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet(
                          'Ve a “Tiempo real” para escuchar con el micrófono.',
                        ),
                        _Bullet(
                          'O toca “Subir audio” para analizar un archivo.',
                        ),
                        _Bullet(
                          'Otorga el permiso de micrófono cuando se solicite.',
                        ),
                        _Bullet(
                          'Mantén el teléfono estable y apunta hacia el ave.',
                        ),
                        _Bullet(
                          'Cuando la app identifique el canto, abre el resultado.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Mejores resultados
                  _SectionCard(
                    icon: Icons.tips_and_updates_rounded,
                    title: 'Consejos para mejores resultados',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet('Graba entre 10 y 30 segundos.'),
                        _Bullet('Evita viento fuerte y ruido de autos/vozes.'),
                        _Bullet(
                          'Acércate (sin perturbar) y apunta el micrófono.',
                        ),
                        _Bullet('Si puedes, usa un protector antiviento.'),
                        _Bullet('En “Subir audio” acepta .mp3, .wav y .m4a.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Preguntas frecuentes
                  _SectionCard(
                    icon: Icons.help_outline_rounded,
                    title: 'Preguntas frecuentes',
                    child: Column(
                      children: const [
                        _Faq(
                          q: 'No identifica el ave, ¿qué hago?',
                          a: 'Asegúrate de estar lo más cerca posible, reduce el ruido ambiente y prueba con otro fragmento del canto. También ayuda grabar 10–30 s y repetir.',
                        ),
                        _Faq(
                          q: '¿Necesito internet?',
                          a: 'Para este prototipo el flujo de navegación es local. En producción ciertos análisis y descargas de datos podrían requerir conexión.',
                        ),
                        _Faq(
                          q: '¿Qué permisos usa?',
                          a: 'Sólo el micrófono para capturar audio en tiempo real. Puedes gestionar los permisos desde Configuración > Permisos.',
                        ),
                        _Faq(
                          q: '¿Qué formatos de audio admite?',
                          a: '.mp3, .wav y .m4a (30 s mínimo, 30 min máximo).',
                        ),
                        _Faq(
                          q: '¿Cómo leo el espectrograma?',
                          a: 'Es una imagen del sonido en el tiempo. Bandas claras/oscuras muestran energía por frecuencia; patrones repetitivos suelen ser cantos.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Privacidad
                  _SectionCard(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacidad y uso de datos',
                    child: const Text(
                      'MuroBird procesa tus grabaciones únicamente para identificar el ave y mostrar su información. '
                      'No compartimos tus audios sin tu consentimiento. Puedes borrar grabaciones desde “Grabaciones”.',
                      style: TextStyle(fontSize: 16, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ===== Atajos rápidos
                  Row(
                    children: [
                      Expanded(
                        child: _CTAButton(
                          icon: Icons.wifi_tethering_rounded,
                          label: 'Tiempo real',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.realtime),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CTAButton(
                          icon: Icons.upload_rounded,
                          label: 'Subir audio',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.upload),
                        ),
                      ),
                    ],
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

/* ====================== Widgets auxiliares ====================== */

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
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
                    color: Colors.black87,
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
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0),
        childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        iconColor: kBrand,
        collapsedIconColor: kBrand,
        title: Text(
          q,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  const _CTAButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: kBrand, width: 2)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(40)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: kBrand),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: kBrand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
