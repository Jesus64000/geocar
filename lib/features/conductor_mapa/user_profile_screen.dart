import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importante
import '../auth/welcome_role_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // Controladores ahora inician vacíos
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _vehiculoController = TextEditingController();
  bool _isLoading = true; // Iniciamos en true para la carga inicial
  bool _isSaving = false; // Para el estado del botón de guardar

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  // PASO 1: Cargar datos reales de Firestore
  Future<void> _cargarDatosUsuario() async {
    if (_user == null) return;

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _vehiculoController.text = data['vehiculo'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _vehiculoController.dispose();
    super.dispose();
  }

  // PASO 2: Guardado real en la base de datos
  void _guardarPerfil() async {
    if (_nombreController.text.isEmpty) {
      _showSnackBar('El nombre no puede estar vacío', Colors.redAccent);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .update({
        'nombre': _nombreController.text.trim(),
        'vehiculo': _vehiculoController.text.trim(),
      });

      if (!mounted) return;
      _showSnackBar('¡Perfil actualizado correctamente!', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error al guardar: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        )
    );
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeRoleScreen()),
            (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Mi Identidad', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  _buildHeroAvatar(colorScheme),
                  const SizedBox(height: 16),
                  Text(_user?.email ?? 'conductor@geocar.com',
                      style: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 40),

                  _buildBentoBox(
                    colorScheme: colorScheme,
                    title: 'Datos Personales',
                    icon: Icons.person_rounded,
                    child: _buildModernInput(
                        controller: _nombreController,
                        hintText: 'Tu nombre completo',
                        icon: Icons.badge_rounded,
                        colorScheme: colorScheme
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildBentoBox(
                    colorScheme: colorScheme,
                    title: 'Mi Vehículo',
                    icon: Icons.directions_car_rounded,
                    accentColor: colorScheme.secondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('El mecánico verá esto para saber qué reparar.',
                            style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))
                        ),
                        const SizedBox(height: 16),
                        _buildModernInput(
                            controller: _vehiculoController,
                            hintText: 'Ej: Toyota Corolla 2008',
                            icon: Icons.car_repair_rounded,
                            colorScheme: colorScheme
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  _isSaving
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : ElevatedButton(
                    onPressed: _guardarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.surface,
                      minimumSize: const Size(double.infinity, 60),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('GUARDAR CAMBIOS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),

                  const SizedBox(height: 32),

                  TextButton.icon(
                    onPressed: _cerrarSesion,
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
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeroAvatar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primary.withValues(alpha: 0.1),
        ),
        child: CircleAvatar(
          radius: 50,
          backgroundColor: colorScheme.primary,
          child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBentoBox({required ColorScheme colorScheme, required String title, required IconData icon, Color? accentColor, required Widget child}) {
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
              Icon(icon, color: accentColor ?? colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernInput({required TextEditingController controller, required String hintText, required IconData icon, required ColorScheme colorScheme}) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
    );
  }
}