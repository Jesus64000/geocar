import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importante
import 'package:geolocator/geolocator.dart'; // Importante
import 'taller_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TallerSetupScreen extends StatefulWidget {
  const TallerSetupScreen({super.key});

  @override
  State<TallerSetupScreen> createState() => _TallerSetupScreenState();
}

class _TallerSetupScreenState extends State<TallerSetupScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  // --- LÓGICA DE MAPA ---
  LatLng _ubicacionActual = const LatLng(10.3927, -71.4405); // Cabimas por defecto
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  // ----------------------

  final List<String> _serviciosSeleccionados = [];
  final List<String> _serviciosDisponibles = [
    'Mecánica Ligera', 'Tren Delantero', 'Frenos',
    'Electricidad', 'Aire Acondicionado', 'Vulcanizadora (Cauchos)'
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _determinarPosicionInicial();
  }

  // Intenta centrar el mapa en la posición real del mecánico al abrir
  Future<void> _determinarPosicionInicial() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition();
      _moverCamara(LatLng(position.latitude, position.longitude));
    }
  }

  Future<void> _moverCamara(LatLng localizacion) async {
    setState(() { _ubicacionActual = localizacion; });
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(localizacion, 16));
  }

  Future<void> _completarSetup() async {
    // Validación de seguridad: Nombre, Especialidades y Teléfono
    if (_nombreController.text.isEmpty ||
        _serviciosSeleccionados.isEmpty ||
        _telefonoController.text.isEmpty) {
      _showSnackBar('Completa todos los campos y selecciona tus servicios', Colors.redAccent);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Guardamos todo en el documento del Taller
        await FirebaseFirestore.instance.collection('talleres').doc(user.uid).set({
          'uid': user.uid,
          'nombre': _nombreController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'especialidades': _serviciosSeleccionados,
          'correo': user.email,
          'estado': 'cerrado', // Por defecto inicia cerrado
          'rating': 5.0,       // Rating inicial
          'horarios': {
            'apertura': '08:00',
            'cierre': '17:00',
            'dias_laborales': ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'],
          },
          // ESTO ES EL PUNTO 2: El GeoPoint con la ubicación del mapa
          'position': GeoPoint(_ubicacionActual.latitude, _ubicacionActual.longitude),

          'fecha_registro': FieldValue.serverTimestamp(),
          'rol': 'taller',
        });

        // IMPORTANTE: También guardamos el rol en SharedPreferences para la persistencia local
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'taller');

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TallerDashboardScreen()));
      }
    } catch (e) {
      _showSnackBar('Error al guardar: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: GoogleFonts.poppins()), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                title: Text('Configura tu Taller', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 22)),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('Marca la ubicación exacta de tu local para que los conductores puedan llegar.',
                      style: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)
                  ),
                  const SizedBox(height: 32),

                  // SECCIÓN 1: MAPA INTERACTIVO (Reemplaza la Caja Bento 3 antigua)
                  _buildBentoSection(
                    colorScheme: colorScheme,
                    title: 'Ubicación Exacta',
                    icon: Icons.location_on_rounded,
                    child: Column(
                      children: [
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(target: _ubicacionActual, zoom: 14),
                              onMapCreated: (controller) => _mapController.complete(controller),
                              onTap: (LatLng point) => setState(() { _ubicacionActual = point; }),
                              scrollGesturesEnabled: true, // Permite mover el mapa con el dedo
                              zoomGesturesEnabled: true,   // Permite hacer zoom
                              myLocationEnabled: true,     // Muestra el punto azul de donde estás
                              myLocationButtonEnabled: true, // Botón para volver a tu posición real
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              markers: {
                                Marker(
                                  markerId: const MarkerId('taller_pos'),
                                  position: _ubicacionActual,
                                  draggable: true, // Permite arrastrar el pin
                                  onDragEnd: (LatLng point) => setState(() { _ubicacionActual = point; }),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),),
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                            Text('Mueve el mapa y toca donde está tu local exactamente',
                              style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.w500)
                           ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECCIÓN 2: Datos Básicos
                  _buildBentoSection(
                    colorScheme: colorScheme,
                    title: 'Datos del Negocio',
                    icon: Icons.storefront_rounded,
                    child: Column(
                      children: [
                        _buildModernInput(controller: _nombreController, hintText: 'Nombre del Taller', icon: Icons.badge_rounded, colorScheme: colorScheme),
                        const SizedBox(height: 16),
                        _buildModernInput(controller: _telefonoController, hintText: 'Teléfono (WhatsApp)', icon: Icons.phone_rounded, colorScheme: colorScheme, isNumber: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECCIÓN 3: Especialidades
                  _buildBentoSection(
                    colorScheme: colorScheme,
                    title: 'Tus Especialidades',
                    icon: Icons.build_rounded,
                    child: Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: _serviciosDisponibles.map((servicio) {
                        final isSelected = _serviciosSeleccionados.contains(servicio);
                        return FilterChip(
                          label: Text(servicio, style: GoogleFonts.poppins(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() { selected ? _serviciosSeleccionados.add(servicio) : _serviciosSeleccionados.remove(servicio); });
                          },
                          backgroundColor: colorScheme.surface,
                          selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                          checkmarkColor: colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: isSelected ? colorScheme.primary : Colors.transparent, width: 1.5),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),

                  _isLoading
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : ElevatedButton(
                    onPressed: _completarSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('ABRIR MI TALLER', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoSection({required ColorScheme colorScheme, required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernInput({required TextEditingController controller, required String hintText, required IconData icon, required ColorScheme colorScheme, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: GoogleFonts.poppins(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: colorScheme.primary.withValues(alpha: 0.5), size: 20),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}