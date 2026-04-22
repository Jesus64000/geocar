import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'taller_profile_screen.dart';
import 'taller_reviews_screen.dart';

class TallerDashboardScreen extends StatefulWidget {
  const TallerDashboardScreen({super.key});

  @override
  State<TallerDashboardScreen> createState() => _TallerDashboardScreenState();
}

class _TallerDashboardScreenState extends State<TallerDashboardScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Función para cambiar el estado de Abierto/Cerrado en Firebase
  Future<void> _toggleEstado(bool actual) async {
    await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
      'estado': actual ? 'cerrado' : 'abierto',
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('talleres').doc(_uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error al cargar datos del taller"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          bool estaAbierto = data['estado'] == 'abierto';
          String nombreTaller = data['nombre'] ?? 'Mi Taller';

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Moderno con Saludo Dinámico
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, 👋', style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6))),
                            Text(nombreTaller, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerProfileScreen())),
                        child: CircleAvatar(
                          backgroundColor: colorScheme.primary.withOpacity(0.1),
                          child: Icon(Icons.person_outline, color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // GRID ESTILO BENTO BOX
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildListDelegate([

                    // CAJA 1 (GRANDE/DOBLE): Interruptor de Estado
                    _buildBentoItem(
                      context,
                      isDouble: true,
                      color: estaAbierto ? Colors.green.shade500 : Colors.red.shade500,
                      onTap: () => _toggleEstado(estaAbierto),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(estaAbierto ? Icons.sensors : Icons.sensors_off, size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(estaAbierto ? 'EN LÍNEA' : 'FUERA DE SERVICIO', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(estaAbierto ? 'Visible para conductores' : 'Oculto en el mapa', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),

                    // CAJA 2: Reseñas (Bento Pequeño)
                    _buildBentoItem(
                      context,
                      color: colorScheme.surfaceContainerHighest,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerReviewsScreen())),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, size: 32, color: Colors.amber),
                          const SizedBox(height: 8),
                          Text('4.8', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Reputación', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),

                    // CAJA 3: Vistas (Bento Pequeño)
                    _buildBentoItem(
                      context,
                      color: colorScheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_outlined, size: 32, color: colorScheme.primary),
                          const SizedBox(height: 8),
                          Text('124', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('Visitas hoy', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    ),

                    // CAJA 4 (ANCHA): Métodos de Pago / Configuración rápida
                    _buildBentoItem(
                      context,
                      isDouble: true,
                      color: colorScheme.primary.withOpacity(0.05),
                      border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickAction(Icons.account_balance_wallet_outlined, "Pagos"),
                          _buildQuickAction(Icons.history_outlined, "Historial"),
                          _buildQuickAction(Icons.campaign_outlined, "Promos"),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Creador de piezas Bento
  Widget _buildBentoItem(BuildContext context, {required Widget child, Color? color, bool isDouble = false, VoidCallback? onTap, BoxBorder? border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: border,
        ),
        // Si es doble, el grid lo manejará mediante el delegate
        // pero aquí definimos la estructura interna
        child: child,
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// Para que el Bento funcione bien con piezas dobles en SliverGrid,
// necesitamos un delegate personalizado o ajustar el conteo.
// Por simplicidad en la demo, usaremos un truco visual con Columnas dentro de la Grid.