import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Estados demo (prototipo)
  bool _darkMode = false;
  bool _saveAuto = true;
  bool _haptics = true;
  bool _uiSounds = false;
  bool _tips = true;

  String _language = 'es';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          // Header consistente
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
                Icon(Icons.settings_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Configuración',
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
                  // ===== App / Perfil =====
                  _Card(
                    title: 'Aplicación',
                    icon: Icons.apps_rounded,
                    child: Column(
                      children: [
                        _NavTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: kBrand,
                          ),
                          title: 'Acerca de MuroBird',
                          subtitle: 'Versión 1.0.0 (demo)',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.about),
                        ),
                        const Divider(height: 1),
                        _RowTile(
                          leading: const Icon(
                            Icons.language_rounded,
                            color: kBrand,
                          ),
                          title: 'Idioma',
                          trailing: DropdownButton<String>(
                            value: _language,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'es',
                                child: Text('Español'),
                              ),
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'pt',
                                child: Text('Português'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _language = v ?? 'es'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Preferencias =====
                  _Card(
                    title: 'Preferencias',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        _SwitchTile(
                          leading: const Icon(
                            Icons.dark_mode_rounded,
                            color: kBrand,
                          ),
                          title: 'Tema oscuro',
                          value: _darkMode,
                          onChanged: (v) => setState(() => _darkMode = v),
                        ),
                        const Divider(height: 1),
                        _SwitchTile(
                          leading: const Icon(
                            Icons.save_alt_rounded,
                            color: kBrand,
                          ),
                          title: 'Guardar automáticamente las grabaciones',
                          subtitle: 'Se guardan en “Grabaciones” al finalizar',
                          value: _saveAuto,
                          onChanged: (v) => setState(() => _saveAuto = v),
                        ),
                        const Divider(height: 1),
                        _SwitchTile(
                          leading: const Icon(
                            Icons.vibration_rounded,
                            color: kBrand,
                          ),
                          title: 'Vibración (haptics)',
                          value: _haptics,
                          onChanged: (v) => setState(() => _haptics = v),
                        ),
                        const Divider(height: 1),
                        _SwitchTile(
                          leading: const Icon(
                            Icons.volume_up_rounded,
                            color: kBrand,
                          ),
                          title: 'Sonidos de interfaz',
                          value: _uiSounds,
                          onChanged: (v) => setState(() => _uiSounds = v),
                        ),
                        const Divider(height: 1),
                        _SwitchTile(
                          leading: const Icon(
                            Icons.tips_and_updates_rounded,
                            color: kBrand,
                          ),
                          title: 'Mostrar consejos',
                          value: _tips,
                          onChanged: (v) => setState(() => _tips = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Permisos & Privacidad =====
                  _Card(
                    title: 'Permisos y privacidad',
                    icon: Icons.privacy_tip_outlined,
                    child: Column(
                      children: [
                        _NavTile(
                          leading: const Icon(Icons.mic_rounded, color: kBrand),
                          title: 'Permisos de la app',
                          subtitle: 'Micrófono y otros',
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.appPermissions,
                          ),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          leading: const Icon(
                            Icons.policy_rounded,
                            color: kBrand,
                          ),
                          title: 'Política de privacidad',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.privacy),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          leading: const Icon(
                            Icons.help_outline_rounded,
                            color: kBrand,
                          ),
                          title: 'Ayuda',
                          onTap: () =>
                              Navigator.pushNamed(context, Routes.help),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ===== Datos locales / mantenimiento =====
                  _Card(
                    title: 'Datos locales',
                    icon: Icons.storage_rounded,
                    child: Column(
                      children: [
                        _DangerTile(
                          leading: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.red,
                          ),
                          title: 'Borrar historial',
                          onTap: () => _confirm(
                            context,
                            title: 'Borrar historial',
                            message:
                                'Se eliminarán todas las entradas del historial. Esta acción no se puede deshacer.',
                            onOk: () => _ok('Historial borrado'),
                          ),
                        ),
                        const Divider(height: 1),
                        _DangerTile(
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.red,
                          ),
                          title: 'Borrar grabaciones locales',
                          onTap: () => _confirm(
                            context,
                            title: 'Borrar grabaciones',
                            message:
                                'Se eliminarán las grabaciones guardadas en el dispositivo (demo).',
                            onOk: () => _ok('Grabaciones borradas'),
                          ),
                        ),
                        const Divider(height: 1),
                        _NavTile(
                          leading: const Icon(
                            Icons.ios_share_rounded,
                            color: kBrand,
                          ),
                          title: 'Exportar datos (demo)',
                          onTap: () => _ok('Exportación (demo)'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  // Nota de versión / copyright
                  const Text(
                    'MuroBird • prototipo UI\n© 2025',
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

  void _ok(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOk,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onOk();
            },
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

/* ======================= Widgets auxiliares ======================= */

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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: trailing,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      secondary: leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
      activeColor: kBrand,
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.leading,
    required this.title,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
      onTap: onTap,
    );
  }
}
