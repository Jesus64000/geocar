import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // Para el botón de modo oscuro
import '../taller_dashboard/taller_dashboard_screen.dart';
import '../taller_dashboard/taller_setup_screen.dart';
import 'forgot_password_screen.dart';
import '../conductor_mapa/home_map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthScreen extends StatefulWidget {
  final bool isTaller;

  const AuthScreen({super.key, required this.isTaller});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  Future<void> _submitAuth() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );
      } else {
        userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        // --- AQUÍ ARREGLAMOS LO DE FIRESTORE PARA CONDUCTORES ---
        if (!widget.isTaller) {
          await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'correo': _emailController.text.trim(),
            'rol': 'conductor',
            'nombre': 'Usuario Nuevo',
            'vehiculo': 'No registrado',
            'fecha_registro': FieldValue.serverTimestamp(),
          });
        }
      }

      // --- GUARDAMOS EL ROL EN LA MEMORIA DEL TELÉFONO ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', widget.isTaller ? 'taller' : 'conductor');

      _navigateBasedOnRole();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Error de autenticación');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Simulación de Google Sign In (UI Lista)
  Future<void> _submitGoogleAuth() async {
    setState(() => _isGoogleLoading = true);
    // TODO: Implementar el paquete google_sign_in aquí en el Paso 3
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isGoogleLoading = false);

    _showError('El inicio con Google se conectará en la siguiente fase.');
  }

  void _navigateBasedOnRole() {
    if (!mounted) return;
    if (widget.isTaller) {
      Widget proximaPantalla = _isLogin ? const TallerDashboardScreen() : const TallerSetupScreen();
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => proximaPantalla), (route) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeMapScreen()), (route) => false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(themeNotifier.value == ThemeMode.light ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: colorScheme.onSurface),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 1. Títulos Dinámicos
              Text(
                _isLogin ? 'Bienvenido' : 'Crear Cuenta',
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isTaller ? 'Gestiona tu taller y recibe clientes.' : 'Encuentra al mejor mecánico cerca de ti.',
                style: GoogleFonts.poppins(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 40),

              // 2. El Formulario (Bento Box Estilo)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildModernInput(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.alternate_email_rounded,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    _buildModernInput(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      colorScheme: colorScheme,
                    ),

                    // Olvidaste Contraseña
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                          style: TextButton.styleFrom(padding: const EdgeInsets.only(top: 16)),
                          child: Text('¿Olvidaste tu contraseña?', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),

                    SizedBox(height: _isLogin ? 8 : 24),

                    // Botón Principal
                    _isLoading
                        ? CircularProgressIndicator(color: colorScheme.primary)
                        : ElevatedButton(
                      onPressed: _submitAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.surface,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(_isLogin ? 'ENTRAR' : 'REGISTRARSE', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 3. Separador Elegante
              Row(
                children: [
                  Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('O continuar con', style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: colorScheme.outline.withOpacity(0.2))),
                ],
              ),
              const SizedBox(height: 24),

              // 4. Botones Sociales
              _isGoogleLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      onPressed: _submitGoogleAuth,
                      colorScheme: colorScheme,
                      logo: 'G', // Usamos una 'G' por ahora, luego puedes poner una imagen PNG de Google
                      label: 'Google',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSocialButton(
                      onPressed: () => _showError('Apple Login próximamente'),
                      colorScheme: colorScheme,
                      logo: 'A', // Representación de Apple
                      label: 'Apple',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 5. Toggle de Modo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLogin ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ', style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.6))),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Regístrate' : 'Inicia sesión', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({required TextEditingController controller, required String hintText, required IconData icon, required ColorScheme colorScheme, bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: colorScheme.primary.withOpacity(0.6)),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _buildSocialButton({required VoidCallback onPressed, required ColorScheme colorScheme, required String logo, required String label}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(logo, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface)),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}