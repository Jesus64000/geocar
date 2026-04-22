import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TallerReviewsScreen extends StatelessWidget {
  const TallerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Header Estilo Vidrio / Moderno
          SliverAppBar(
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
                    Text('4.8',
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
                        color: index < 4 ? Colors.amber : Colors.amber.withOpacity(0.3),
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
          ),

          // 2. Lista de Reseñas (Bento Style)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  // Datos mockeados con estilo 2026 (En el futuro vendrán de un StreamBuilder)
                  final reviews = [
                    {"nombre": "Carlos R.", "comentario": "Excelente atención en la Intercomunal. Pago móvil rápido.", "estrellas": 5, "fecha": "Hoy"},
                    {"nombre": "María P.", "comentario": "Buen servicio de frenos, aunque mucha gente.", "estrellas": 4, "fecha": "Ayer"},
                    {"nombre": "José V.", "comentario": "Honesto con los repuestos. Volveré.", "estrellas": 5, "fecha": "Hace 1 sem."},
                  ];

                  final review = reviews[index % reviews.length];

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
                                  child: Text(review["nombre"].toString()[0],
                                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review["nombre"].toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(review["fecha"].toString(), style: GoogleFonts.poppins(fontSize: 11, color: colorScheme.onSurface.withOpacity(0.4))),
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
                                  Text(' ${review["estrellas"]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          review["comentario"].toString(),
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
                childCount: 6, // Simulamos varias reseñas
              ),
            ),
          ),
        ],
      ),
    );
  }
}