import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/splash_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/push_notification_service.dart';

// Controlador global para cambiar el tema en tiempo real
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.inicializar();
  runApp(const GeocarApp());
}

class GeocarApp extends StatelessWidget {
  const GeocarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el cambio de tema para repintar la app entera
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Geocar',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,   // Conectamos el tema claro
          darkTheme: AppTheme.darkTheme, // Conectamos el tema oscuro
          themeMode: currentMode,       // Decide cuál usar según el controlador
          home: const SplashScreen(),
        );
      },
    );
  }
}