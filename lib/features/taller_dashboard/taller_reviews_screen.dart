import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TallerReviewsScreen extends StatelessWidget {
  const TallerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. STREAM BUILDER PARA EL HEADER (Puntaje Global)
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('talleres').doc(uid).snapshots(),
              builder: (context, snapshot) {
                double ratingGlobal = 5.0; // Fallback por defecto

                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  ratingGlobal = (data['rating'] ?? 5.0).toDouble();
                }

                return SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  backgroundColor: colorScheme.surface,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary.withOpacity(0.1),
                            colorScheme.surface,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Text(ratingGlobal.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  letterSpacing: -2
                              )
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) => Icon(
                              Icons.star_rounded,
                              color: index < ratingGlobal.round() ? Colors.amber : Colors.amber.withOpacity(0.3),
                              size: 28,
                            )),
                          ),
                          const SizedBox(height: 8),
                          Text('PROMEDIO DE RESEÑAS',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  letterSpacing: 1.2
                              )
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
          ),

          // 2. STREAM BUILDER PARA LA LISTA DE RESEÑAS (Subcolección)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('talleres')
                .doc(uid)
                .collection('resenas')
                .orderBy('fecha', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.reviews_outlined, size: 60, color: colorScheme.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text("Aún no tienes reseñas", style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }

              var resenas = snapshot.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      var review = resenas[index].data() as Map<String, dynamic>;

                      String nombre = review['nombre_conductor'] ?? 'Conductor Anónimo';
                      String inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';
                      int estrellas = review['estrellas'] ?? 5;
                      String comentario = review['comentario'] ?? 'Sin comentarios.';

                      Timestamp? timestamp = review['fecha'];
                      String fechaStr = 'Reciente';
                      if (timestamp != null) {
                        fechaStr = DateFormat('dd MMM yyyy').format(timestamp.toDate());
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                                      child: Text(inicial,
                                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(fechaStr, style: GoogleFonts.poppins(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.4))),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                      Text(' $estrellas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              comentario,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                  height: 1.5
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: resenas.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}