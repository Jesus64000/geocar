import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkshopDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tallerId;

  const WorkshopDetailScreen({super.key, required this.data, required this.tallerId});

  Future<void> _abrirWhatsApp(BuildContext context, String? phone, String? name) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Número no disponible')));
      return;
    }
    String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanedPhone.startsWith('58')) cleanedPhone = '58$cleanedPhone';

    var message = "Hola $name, vi tu perfil en Geocar y necesito ayuda con mi vehículo.";
    var url = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirRutaExterna(BuildContext context, GeoPoint? pos) async {
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación no disponible'))
      );
      return;
    }

    // CORRECCIÓN: Se agregó el '$' antes de la llave
    final String googleMapsUrl = "https://www.google.com/maps/dir/?api=1&destination=${pos.latitude},${pos.longitude}&travelmode=driving";

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el mapa'))
        );
      }
    }
  }

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

                  // BOTONES DE ACCIÓN (WhatsApp y Ruta)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _abrirWhatsApp(context, data['telefono'], data['nombre']),
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: Text('CONTACTAR', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          onPressed: () => _abrirRutaExterna(context, data['position']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                          ),
                          child: const Icon(Icons.directions_rounded, size: 28),
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