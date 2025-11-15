import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  // Estados de permisos
  PermissionStatus mic = PermissionStatus.denied;
  PermissionStatus storage = PermissionStatus.denied;
  PermissionStatus photos = PermissionStatus.denied; // iOS
  PermissionStatus media = PermissionStatus.denied; // Android 13+
  PermissionStatus location = PermissionStatus.denied;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    setState(() => _loading = true);

    final micS = await Permission.microphone.status;

    // Almacenamiento / fotos (según plataforma/SDK)
    PermissionStatus storageS = PermissionStatus.denied;
    PermissionStatus photosS = PermissionStatus.denied;
    PermissionStatus mediaS = PermissionStatus.denied;

    if (Platform.isAndroid) {
      // Android 13+ usa permisos granulares para media
      mediaS =
          await Permission.photos.status; // incluye imágenes en Android 13+
      // Para compatibilidad con Android < 13:
      storageS = await Permission.storage.status;
    } else if (Platform.isIOS) {
      photosS = await Permission.photos.status;
    }

    // Ubicación (si la app muestra mapa o centra al usuario)
    final locS = await Permission.locationWhenInUse.status;

    setState(() {
      mic = micS;
      storage = storageS;
      photos = photosS;
      media = mediaS;
      location = locS;
      _loading = false;
    });
  }

  Future<void> _request(Permission p) async {
    await p.request();
    await _refreshStatuses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // ===== Encabezado =====
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
                Icon(Icons.mic_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Permisos de la app',
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
                onPressed: _refreshStatuses,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Actualizar',
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                children: [
                  _Card(
                    title: 'Micrófono',
                    icon: Icons.mic_rounded,
                    child: _PermRow(
                      description: 'Necesario para grabar cantos de aves.',
                      status: mic,
                      onRequest: () => _request(Permission.microphone),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Puedes cambiar estos permisos en cualquier momento desde los Ajustes del sistema.',
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

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.description,
    required this.status,
    this.label,
    required this.onRequest,
  });

  final String description;
  final String? label;
  final PermissionStatus status;
  final VoidCallback onRequest;

  Color _chipColor() {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green.shade600;
      case PermissionStatus.limited:
        return Colors.orange.shade700;
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
      default:
        return Colors.red.shade700;
    }
  }

  String _statusText() {
    switch (status) {
      case PermissionStatus.granted:
        return 'Concedido';
      case PermissionStatus.limited:
        return 'Limitado';
      case PermissionStatus.denied:
        return 'Denegado';
      case PermissionStatus.restricted:
        return 'Restringido';
      case PermissionStatus.permanentlyDenied:
        return 'Denegado permanentemente';
      default:
        return status.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      leading: const Icon(Icons.security_rounded, color: kBrand),
      title: Text(
        label ?? 'Permiso',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(description),
      trailing: GestureDetector(
        onTap: () async {
          await openAppSettings();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _chipColor(),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _statusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
