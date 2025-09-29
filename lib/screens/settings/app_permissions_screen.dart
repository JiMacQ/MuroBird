import 'package:flutter/material.dart';
import '../../widgets/birby_app_bar.dart';

class AppPermissionsScreen extends StatelessWidget {
  const AppPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: birbyBar('Permisos'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.mic),
            title: Text('Micrófono'),
            subtitle: Text('Requerido para capturar cantos'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.sd_card),
            title: Text('Almacenamiento'),
            subtitle: Text('Guardar grabaciones y resultados'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.location_on_outlined),
            title: Text('Ubicación (opcional)'),
            subtitle: Text('Mejorar resultados según región'),
          ),
        ],
      ),
    );
  }
}
