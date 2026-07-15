import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importante
import 'package:geolocator/geolocator.dart'; // Importante
import 'taller_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  // --- LÓGICA DE FOTOS ---
  final ImagePicker _picker = ImagePicker();
  String? _photoUrl;
  final List<String> _fotosGaleria = [];
  bool _isUploadingPerfil = false;
  bool _isUploadingGaleria = false;

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
    final nombreLimpio = _nombreController.text.trim();
    final telefonoLimpio = _telefonoController.text.trim();

    if (nombreLimpio.isEmpty || nombreLimpio.length < 3) {
      _showSnackBar('El nombre del taller debe tener al menos 3 caracteres', Colors.redAccent);
      return;
    }

    final phoneRegExp = RegExp(r'^\+?[0-9\s\-]{7,15}$');
    if (telefonoLimpio.isEmpty || !phoneRegExp.hasMatch(telefonoLimpio)) {
      _showSnackBar('Ingresa un número de teléfono válido (solo números, mínimo 7 dígitos)', Colors.redAccent);
      return;
    }

    if (_serviciosSeleccionados.isEmpty) {
      _showSnackBar('Selecciona al menos un servicio o especialidad', Colors.redAccent);
      return;
    }

    if (_photoUrl == null || _photoUrl!.isEmpty) {
      _showSnackBar('La foto de perfil del taller es obligatoria', Colors.redAccent);
      return;
    }

    if (_fotosGaleria.length < 3) {
      _showSnackBar('Debes subir al menos 3 fotos del local (${_fotosGaleria.length}/3 subidas)', Colors.redAccent);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Guardamos todo en el documento del Taller
        await FirebaseFirestore.instance.collection('talleres').doc(user.uid).set({
          'uid': user.uid,
          'nombre': nombreLimpio,
          'telefono': telefonoLimpio,
          'especialidades': _serviciosSeleccionados,
          'correo': user.email,
          'estado': 'cerrado', // Por defecto inicia cerrado
          'rating': 5.0,       // Rating inicial
          'horarios': {
            'apertura': '08:00',
            'cierre': '17:00',
            'dias_laborales': ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'],
          },
          'photoUrl': _photoUrl,
          'fotos': _fotosGaleria,
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

  Future<void> _subirFotoPerfil() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image == null) return;

      setState(() => _isUploadingPerfil = true);

      File file = File(image.path);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      Reference ref = FirebaseStorage.instance.ref().child('talleres/${user.uid}/perfil.jpg');
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _photoUrl = downloadUrl;
      });
      _showSnackBar('¡Foto de perfil cargada!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al subir foto de perfil: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploadingPerfil = false);
    }
  }

  Future<void> _subirFotoGaleria() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploadingGaleria = true);

      File file = File(image.path);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String nombreArchivo = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('talleres/${user.uid}/galeria/$nombreArchivo.jpg');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _fotosGaleria.add(downloadUrl);
      });
      _showSnackBar('¡Foto añadida a la galería!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al subir foto de galería: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploadingGaleria = false);
    }
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
                              initialCameraPosition: CameraPosition(target: _ubicacionActual, zoom: 15),
                              onMapCreated: (controller) => _mapController.complete(controller),
                              onTap: (LatLng point) => setState(() { _ubicacionActual = point; }),

                              // CONFIGURACIÓN DE GESTOS NATURALES (EFECTO YUMMY)
                              scrollGesturesEnabled: true,
                              zoomGesturesEnabled: true,
                              rotateGesturesEnabled: true,
                              tiltGesturesEnabled: true,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: true,
                              zoomControlsEnabled: false,

                              // ESTA LÍNEA ES LA MAGIA:
                              // Evita que el scroll de la pantalla interfiera con el del mapa
                              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                              },

                              markers: {
                                Marker(
                                  markerId: const MarkerId('taller_pos'),
                                  position: _ubicacionActual,
                                  draggable: true,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                                  onDragEnd: (LatLng point) => setState(() { _ubicacionActual = point; }),
                                ),
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
                  const SizedBox(height: 24),

                  // SECCIÓN 4: FOTOS OBLIGATORIAS (Mínimo 1 perfil, 3 de local)
                  _buildBentoSection(
                    colorScheme: colorScheme,
                    title: 'Fotos Obligatorias',
                    icon: Icons.camera_alt_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto de Perfil / Logo
                        Text('Foto de Perfil o Logotipo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _subirFotoPerfil,
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                  image: _photoUrl != null
                                      ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: _isUploadingPerfil
                                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                    : (_photoUrl == null
                                        ? Icon(Icons.add_a_photo_rounded, color: colorScheme.primary)
                                        : null),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _photoUrl == null
                                    ? 'Toca para subir la foto principal de tu taller (obligatoria)'
                                    : '¡Foto principal cargada correctamente!',
                                style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        // Fotos del local / Galería
                        Text('Fotos de tu Local (Mínimo 3)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Agrega fotos de tu fachada, equipos o instalaciones para generar confianza.', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._fotosGaleria.map((url) => Container(
                                margin: const EdgeInsets.only(right: 12),
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _fotosGaleria.remove(url)),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.redAccent,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              )),
                              if (_fotosGaleria.length < 5)
                                GestureDetector(
                                  onTap: _subirFotoGaleria,
                                  child: Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: _isUploadingGaleria
                                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                        : Icon(Icons.add_photo_alternate_rounded, color: colorScheme.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Fotos subidas: ${_fotosGaleria.length} de 3 requeridas',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _fotosGaleria.length >= 3 ? Colors.green : Colors.orange)),
                      ],
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