import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORTANTE: Ajusta estas rutas según tu estructura de carpetas real
import '../taller_dashboard/taller_rescue_screen.dart';
import '../../widgets/chat/universal_chat_sheet.dart';

class WorkshopDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tallerId;

  const WorkshopDetailScreen({super.key, required this.data, required this.tallerId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool estaAbierto = data['estado'] == 'abierto';
    double rating = (data['rating'] ?? 5.0).toDouble();
    List fotos = data['fotos'] ?? [];
    List especialidades = data['especialidades'] ?? [];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // FOTO DE PORTADA EXPANDIBLE
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: CircleAvatar(
                backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: fotos.isNotEmpty
                  ? Image.network(fotos.first, fit: BoxFit.cover)
                  : Container(
                color: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.build_circle_rounded, size: 100, color: colorScheme.primary.withValues(alpha: 0.3)),
              ),
            ),
          ),

          // CONTENIDO DEL PERFIL
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA (Nombre y Estado)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['nombre'] ?? 'Taller sin nombre', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, height: 1.1)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                const SizedBox(width: 4),
                                Text('Cabimas, Zulia', style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                              ],
                            )
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: estaAbierto ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: estaAbierto ? Colors.green.shade300 : Colors.red.shade300),
                        ),
                        child: Text(estaAbierto ? 'ABIERTO' : 'CERRADO', style: GoogleFonts.poppins(color: estaAbierto ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // MÉTRICAS RAPIDAS (BENTO)
                  Row(
                    children: [
                      _buildInfoCaja(Icons.star_rounded, rating.toStringAsFixed(1), 'Reputación', Colors.amber, colorScheme),
                      const SizedBox(width: 12),
                      _buildInfoCaja(Icons.verified_rounded, 'Sí', 'Verificado', Colors.blue, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ESPECIALIDADES
                  Text('Especialidades', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: especialidades.map((e) => Chip(
                      label: Text(e.toString(), style: GoogleFonts.poppins(fontSize: 13)),
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    )).toList(),
                  ),
                  const SizedBox(height: 40),

                  // BOTONES DE ACCIÓN (Chat In-App y Ruta In-App)
                  Row(
                    children: [
                      // BOTÓN DE CHAT IN-APP (Reemplaza al WhatsApp directo)
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Sacamos el UID del conductor para armar la sala de chat única
                            final String miUid = FirebaseAuth.instance.currentUser?.uid ?? 'conductor_anonimo';

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                child: UniversalChatSheet(
                                  modo: ChatMode.directo,
                                  referenceId: '${tallerId}_$miUid', // ID combinado para sala única
                                  tallerPhone: data['telefono'] ?? '',
                                  miRol: 'conductor',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: Text('CONTACTAR', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary, // Cambiado a color primario para denotar acción In-App
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // BOTÓN DE NAVEGACIÓN
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () {
                            GeoPoint? pos = data['position'];
                            if (pos != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TallerRescueScreen(
                                    emergenciaId: "DIRECTORIO",
                                    destinoManual: LatLng(pos.latitude, pos.longitude),
                                    nombreDestino: data['nombre'],
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación no disponible')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.navigation_rounded, size: 28),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCaja(IconData icon, String value, String label, Color iconColor, ColorScheme colorScheme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            )
          ],
        ),
      ),
    );
  }
}