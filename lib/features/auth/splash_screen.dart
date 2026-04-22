import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'welcome_role_screen.dart';
import '../taller_dashboard/taller_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para arreglar FirebaseFirestore
import 'package:firebase_auth/firebase_auth.dart';      // Para el User? user
import '../conductor_mapa/home_map_screen.dart';       // Para que reconozca HomeMapScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Configuración del "Latido" o "Pulso" del radar
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      String? role = prefs.getString('user_role');

      // Si por alguna razón el teléfono olvidó el rol, lo buscamos en la nube
      if (role == null) {
        // Primero probamos si está en la colección de talleres
        var tallerDoc = await FirebaseFirestore.instance.collection('talleres').doc(user.uid).get();
        role = tallerDoc.exists ? 'taller' : 'conductor';
        await prefs.setString('user_role', role);
      }

      if (!mounted) return;

      // AHORA SÍ: Navegación basada en la realidad
      if (role == 'taller') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TallerDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeMapScreen()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WelcomeRoleScreen()));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Efecto de Radar / Spatial Design
            AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withOpacity(0.05),
                        border: Border.all(color: colorScheme.primary.withOpacity(0.1), width: 2),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.1),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ]
                          ),
                          child: const Icon(Icons.location_on_rounded, size: 60, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                }
            ),
            const SizedBox(height: 40),

            // Tipografía Premium
            TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, double opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - opacity)),
                      child: Column(
                        children: [
                          Text(
                            'GEOCAR',
                            style: GoogleFonts.poppins(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              letterSpacing: 6.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tu red mecánica en Cabimas',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
            ),
          ],
        ),
      ),
    );
  }
}