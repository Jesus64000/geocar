import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'taller_profile_screen.dart';
import 'taller_reviews_screen.dart';
import 'taller_rescue_screen.dart';

class TallerDashboardScreen extends StatefulWidget {
  const TallerDashboardScreen({super.key});

  @override
  State<TallerDashboardScreen> createState() => _TallerDashboardScreenState();
}

class _TallerDashboardScreenState extends State<TallerDashboardScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Función para cambiar el estado de Abierto/Cerrado
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
              // 1. HEADER (SALUDO Y PERFIL)
              SliverAppBar(
                expandedHeight: 100,
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
                            Text('Centro de Mando, 👋', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                            Text(nombreTaller, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerProfileScreen())),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person_rounded, color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      // 2. RADAR SOS EN VIVO (Escucha la colección 'emergencias')
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('emergencias').where('estado', isEqualTo: 'activa').snapshots(),
                        builder: (context, sosSnapshot) {
                          if (!sosSnapshot.hasData || sosSnapshot.data!.docs.isEmpty) {
                            return const SizedBox.shrink(); // No hay emergencias, se oculta
                          }

                          // Si hay emergencias, mostramos la primera
                          var emergencia = sosSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                          String vehiculo = emergencia['vehiculo'] ?? 'Vehículo Desconocido';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(color: Colors.redAccent.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                                ]
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('¡SOS CERCANO!', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(vehiculo, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => TallerRescueScreen(
                                              emergenciaId: sosSnapshot.data!.docs.first.id,
                                            )
                                        )
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Text('VER', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                          );
                        },
                      ),

                      // 3. SWITCH GIGANTE DE ESTADO (BENTO ANCHO)
                      _buildBentoContainer(
                        color: estaAbierto ? Colors.green.shade500 : Colors.red.shade400,
                        onTap: () => _toggleEstado(estaAbierto),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                              child: Icon(estaAbierto ? Icons.radar : Icons.power_settings_new_rounded, size: 40, color: Colors.white),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(estaAbierto ? 'TALLER EN LÍNEA' : 'FUERA DE SERVICIO', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text(estaAbierto ? 'Recibiendo alertas de conductores' : 'Toca para conectarte al mapa', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. MÉTRICAS GEMELAS (BENTO ROW)
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoContainer(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerReviewsScreen())),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star_rounded, size: 36, color: Colors.amber),
                                  const SizedBox(height: 8),
                                  Text('4.8', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
                                  Text('Reputación', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBentoContainer(
                              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.visibility_rounded, size: 36, color: colorScheme.primary),
                                  const SizedBox(height: 8),
                                  Text('124', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
                                  Text('Visitas al Perfil', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. ACCESOS RÁPIDOS (BENTO ANCHO CON COLUMNAS)
                      _buildBentoContainer(
                        color: colorScheme.surface,
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildQuickAction(
                                context,
                                icon: Icons.add_a_photo_rounded,
                                label: "Subir Fotos",
                                color: Colors.blue,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerProfileScreen()))
                            ),
                            _buildQuickAction(
                                context,
                                icon: Icons.reviews_rounded,
                                label: "Reseñas",
                                color: Colors.orange,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TallerReviewsScreen()))
                            ),
                            _buildQuickAction(
                                context,
                                icon: Icons.workspace_premium_rounded,
                                label: "VIP",
                                color: Colors.purple,
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funcionalidad Premium en desarrollo')));
                                }
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- COMPONENTES BENTO MEJORADOS ---

  Widget _buildBentoContainer({required Widget child, Color? color, VoidCallback? onTap, BoxBorder? border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32), // Esquinas bien redondas tipo iOS 18
          border: border,
        ),
        child: child,
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, {required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}