import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // Para el tema

class TallerProfileScreen extends StatefulWidget {
  const TallerProfileScreen({super.key});

  @override
  State<TallerProfileScreen> createState() => _TallerProfileScreenState();
}

class _TallerProfileScreenState extends State<TallerProfileScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('talleres').doc(_uid).update({
        'nombre': _nombreController.text.trim(),
        'telefono': _telefonoController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado con éxito'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          // Cargamos los datos iniciales en los controladores si están vacíos
          if (_nombreController.text.isEmpty) _nombreController.text = data['nombre'] ?? '';
          if (_telefonoController.text.isEmpty) _telefonoController.text = data['telefono'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Header con Avatar y Correo
                _buildProfileHeader(data['correo'] ?? 'taller@geocar.com', colorScheme),
                const SizedBox(height: 40),

                // 2. Bloque de Información General (Bento Style)
                _buildSettingsSection(
                  title: 'Información General',
                  colorScheme: colorScheme,
                  children: [
                    _buildProfileInput(
                      label: 'Nombre del Taller',
                      controller: _nombreController,
                      icon: Icons.store_outlined,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 20),
                    _buildProfileInput(
                      label: 'Teléfono de contacto',
                      controller: _telefonoController,
                      icon: Icons.phone_android_outlined,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Bloque de Especialidades (Lectura)
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
                        backgroundColor: colorScheme.primary.withOpacity(0.05),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ))
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // 4. Botón de Acción Principal
                _isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: Text('GUARDAR CAMBIOS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),

                // 5. Cerrar Sesión (Sutil)
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  label: Text('Cerrar Sesión', style: GoogleFonts.poppins(color: Colors.redAccent)),
                ),
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
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 2)),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
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
        Text(email, style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.5))),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildProfileInput({required String label, required TextEditingController controller, required IconData icon, required ColorScheme colorScheme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: colorScheme.primary),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}