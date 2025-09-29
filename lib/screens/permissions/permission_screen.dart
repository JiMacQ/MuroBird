import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> _requestMic(BuildContext context) async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } else if (status.isPermanentlyDenied) {
      // Si el usuario bloqueó permanentemente, abrir ajustes
      openAppSettings();
    } else {
      // Si solo negó, igual podemos mostrar Home pero sin audio
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colores del “botón 3D” del micrófono
    const accentLight = Color(0xFF27E2CB);
    const accentDark = Color(0xFF11BFA6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ===== Círculo 3D con micrófono =====
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentLight, accentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.mic, size: 64, color: Colors.white),
              ),
            ),

            const SizedBox(height: 28),

            // ===== Título y descripción =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Permitir acceso al micrófono',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Necesitamos acceso a tu micrófono para captar el audio de las aves',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ),

            const Spacer(flex: 3),

            // ===== Botón Aceptar =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                  onPressed: () => _requestMic(context),
                  child: const Text('Aceptar'),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ===== “Ahora no” =====
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, Routes.home),
              child: const Text(
                'Ahora no',
                style: TextStyle(
                  color: kBrand,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
