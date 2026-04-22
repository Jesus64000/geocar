import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante para el Stream
import 'workshop_list_screen.dart';
import 'user_profile_screen.dart';
import 'package:geolocator/geolocator.dart'; // Para Position y Geolocator

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  LatLng? _miPosicionActual;
  bool _estaCargandoMapa = true;

  @override
  void initState() {
    super.initState();
    _obtenerUbicacionActual();
  }

  Future<void> _obtenerUbicacionActual() async {
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _miPosicionActual = LatLng(position.latitude, position.longitude);
      _estaCargandoMapa = false;
    });
  }

  String _calcularDistanciaReal(GeoPoint tallerPos) {
    if (_miPosicionActual == null) return "-- km";
    double distanciaEnMetros = Geolocator.distanceBetween(
      _miPosicionActual!.latitude,
      _miPosicionActual!.longitude,
      tallerPos.latitude,
      tallerPos.longitude,
    );
    return (distanciaEnMetros / 1000).toStringAsFixed(1) + " km";
  }

  // Coordenadas de Cabimas
  static const LatLng _centerCabimas = LatLng(10.3927, -71.4405);

  // Filtro para ocultar negocios y locales genéricos de Google
  final String _mapStyleLimpio = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [ { "visibility": "off" } ]
    },
    {
      "featureType": "transit",
      "elementType": "labels",
      "stylers": [ { "visibility": "off" } ]
    }
  ]
  ''';

  // Función para crear marcadores dinámicos desde Firestore
  Marker _crearMarcadorReal(String id, Map<String, dynamic> data, ColorScheme colorScheme) {
    GeoPoint pos = data['position']; // El campo que definimos en el setup
    bool estaAbierto = data['estado'] == 'abierto';

    return Marker(
      markerId: MarkerId(id),
      position: LatLng(pos.latitude, pos.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        estaAbierto ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
      ),
      onTap: () => _mostrarDetalleTaller(
          context,
          data['nombre'] ?? 'Taller',
          _calcularDistanciaReal(pos), // DISTANCIA REAL CALCULADA
          estaAbierto,
          colorScheme
      ),
    );
  }

  void _mostrarDetalleTaller(BuildContext context, String nombre, String especialidades, bool abierto, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 50, height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                )
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: abierto ? Colors.green : Colors.grey),
                          const SizedBox(width: 4),
                          Text('Sector Delicias • Cabimas', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: abierto ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: abierto ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Text(abierto ? 'ABIERTO' : 'CERRADO', style: GoogleFonts.poppins(color: abierto ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildMiniBento(Icons.star_rounded, 'Nuevo', 'Rating', Colors.amber, colorScheme),
                const SizedBox(width: 12),
                _buildMiniBento(Icons.location_on_outlined, especialidades, 'Distancia', colorScheme.primary, colorScheme),
                const SizedBox(width: 12),
                _buildMiniBento(Icons.verified_user_outlined, 'Sí', 'Verificado', Colors.blue, colorScheme),
              ],
            ),
            const SizedBox(height: 24),

            Text(especialidades, style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {}, // Aquí iría Google Maps externo
                    icon: const Icon(Icons.directions_car_rounded),
                    label: Text('VER RUTA', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.surface,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {}, // Aquí conectaremos el WhatsApp
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, size: 28),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBento(IconData icon, String value, String label, Color accentColor, ColorScheme colorScheme) {
    return Expanded(
      child: Container(
        // Altura mínima para que todos los cuadros Bento se vean alineados
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Color de fondo sutil (Efecto Bento 2026)
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icono con color de acento dinámico
            Icon(icon, color: accentColor, size: 22),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Aquí se mostrará la distancia real (ej: "2.5 km")
                Text(
                    value,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: colorScheme.onSurface
                    )
                ),
                // Etiqueta (ej: "Distancia" o "Rating")
                Text(
                    label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.5
                    )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _estaCargandoMapa
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text("Sincronizando satélites...", style: GoogleFonts.poppins())
        ],
      ))
          : Stack(
        children: [
          // STREAM DE FIRESTORE: El mapa ahora es dinámico
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('talleres').snapshots(),
            builder: (context, snapshot) {
              Set<Marker> marcadoresDinamicos = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Solo dibujamos si tiene posición válida
                  if (data.containsKey('position') && data['position'] is GeoPoint) {
                    marcadoresDinamicos.add(_crearMarcadorReal(doc.id, data, colorScheme));
                  }
                }
              }

              return GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _centerCabimas,
                  zoom: 14.5,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController.complete(controller);
                  controller.setMapStyle(_mapStyleLimpio);
                },
                markers: marcadoresDinamicos,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              );
            },
          ),

          // INTERFAZ DE BÚSQUEDA (GLASSMORPHYSM)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                          ),
                          child: TextField(
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              hintText: 'Hola, ¿qué necesita tu carro hoy?',
                              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                              border: InputBorder.none,
                              icon: Icon(Icons.search_rounded, color: colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.primary, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primary,
                        child: const Icon(Icons.person_rounded, color: Colors.white),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),

          // BOTÓN DIRECTORIO FLOTANTE
          Positioned(
            bottom: 110, right: 24,
            child: FloatingActionButton(
              heroTag: 'sos_btn',
              onPressed: () {
                _showSnackBar("Buscando talleres mecánicos cerca de ti...", Colors.orange);
                // Aquí luego programaremos la alerta masiva a los talleres
              },
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.sos_rounded, color: Colors.white, size: 30),
            ),
          ),

          Positioned(
            bottom: 40, right: 24,
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkshopListScreen())),
              backgroundColor: colorScheme.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(Icons.format_list_bulleted, color: colorScheme.primary),
              label: Text('Directorio', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}