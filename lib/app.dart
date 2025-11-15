import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/routes.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/permissions/permission_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/realtime/realtime_screen.dart';
import 'screens/searching/searching_screen.dart';
import 'screens/upload/upload_audio_screen.dart';
import 'screens/result/result_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/recordings/recordings_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/privacy_screen.dart';
import 'screens/settings/app_permissions_screen.dart';

class BirbyApp extends StatelessWidget {
  const BirbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuroBird',
      debugShowCheckedModeBanner: false,
      theme: buildBirbyTheme(),
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => SplashScreen(),
        Routes.permissions: (_) => PermissionScreen(),
        Routes.home: (_) => HomeScreen(),
        Routes.realtime: (_) => RealtimeScreen(),
        Routes.searching: (_) => SearchingScreen(),
        Routes.upload: (_) => UploadAudioScreen(),
        Routes.result: (_) => ResultScreen(),
        Routes.help: (_) => HelpScreen(),
        Routes.recordings: (_) => RecordingsScreen(),
        Routes.history: (_) => HistoryScreen(),
        Routes.settings: (_) => SettingsScreen(),
        Routes.about: (_) => AboutScreen(),
        Routes.privacy: (_) => PrivacyScreen(),
        Routes.appPermissions: (_) => AppPermissionsScreen(),
        
      },
    );
  }
}
