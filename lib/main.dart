import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart'; // IMPORTAR PARA LA INICIALIZACIÓN
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'features/auth/splash_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/push_notification_service.dart';

// Controlador global para cambiar el tema en tiempo real - Por defecto oscuro
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: '288138752009-cemtu054b432rgcldjof42fh925qgejj.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint("Error al inicializar Google Sign In: $e");
  }
  await PushNotificationService.inicializar();

  // Cargar preferencia guardada del tema
  try {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('theme_mode');
    if (themeStr != null) {
      themeNotifier.value = themeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
    }
  } catch (e) {
    debugPrint("Error al cargar preferencia de tema: $e");
  }

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