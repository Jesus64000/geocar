import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkshopListScreen extends StatefulWidget {
  const WorkshopListScreen({super.key});

  @override
  State<WorkshopListScreen> createState() => _WorkshopListScreenState();
}

class _WorkshopListScreenState extends State<WorkshopListScreen> {
  String _filtroActual = 'Todos';
  final List<String> _categorias = ['Todos', 'Mecánica', 'Frenos', 'Cauchos', 'Electricidad'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Header con Buscador Integrado
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Talleres en Cabimas',
                        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)
                    ),
                    const SizedBox(height: 16),
                    // Buscador Estilo 2026
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          hintStyle: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                          border: InputBorder.none,
                          icon: Icon(Icons.search_rounded, color: colorScheme.primary, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // 2. Filtros Rápidos (Cápsulas Horizontales)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _categorias.length,
                itemBuilder: (context, index) {
                  bool seleccionada = _filtroActual == _categorias[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 12, top: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filtroActual = _categorias[index]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center, // <-- Corregido el parámetro 'center'
                        decoration: BoxDecoration(
                          color: seleccionada ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: seleccionada ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                        ),
                        child: Text(
                          _categorias[index],
                          style: GoogleFonts.poppins(
                            color: seleccionada ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: seleccionada ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 3. Directorio (Lista Bento)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('talleres').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('No hay talleres registrados aún.', style: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      bool estaAbierto = data['estado'] == 'abierto';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            // Aquí iría el detalle del taller
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Icono/Imagen del taller
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(Icons.build_circle_rounded, color: colorScheme.primary, size: 40),
                                ),
                                const SizedBox(width: 16),

                                // Info del Taller
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8, height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: estaAbierto ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(estaAbierto ? 'EN LÍNEA' : 'CERRADO',
                                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: estaAbierto ? Colors.green : Colors.red)
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(data['nombre'] ?? 'Taller sin nombre',
                                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)
                                      ),
                                      Text(
                                        (data['especialidades'] as List? ?? []).join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Flecha de acción
                                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.2)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: docs.length,
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