import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Importa las herramientas necesarias (Ajusta las rutas a tu proyecto)
import '../../widgets/chat/universal_chat_sheet.dart';
import 'driver_review_modal.dart'; // <-- NUESTRO NUEVO MOTOR DE RESEÑAS

class DriverActiveRescueScreen extends StatefulWidget {
  final String emergenciaId;

  const DriverActiveRescueScreen({super.key, required this.emergenciaId});

  @override
  State<DriverActiveRescueScreen> createState() => _DriverActiveRescueScreenState();
}

class _DriverActiveRescueScreenState extends State<DriverActiveRescueScreen> {
  StreamSubscription<DocumentSnapshot>? _emergenciaSub;
  bool _modalAbierto = false;

  @override
  void initState() {
    super.initState();
    _iniciarEscuchaEventosBaseDeDatos();
  }

  // EL MOTOR DE EVENTOS EN BACKGROUND (Clean Architecture)
  void _iniciarEscuchaEventosBaseDeDatos() {
    _emergenciaSub = FirebaseFirestore.instance
        .collection('emergencias')
        .doc(widget.emergenciaId)
        .snapshots()
        .listen((snapshot) {

      if (!snapshot.exists) return;

      var data = snapshot.data() as Map<String, dynamic>;
      String estado = data['estado'] ?? '';

      // EVENTO A: El taller finalizó el trabajo
      if (estado == 'finalizada' && !_modalAbierto) {
        _modalAbierto = true;
        _mostrarModalCalificacion(data['taller_id']);
      }
      // EVENTO B: Se canceló la emergencia
      else if (estado == 'cancelada') {
        _emergenciaSub?.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _emergenciaSub?.cancel(); // Evita fugas de memoria
    super.dispose();
  }

  // EL GATILLO DEL MODAL
  void _mostrarModalCalificacion(String tallerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // El usuario no puede cerrarlo tocando afuera
      enableDrag: false, // El usuario no puede cerrarlo arrastrando hacia abajo
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: false, // Bloquea el botón físico de "Atrás" de Android
        child: DriverReviewModal(
          tallerId: tallerId,
          emergenciaId: widget.emergenciaId,
        ),
      ),
    ).then((_) {
      // Cuando el modal termine su trabajo y se cierre solo, devolvemos al conductor al mapa
      _emergenciaSub?.cancel();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false, // Bloquea volver atrás por accidente durante un rescate activo
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text("Rescate en Curso", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Center(child: CircularProgressIndicator());

            bool estaEnCamino = data['estado'] == 'en_camino';
            bool estaFinalizada = data['estado'] == 'finalizada';

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ANIMACIÓN / ESTADO VISUAL
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: estaFinalizada
                          ? Colors.blue.withValues(alpha: 0.1)
                          : (estaEnCamino ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
                    ),
                    child: Icon(
                      estaFinalizada
                          ? Icons.stars_rounded
                          : (estaEnCamino ? Icons.check_circle_outline_rounded : Icons.radar_rounded),
                      size: 80,
                      color: estaFinalizada ? Colors.blue : (estaEnCamino ? Colors.green : Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // TEXTO DE ESTADO
                  Text(
                    estaFinalizada
                        ? "Misión Cumplida"
                        : (estaEnCamino ? "¡Taller en Camino!" : "Buscando Talleres..."),
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    estaFinalizada
                        ? "Por favor, evalúa el servicio del mecánico."
                        : (estaEnCamino
                        ? "Un mecánico ha aceptado tu solicitud y se dirige a tu ubicación."
                        : "Estamos alertando a los mecánicos disponibles en un radio cercano."),
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // ZONA DINÁMICA: Mostrar INFO DEL TALLER Y CHAT solo si ya aceptaron y no han terminado
                  if (estaEnCamino) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.build_circle_rounded, size: 40, color: Colors.blue),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Taller Asignado", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                Text(data['taller_nombre'] ?? 'Taller de Geocar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // EL GATILLO DEL CHAT
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: UniversalChatSheet(
                                modo: ChatMode.sos,
                                referenceId: widget.emergenciaId,
                                tallerPhone: data['taller_telefono'] ?? '',
                                miRol: 'conductor',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: Text("ABRIR CHAT DE RESCATE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // TODO: Botón de Cancelar (Sprint 19)
                  if (!estaFinalizada)
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Función de cancelación en desarrollo...")));
                      },
                      child: Text("Cancelar Solicitud", style: GoogleFonts.poppins(color: Colors.grey, decoration: TextDecoration.underline)),
                    )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}