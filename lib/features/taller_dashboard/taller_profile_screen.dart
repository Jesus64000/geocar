import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_screen.dart';
import '../../main.dart';

class TallerProfileScreen extends StatefulWidget {
  const TallerProfileScreen({super.key});

  @override
  State<TallerProfileScreen> createState() => _TallerProfileScreenState();
}

class _TallerProfileScreenState extends State<TallerProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  LatLng? _ubicacionSeleccionada;
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  // --- MOTORES DE FOTOS ---
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingGaleria = false;
  bool _isUploadingPerfil = false; // Nuevo estado para el avatar
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  // 1. MOTOR: FOTO DE PERFIL PRINCIPAL
  Future<void> _subirFotoPerfil() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
      if (image == null) return;

      setState(() => _isUploadingPerfil = true);

      File file = File(image.path);
      // Guardamos la foto siempre con el mismo nombre para que se sobreescriba y no gastar espacio
      Reference ref = FirebaseStorage.instance.ref().child('talleres/$_uid/perfil.jpg');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Guardamos el campo 'photoUrl' (string único)
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'photoUrl': downloadUrl
      });

      _showSnackBar('¡Foto de perfil actualizada!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al subir perfil: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploadingPerfil = false);
    }
  }

  // 2. MOTOR: FOTOS DE LA GALERÍA (FACHADA)
  Future<void> _subirFotoFachada() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      setState(() => _isUploadingGaleria = true);

      File file = File(image.path);
      String nombreArchivo = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('talleres/$_uid/galeria/$nombreArchivo.jpg');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Guardamos en el Array 'fotos'
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'fotos': FieldValue.arrayUnion([downloadUrl])
      });

      _showSnackBar('¡Foto añadida a la galería!', Colors.green);
    } catch (e) {
      _showSnackBar('Error al subir foto: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isUploadingGaleria = false);
    }
  }

  Future<void> _eliminarFotoGaleria(String urlFoto) async {
    try {
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'fotos': FieldValue.arrayRemove([urlFoto])
      });
      _showSnackBar('Foto eliminada', Colors.orange);
    } catch (e) {
      _showSnackBar('Error al eliminar foto', Colors.redAccent);
    }
  }

  Future<void> _cambiarEstadoOperacion(bool estaAbierto) async {
    try {
      if (estaAbierto) {
        final doc = await FirebaseFirestore.instance.collection('talleres').doc(_uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final String? photoUrl = data['photoUrl'];
          final List<dynamic> fotos = data['fotos'] ?? [];

          if (photoUrl == null || photoUrl.isEmpty || fotos.length < 3) {
            _showSnackBar(
              'Para abrir tu taller, debes subir tu foto de perfil y al menos 3 fotos de tu local.',
              Colors.redAccent,
            );
            return;
          }
        }
      }

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

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic> datosAActualizar = {
        'nombre': nombreLimpio,
        'telefono': telefonoLimpio,
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
    await prefs.remove('last_role_is_taller'); // Limpiamos la memoria

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen(isTaller: false)),
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
          List<dynamic> fotosGaleria = data['fotos'] ?? [];
          String? fotoPerfilUrl = data['photoUrl']; // Extraemos la foto de perfil

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
                _buildProfileHeader(data['correo'] ?? 'taller@geocar.com', fotoPerfilUrl, colorScheme),
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

                // --- 1.2 AJUSTES VISUALES ---
                _buildSettingsSection(
                  title: 'Ajustes Visuales',
                  colorScheme: colorScheme,
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, _) {
                        bool isDark = currentMode == ThemeMode.dark;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isDark ? 'Modo Oscuro Activo' : 'Modo Claro Activo',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            'Alterna el aspecto visual de toda la app.',
                            style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          value: isDark,
                          activeColor: colorScheme.primary,
                          onChanged: (bool value) async {
                            final nuevoModo = value ? ThemeMode.dark : ThemeMode.light;
                            themeNotifier.value = nuevoModo;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('theme_mode', nuevoModo == ThemeMode.dark ? 'dark' : 'light');
                          },
                          secondary: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? Colors.amber : colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ],
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
                    Text('Sube fotos de tu fachada o trabajos para generar confianza.', style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 16),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // BOTÓN DE AÑADIR FOTO
                          GestureDetector(
                            onTap: _isUploadingGaleria ? null : _subirFotoFachada,
                            child: Container(
                              height: 120, width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
                              ),
                              child: _isUploadingGaleria
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
                                  onTap: () => _eliminarFotoGaleria(url),
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

  // HEADER DINÁMICO (Avatar clickeable para subir foto)
  Widget _buildProfileHeader(String email, String? fotoUrl, ColorScheme colorScheme) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploadingPerfil ? null : _subirFotoPerfil,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2)),
                child: _isUploadingPerfil
                    ? CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
                    : CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                  child: fotoUrl == null ? Icon(Icons.build_rounded, size: 50, color: colorScheme.primary) : null,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary,
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ],
          ),
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