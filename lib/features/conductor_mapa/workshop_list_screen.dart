import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // PAQUETE WHATSAPP
import 'workshop_detail_screen.dart';
import '../../widgets/shimmer_loading.dart';

class WorkshopListScreen extends StatefulWidget {
  const WorkshopListScreen({super.key});

  @override
  State<WorkshopListScreen> createState() => _WorkshopListScreenState();
}

class _WorkshopListScreenState extends State<WorkshopListScreen> {
  // --- VARIABLES DE ESTADO PARA FILTROS ---
  String _filtroActual = 'Todos';
  String _searchQuery = '';
  bool _soloAbiertos = false; // El filtro "Abierto Ahora"

  final List<String> _categorias = [
    'Todos', 'Mecánica Ligera', 'Tren Delantero', 'Frenos',
    'Electricidad', 'Aire Acondicionado', 'Vulcanizadora (Cauchos)'
  ];

  // --- FUNCIÓN WHATSAPP DIRECTO ---
  Future<void> _abrirWhatsApp(String? phone, String? name) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar("El taller no registró número");
      return;
    }
    String cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanedPhone.startsWith('58')) cleanedPhone = '58$cleanedPhone';

    var message = "Hola $name, vi tu taller en el directorio de Geocar.";
    var url = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("No se pudo abrir WhatsApp");
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. HEADER Y BUSCADOR
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
                    Text('Directorio Geocar',
                        style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)
                    ),
                    const SizedBox(height: 16),
                    // Buscador Funcional
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Buscar taller por nombre...',
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

          // 2. FILTRO "ABIERTO AHORA" Y CATEGORÍAS
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Switch Abierto Ahora
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, color: _soloAbiertos ? Colors.green : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text('Mostrar solo abiertos ahora', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _soloAbiertos ? Colors.green.shade700 : colorScheme.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                      Switch(
                        value: _soloAbiertos,
                        activeColor: Colors.green,
                        onChanged: (val) => setState(() => _soloAbiertos = val),
                      ),
                    ],
                  ),
                ),

                // Cápsulas de Categorías
                SizedBox(
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
                            alignment: Alignment.center,
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
              ],
            ),
          ),

          // 3. LISTA DE TALLERES (CON FILTROS APLICADOS)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('talleres').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSliverShimmerList(colorScheme);
              }

              // APLICAMOS LOS 3 FILTROS (Búsqueda, Categoría, Abierto)
              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                // 1. Filtro de Búsqueda de Texto
                final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                if (_searchQuery.isNotEmpty && !nombre.contains(_searchQuery)) return false;

                // 2. Filtro de Categoría
                if (_filtroActual != 'Todos') {
                  final especialidades = data['especialidades'] as List? ?? [];
                  if (!especialidades.contains(_filtroActual)) return false;
                }

                // 3. Filtro Abierto Ahora
                if (_soloAbiertos && data['estado'] != 'abierto') return false;

                return true;
              }).toList();

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 60, color: colorScheme.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text('No se encontraron talleres con esos filtros.', style: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      bool estaAbierto = data['estado'] == 'abierto';
                      double rating = (data['rating'] ?? 5.0).toDouble(); // RATING
                      List fotos = data['fotos'] ?? []; // GALERÍA

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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkshopDetailScreen(
                                    data: data,           // Pasamos los datos del taller
                                    tallerId: docs[index].id, // Pasamos el ID del documento
                                  ),
                                ),
                              );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // FOTO DEL TALLER O ICONO POR DEFECTO
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty)
                                      ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(data['photoUrl'], fit: BoxFit.cover)
                                  )
                                      : fotos.isNotEmpty
                                      ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(fotos.first, fit: BoxFit.cover)
                                  )
                                      : Icon(Icons.build_circle_rounded, color: colorScheme.primary, size: 40),
                                ),
                                const SizedBox(width: 16),

                                // INFO DEL TALLER
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
                                          const SizedBox(width: 6),
                                          Text(estaAbierto ? 'EN LÍNEA' : 'CERRADO', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: estaAbierto ? Colors.green : Colors.red)),

                                          const Spacer(),

                                          // RATING (ESTRELLAS)
                                          Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 14),
                                          const SizedBox(width: 4),
                                          Text(rating.toStringAsFixed(1), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(data['nombre'] ?? 'Taller sin nombre',
                                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, height: 1.1)
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (data['especialidades'] as List? ?? []).join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                                      ),
                                    ],
                                  ),
                                ),

                                // BOTÓN WHATSAPP RÁPIDO
                                IconButton(
                                  onPressed: () => _abrirWhatsApp(data['telefono'], data['nombre']),
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.green, size: 20),
                                  ),
                                )
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

  Widget _buildSliverShimmerList(ColorScheme colorScheme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  ShimmerLoading.rounded(width: 80, height: 80, borderRadius: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerLoading.rounded(width: 150, height: 18, borderRadius: 8),
                        const SizedBox(height: 10),
                        ShimmerLoading.rounded(width: 100, height: 14, borderRadius: 6),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ShimmerLoading.rounded(width: 50, height: 14, borderRadius: 6),
                            const SizedBox(width: 12),
                            ShimmerLoading.rounded(width: 40, height: 14, borderRadius: 6),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          childCount: 3,
        ),
      ),
    );
  }
}