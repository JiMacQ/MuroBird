import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';

// === Offline ===
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../offline/offline_prefs.dart';
import '../../offline/offline_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideNext();
  }

  Future<void> _decideNext() async {
    // Breve animación de splash
    await Future.delayed(const Duration(milliseconds: 1400));

    // Revisa el estado del permiso de micrófono
    final status = await Permission.microphone.status;
    if (!mounted) return;

    if (!status.isGranted) {
      // Si está denegado o permanentemente denegado, ve a la pantalla de permisos
      Navigator.pushReplacementNamed(context, Routes.permissions);
      return;
    }

    // === Lógica de inicio OFFLINE (silenciosa) ===
    try {
      final offlineOn = await OfflinePrefs.enabled;
      final ready = await OfflineManager.isReady();

      if (offlineOn && !ready) {
        // Si el usuario quiere offline pero aún no hay paquete,
        // intentamos descargar e instalar en segundo plano.
        final conn = await Connectivity().checkConnectivity();
        if (conn != ConnectivityResult.none) {
          // Descarga sin progreso (rápida de integrar en splash).
          await OfflineManager.downloadAndInstall();
        }
        // Si no hay conexión, simplemente seguimos a Home (no bloqueamos el arranque).
      }
    } catch (_) {
      // Silencioso: no interrumpimos el flujo de arranque si falla.
    }

    if (!mounted) return;
    // Listo: vamos al Home
    Navigator.pushReplacementNamed(context, Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrand,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo_birby.png',
                    width: 112,
                    height: 112,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'MuroBird',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escucha. Detecta. Conoce',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            // Loader inferior
            const Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Column(
                children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
