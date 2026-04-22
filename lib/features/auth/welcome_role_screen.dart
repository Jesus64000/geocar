import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';
import '../../main.dart'; // Para el botón de modo oscuro

class WelcomeRoleScreen extends StatelessWidget {
  const WelcomeRoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Cambia según el modo oscuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Mantenemos el botón de modo oscuro aquí también
          IconButton(
            icon: Icon(themeNotifier.value == ThemeMode.light ? Icons.dark_mode : Icons.light_mode, color: colorScheme.onSurface),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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
                'Bienvenido a Geocar',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Cómo vas a usar la aplicación hoy?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              const Spacer(),

              // Tarjeta del Conductor
              _buildRoleCard(
                context,
                title: 'Necesito un Mecánico',
                subtitle: 'Encuentra talleres cerca de ti en Cabimas.',
                icon: Icons.drive_eta_outlined,
                color: colorScheme.secondary, // Usamos el color secundario (celeste)
                isTaller: false,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),

              // Tarjeta del Taller
              _buildRoleCard(
                context,
                title: 'Soy un Taller',
                subtitle: 'Registra tu negocio y recibe clientes.',
                icon: Icons.build_circle_outlined,
                color: colorScheme.primary, // Usamos el azul principal
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
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen(isTaller: isTaller)));
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5), // Fondo inteligente
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2), // Borde del color de la acción
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