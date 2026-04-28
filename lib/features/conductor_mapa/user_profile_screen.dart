import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/welcome_role_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _nombreController = TextEditingController();

  // --- LÓGICA DEL GARAGE ---
  List<Map<String, dynamic>> _misVehiculos = [];
  // -------------------------

  bool _isLoading = true;
  bool _isSaving = false;

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

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

          // Cargamos la lista de vehículos
          if (data['vehiculos'] != null && data['vehiculos'] is List) {
            _misVehiculos = List<Map<String, dynamic>>.from(data['vehiculos']);
          }
          // MIGRACIÓN: Si el usuario tenía el formato viejo, lo convertimos al nuevo
          else if (data['vehiculo'] != null && data['vehiculo'].toString().isNotEmpty) {
            _misVehiculos = [{
              'marca': 'Mi Vehículo',
              'modelo': data['vehiculo'],
              'año': 'N/A'
            }];
          }

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
    super.dispose();
  }

  void _guardarPerfil() async {
    if (_nombreController.text.isEmpty) {
      _showSnackBar('El nombre no puede estar vacío', Colors.redAccent);
      return;
    }

    if (_misVehiculos.isEmpty) {
      _showSnackBar('Debes tener al menos un vehículo en tu Garage', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .update({
        'nombre': _nombreController.text.trim(),
        'vehiculos': _misVehiculos, // Guardamos el array completo
      });

      if (!mounted) return;
      _showSnackBar('¡Perfil y Garage actualizados!', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error al guardar: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- MODAL PARA AGREGAR VEHÍCULO ---
  void _mostrarDialogoAgregarVehiculo() {
    final marcaController = TextEditingController();
    final modeloController = TextEditingController();
    final anioController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              Text('Nuevo Vehículo', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              _buildModernInput(controller: marcaController, hintText: 'Marca (Ej: Toyota)', icon: Icons.branding_watermark_rounded, colorScheme: Theme.of(context).colorScheme),
              const SizedBox(height: 12),
              _buildModernInput(controller: modeloController, hintText: 'Modelo (Ej: Corolla)', icon: Icons.directions_car_rounded, colorScheme: Theme.of(context).colorScheme),
              const SizedBox(height: 12),
              _buildModernInput(controller: anioController, hintText: 'Año (Ej: 2008)', icon: Icons.calendar_month_rounded, colorScheme: Theme.of(context).colorScheme, isNumber: true),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (marcaController.text.isEmpty || modeloController.text.isEmpty || anioController.text.isEmpty) {
                    _showSnackBar('Llena todos los campos', Colors.redAccent);
                    return;
                  }
                  setState(() {
                    _misVehiculos.add({
                      'marca': marcaController.text.trim(),
                      'modelo': modeloController.text.trim(),
                      'año': anioController.text.trim(),
                    });
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text('AGREGAR AL GARAGE', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
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

                  // BENTO BOX DEL GARAGE
                  _buildBentoBox(
                    colorScheme: colorScheme,
                    title: 'Mi Garage',
                    icon: Icons.garage_rounded,
                    accentColor: colorScheme.secondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Agrega tus vehículos. Cuando pidas auxilio, podrás elegir cuál está fallando.',
                            style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))
                        ),
                        const SizedBox(height: 16),

                        if (_misVehiculos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text('No tienes vehículos registrados.', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                          ),

                        // Lista de Carros
                        ..._misVehiculos.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> vehiculo = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.directions_car_rounded, color: colorScheme.primary),
                              ),
                              title: Text('${vehiculo['marca']} ${vehiculo['modelo']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Año: ${vehiculo['año']}', style: GoogleFonts.poppins(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  setState(() => _misVehiculos.removeAt(index));
                                },
                              ),
                            ),
                          );
                        }),

                        // Botón Añadir
                        Center(
                          child: TextButton.icon(
                            onPressed: _mostrarDialogoAgregarVehiculo,
                            icon: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
                            label: Text('Añadir Vehículo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                          ),
                        )
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

  Widget _buildModernInput({required TextEditingController controller, required String hintText, required IconData icon, required ColorScheme colorScheme, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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