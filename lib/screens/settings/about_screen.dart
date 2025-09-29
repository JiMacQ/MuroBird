import 'package:flutter/material.dart';
import '../../widgets/birby_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: birbyBar('Acerca de'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('MuroBird / Birby'),
            SizedBox(height: 6),
            Text('Versión 0.1.0 (prototipo UI)'),
            SizedBox(height: 12),
            Text('App para identificar aves mediante audio y micrófono.'),
          ],
        ),
      ),
    );
  }
}
