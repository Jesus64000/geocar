import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverReviewModal extends StatefulWidget {
  final String tallerId;
  final String emergenciaId;

  const DriverReviewModal({
    super.key,
    required this.tallerId,
    required this.emergenciaId,
  });

  @override
  State<DriverReviewModal> createState() => _DriverReviewModalState();
}

class _DriverReviewModalState extends State<DriverReviewModal> {
  final TextEditingController _comentarioController = TextEditingController();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  int _rating = 5;
  bool _isSubmitting = false;

  Future<void> _enviarResena() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una puntuación.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Obtener nombre del conductor
      final conductorDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_uid).get();
      final nombreConductor = conductorDoc.data()?['nombre'] ?? 'Conductor Anónimo';

      // 2. Escribir en la subcolección de reseñas del taller
      await FirebaseFirestore.instance
          .collection('talleres')
          .doc(widget.tallerId)
          .collection('resenas')
          .add({
        'conductor_id': _uid,
        'nombre_conductor': nombreConductor,
        'estrellas': _rating,
        'comentario': _comentarioController.text.trim(),
        'fecha': FieldValue.serverTimestamp(),
      });

      // 3. RECALCULAR EL PROMEDIO GLOBAL
      final resenasSnapshot = await FirebaseFirestore.instance
          .collection('talleres')
          .doc(widget.tallerId)
          .collection('resenas')
          .get();

      double totalEstrellas = 0;
      for (var doc in resenasSnapshot.docs) {
        totalEstrellas += (doc.data()['estrellas'] ?? 5) as int;
      }

      double nuevoPromedio = totalEstrellas / resenasSnapshot.docs.length;

      // Actualizar el documento principal del taller
      await FirebaseFirestore.instance.collection('talleres').doc(widget.tallerId).update({
        'rating': double.parse(nuevoPromedio.toStringAsFixed(1)),
      });

      // 4. Cerrar el ciclo de la emergencia
      await FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).update({
        'estado': 'calificada'
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias! Tu reseña ayuda a toda la comunidad.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 5,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 24),

          Text('¿Qué tal el servicio?', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Califica al mecánico para ayudar a otros', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),

          // Selector de 5 Estrellas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                iconSize: 40,
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: index < _rating ? Colors.amber : Colors.grey.shade300,
                ),
                onPressed: () {
                  setState(() => _rating = index + 1);
                },
              );
            }),
          ),
          const SizedBox(height: 20),

          // Input del Comentario
          TextField(
            controller: _comentarioController,
            maxLines: 3,
            maxLength: 150,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              hintText: 'Ej. "Excelente atención, muy rápido y honesto..."',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

          // Botón de Envío
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _enviarResena,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('ENVIAR RESEÑA', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}