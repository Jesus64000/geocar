import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NUEVO: Para guardar las fotos
import 'package:image_picker/image_picker.dart'; // NUEVO: Para abrir la cámara/galería
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/welcome_role_screen.dart';

class TallerProfileScreen extends StatefulWidget {
  const TallerProfileScreen({super.key});

  @override
  State<TallerProfileScreen> createState() => _TallerProfileScreenState();
}

class _TallerProfileScreenState extends State<TallerProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  // --- LÓGICA DEL MAPA ---
  LatLng? _ubicacionSeleccionada;
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  // --- LÓGICA DE FOTOS ---
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN PARA SUBIR FOTO ---
  Future<void> _subirFotoFachada() async {
    try {
      // 1. Abrimos la galería
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      // 2. Preparamos el archivo y la ruta en Firebase Storage
      File file = File(image.path);
      String nombreArchivo = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('talleres/$_uid/galeria/$nombreArchivo.jpg');

      // 3. Subimos la imagen
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // 4. Guardamos la URL en Firestore (Array)
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'fotos': FieldValue.arrayUnion([downloadUrl])
      });

      _showSnackBar('¡Foto subida con éxito!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al subir foto: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // --- FUNCIÓN PARA ELIMINAR FOTO ---
  Future<void> _eliminarFoto(String urlFoto) async {
    try {
      // Eliminamos la URL de Firestore
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'fotos': FieldValue.arrayRemove([urlFoto])
      });
      // (Opcional: Se podría eliminar también de Storage usando refFromURL)
      _showSnackBar('Foto eliminada', Colors.orange);
    } catch (e) {
      _showSnackBar('Error al eliminar foto', Colors.redAccent);
    }
  }

  Future<void> _cambiarEstadoOperacion(bool estaAbierto) async {
    try {
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'estado': estaAbierto ? 'abierto' : 'cerrado',
      });
      _showSnackBar(estaAbierto ? 'Tu taller ahora está visible en el mapa' : 'Has cerrado el taller por hoy', estaAbierto ? Colors.green : Colors.orange);
    } catch (e) {
      _showSnackBar('Error al cambiar estado: $e', Colors.redAccent);
    }
  }

  void _showSnackBar(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> datosAActualizar = {
        'nombre': _nombreController.text.trim(),
        'telefono': _telefonoController.text.trim(),
      };

      if (_ubicacionSeleccionada != null) {
        datosAActualizar['position'] = GeoPoint(_ubicacionSeleccionada!.latitude, _ubicacionSeleccionada!.longitude);
      }

      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update(datosAActualizar);

      if (!mounted) return;
      _showSnackBar('¡Perfil actualizado con éxito!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cerrarSesionLimpiamente() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeRoleScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Mi Perfil', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('talleres').doc(_uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          bool estaAbierto = data['estado'] == 'abierto';
          List<dynamic> fotosGaleria = data['fotos'] ?? []; // Extraemos las fotos

          if (_nombreController.text.isEmpty) _nombreController.text = data['nombre'] ?? '';
          if (_telefonoController.text.isEmpty) _telefonoController.text = data['telefono'] ?? '';

          if (_ubicacionSeleccionada == null && data['position'] != null) {
            GeoPoint geo = data['position'];
            _ubicacionSeleccionada = LatLng(geo.latitude, geo.longitude);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildProfileHeader(data['correo'] ?? 'taller@geocar.com', colorScheme),
                const SizedBox(height: 32),

                // --- 1. ESTADO DE OPERACIÓN ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: estaAbierto ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: estaAbierto ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: estaAbierto ? Colors.green : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(estaAbierto ? Icons.door_front_door_outlined : Icons.lock_outline, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(estaAbierto ? 'Taller Abierto' : 'Taller Cerrado', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: estaAbierto ? Colors.green.shade700 : Colors.red.shade700)),
                            Text(estaAbierto ? 'Recibiendo clientes' : 'Oculto en el mapa', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      Switch(
                        value: estaAbierto,
                        activeColor: Colors.green,
                        onChanged: (val) => _cambiarEstadoOperacion(val),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- 2. INFORMACIÓN GENERAL ---
                _buildSettingsSection(
                  title: 'Información General',
                  colorScheme: colorScheme,
                  children: [
                    _buildProfileInput(label: 'Nombre del Taller', controller: _nombreController, icon: Icons.store_outlined, colorScheme: colorScheme),
                    const SizedBox(height: 20),
                    _buildProfileInput(label: 'Teléfono de contacto', controller: _telefonoController, icon: Icons.phone_android_outlined, colorScheme: colorScheme),
                  ],
                ),
                const SizedBox(height: 24),

                // --- 3. GALERÍA DE FOTOS REAL ---
                _buildSettingsSection(
                  title: 'Fotos del Local',
                  colorScheme: colorScheme,
                  children: [
                    Text('Sube fotos de tu fachada para generar confianza.', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // BOTÓN DE AÑADIR FOTO
                          GestureDetector(
                            onTap: _isUploadingPhoto ? null : _subirFotoFachada,
                            child: Container(
                              height: 120, width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
                              ),
                              child: _isUploadingPhoto
                                  ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                  : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: colorScheme.primary, size: 30),
                                  const SizedBox(height: 8),
                                  Text('Añadir', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),

                          // LISTA DE FOTOS SUBIDAS
                          ...fotosGaleria.map((url) => Stack(
                            children: [
                              Container(
                                height: 120, width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  image: DecorationImage(
                                    image: NetworkImage(url),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 16,
                                child: GestureDetector(
                                  onTap: () => _eliminarFoto(url),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              )
                            ],
                          )),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 24),

                // --- 4. MAPA DE UBICACIÓN ---
                _buildSettingsSection(
                  title: 'Ubicación Exacta',
                  colorScheme: colorScheme,
                  children: [
                    Text('Si te mudaste, arrastra el mapa para actualizar tu ubicación.',
                        style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 250,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2),
                      ),
                      child: _ubicacionSeleccionada == null
                          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                          : GoogleMap(
                        initialCameraPosition: CameraPosition(target: _ubicacionSeleccionada!, zoom: 15),
                        onMapCreated: (controller) {
                          if (!_mapController.isCompleted) _mapController.complete(controller);
                        },
                        onTap: (pos) => setState(() => _ubicacionSeleccionada = pos),
                        scrollGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('taller_pos_perfil'),
                            position: _ubicacionSeleccionada!,
                            draggable: true,
                            onDragEnd: (pos) => setState(() => _ubicacionSeleccionada = pos),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          ),
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- 5. ESPECIALIDADES ---
                _buildSettingsSection(
                  title: 'Mis Especialidades',
                  colorScheme: colorScheme,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (data['especialidades'] as List<dynamic>? ?? [])
                          .map((e) => Chip(
                        label: Text(e.toString(), style: GoogleFonts.poppins(fontSize: 12)),
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      )).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // --- 6. BOTONES DE ACCIÓN ---
                _isSaving
                    ? CircularProgressIndicator(color: colorScheme.primary)
                    : ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.surface,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: Text('GUARDAR CAMBIOS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const SizedBox(height: 32),

                TextButton.icon(
                  onPressed: _cerrarSesionLimpiamente,
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  label: Text('Cerrar Sesión', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String email, ColorScheme colorScheme) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2)),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.build_rounded, size: 50, color: colorScheme.primary),
              ),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(email, style: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children, required ColorScheme colorScheme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }

  Widget _buildProfileInput({required String label, required TextEditingController controller, required IconData icon, required ColorScheme colorScheme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: colorScheme.primary.withValues(alpha: 0.8)),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ],
    );
  }
}