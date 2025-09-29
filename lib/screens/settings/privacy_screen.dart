import 'package:flutter/material.dart';
import '../../widgets/birby_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: birbyBar('Políticas de seguridad'),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Aquí irá tu política de privacidad y seguridad de datos. '
          'Por ahora es un placeholder para diseño y navegación.',
        ),
      ),
    );
  }
}
