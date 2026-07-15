import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';
import '../conductor_mapa/home_map_screen.dart';
import '../conductor_mapa/user_profile_screen.dart';
import '../taller_dashboard/taller_setup_screen.dart';

class WelcomeRoleScreen extends StatefulWidget {
  final User user;
  const WelcomeRoleScreen({super.key, required this.user});

  @override
  State<WelcomeRoleScreen> createState() => _WelcomeRoleScreenState();
}

class _WelcomeRoleScreenState extends State<WelcomeRoleScreen> {
  bool _isRegistering = false;

  // EL GATILLO: Guarda la decisión, registra en Firestore y avanza de forma omnidireccional
  Future<void> _seleccionarRolYContinuar(bool isTaller) async {
    setState(() => _isRegistering = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('last_role_is_taller', isTaller); // Guardamos el rol en memoria
      await prefs.setString('user_role', isTaller ? 'taller' : 'conductor');

      if (isTaller) {
        // Registro en Firestore para Taller
        await FirebaseFirestore.instance.collection('talleres').doc(widget.user.uid).set({
          'uid': widget.user.uid,
          'correo': widget.user.email ?? '',
          'rol': 'taller',
          'nombre': widget.user.displayName ?? 'Taller de Geocar',
          'photoUrl': widget.user.photoURL,
          'estado': 'cerrado',
          'fecha_registro': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const TallerSetupScreen()),
            (route) => false,
          );
        }
      } else {
        // Registro en Firestore para Conductor
        await FirebaseFirestore.instance.collection('usuarios').doc(widget.user.uid).set({
          'uid': widget.user.uid,
          'correo': widget.user.email ?? '',
          'rol': 'conductor',
          'nombre': widget.user.displayName ?? 'Usuario de Geocar',
          'photoUrl': widget.user.photoURL,
          'vehiculos': [],
          'fecha_registro': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // Ir directo al mapa
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeMapScreen()),
            (route) => false,
          );
          // E inyectamos el perfil para que registre su vehículo de inmediato
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserProfileScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al configurar tu rol: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Pantalla de carga estética mientras registra el perfil en Firestore
    if (_isRegistering) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Configurando tu experiencia...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(themeNotifier.value == ThemeMode.light ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: colorScheme.onSurface),
            onPressed: () async {
              final nuevoModo = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              themeNotifier.value = nuevoModo;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('theme_mode', nuevoModo == ThemeMode.dark ? 'dark' : 'light');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                '¡Felicidades!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta ha sido creada. Ahora selecciona cómo vas a utilizar GeoCar hoy:',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              const Spacer(),

              _buildRoleCard(
                context,
                title: 'Necesito un Mecánico',
                subtitle: 'Encuentra talleres cerca de ti en Cabimas.',
                icon: Icons.drive_eta_outlined,
                color: colorScheme.secondary,
                isTaller: false,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),

              _buildRoleCard(
                context,
                title: 'Soy un Taller',
                subtitle: 'Registra tu negocio y recibe clientes.',
                icon: Icons.build_circle_outlined,
                color: colorScheme.primary,
                isTaller: true,
                colorScheme: colorScheme,
              ),
              const Spacer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isTaller,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: () => _seleccionarRolYContinuar(isTaller),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: colorScheme.onSurface.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}