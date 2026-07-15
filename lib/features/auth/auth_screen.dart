import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // EL MOTOR DE GOOGLE
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../main.dart';
import '../taller_dashboard/taller_dashboard_screen.dart';
import '../taller_dashboard/taller_setup_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_role_screen.dart';
import '../conductor_mapa/home_map_screen.dart';
import '../conductor_mapa/user_profile_screen.dart';

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
  final _formKey = GlobalKey<FormState>(); // CLAVE PARA VALIDACIÓN DE FORMULARIO

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _selectedRole; // 'conductor' o 'taller'

  // 1. EL MOTOR PRINCIPAL DE CORREO/CONTRASEÑA
  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) {
      return; // Detiene la autenticación si los campos son inválidos
    }
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;

      if (_isLogin) {
        userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );
        
        final user = userCredential.user;
        if (user != null && !user.emailVerified) {
          await _auth.signOut();
          _showError('Por favor, verifica tu correo electrónico antes de iniciar sesión. Revisa tu bandeja de entrada o spam.');
          setState(() => _isLoading = false);
          return;
        }

        // Consultamos en ambas colecciones con control de excepciones
        bool existsAsUsuario = false;
        bool existsAsTaller = false;

        try {
          final usuarioDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user!.uid).get();
          existsAsUsuario = usuarioDoc.exists;
        } catch (e) {
          existsAsUsuario = false;
        }

        try {
          final tallerDoc = await FirebaseFirestore.instance.collection('talleres').doc(user!.uid).get();
          existsAsTaller = tallerDoc.exists;
        } catch (e) {
          existsAsTaller = false;
        }

        if (existsAsUsuario) {
          await _marcarRolEnMemoriaEspecifico(false);
          _navigateToDriverFlow(isNew: false);
        } else if (existsAsTaller) {
          await _marcarRolEnMemoriaEspecifico(true);
          _navigateToTallerFlow(isNew: false);
        } else {
          // Si no existe en ninguno (caso huérfano o incompleto), lo mandamos a pantalla completa
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => WelcomeRoleScreen(user: user!),
            ),
            (route) => false,
          );
        }
      } else {
        // Registro nuevo por correo/contraseña
        if (_selectedRole == null) {
          _showError('Por favor selecciona un rol antes de continuar.');
          setState(() => _isLoading = false);
          return;
        }

        userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        final user = userCredential.user;
        if (user != null) {
          // Crear documento en Firestore de inmediato según el rol para evitar huérfanos
          if (_selectedRole == 'taller') {
            await FirebaseFirestore.instance.collection('talleres').doc(user.uid).set({
              'uid': user.uid,
              'correo': user.email ?? '',
              'rol': 'taller',
              'nombre': 'Taller de Geocar',
              'estado': 'cerrado',
              'fecha_registro': FieldValue.serverTimestamp(),
            });
          } else {
            await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
              'uid': user.uid,
              'correo': user.email ?? '',
              'rol': 'conductor',
              'nombre': 'Usuario de Geocar',
              'vehiculos': [],
              'fecha_registro': FieldValue.serverTimestamp(),
            });
          }

          // Enviar correo de verificación
          await user.sendEmailVerification();

          // Cerrar sesión para obligar verificación antes del login
          await _auth.signOut();

          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('¡Registro Exitoso!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text(
                'Hemos enviado un correo de verificación a ${user.email}. Por favor verifica tu cuenta para activarla antes de entrar.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isLogin = true;
                      _selectedRole = null;
                      _emailController.clear();
                      _passwordController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Entendido', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Error de autenticación');
    } catch (e) {
      _showError('Ocurrió un error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. EL MOTOR DE GOOGLE SIGN-IN (LA GRAN INYECCIÓN NATIVA)
  Future<void> _submitGoogleAuth() async {
    setState(() => _isGoogleLoading = true);
    try {
      // 1. Iniciamos la autenticación nativa usando el selector del dispositivo (API v7+)
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return; // El usuario canceló la selección de cuenta
      }

      // 2. Obtenemos las claves de acceso de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Generamos la credencial para Firebase Auth usando el idToken nativo
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: null, // No se requiere para el inicio de sesión de Firebase
        idToken: googleAuth.idToken,
      );

      // 4. Iniciamos sesión en Firebase con la credencial obtenida
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Consultamos en ambas colecciones con control de excepciones para manejar reglas de Firestore restrictivas en nuevos usuarios
        bool existsAsUsuario = false;
        bool existsAsTaller = false;

        try {
          final usuarioDoc = await FirebaseFirestore.instance.collection('usuarios').doc(firebaseUser.uid).get();
          existsAsUsuario = usuarioDoc.exists;
        } catch (e) {
          debugPrint("Aviso: No se pudo leer el documento de conductor (probablemente no existe o regla restrictiva): $e");
          existsAsUsuario = false;
        }

        try {
          final tallerDoc = await FirebaseFirestore.instance.collection('talleres').doc(firebaseUser.uid).get();
          existsAsTaller = tallerDoc.exists;
        } catch (e) {
          debugPrint("Aviso: No se pudo leer el documento de taller (probablemente no existe o regla restrictiva): $e");
          existsAsTaller = false;
        }

        if (existsAsUsuario) {
          // Ya existe como conductor
          await _marcarRolEnMemoriaEspecifico(false);
          _navigateToDriverFlow(isNew: false);
        } else if (existsAsTaller) {
          // Ya existe como taller
          await _marcarRolEnMemoriaEspecifico(true);
          _navigateToTallerFlow(isNew: false);
        } else {
          // Si es un usuario nuevo y ya seleccionó un rol en la pantalla de registro
          if (_selectedRole != null) {
            final isTaller = _selectedRole == 'taller';
            await _marcarRolEnMemoriaEspecifico(isTaller);
            
            if (isTaller) {
              await FirebaseFirestore.instance.collection('talleres').doc(firebaseUser.uid).set({
                'uid': firebaseUser.uid,
                'correo': firebaseUser.email ?? '',
                'rol': 'taller',
                'nombre': firebaseUser.displayName ?? 'Taller de Geocar',
                'photoUrl': firebaseUser.photoURL,
                'estado': 'cerrado',
                'fecha_registro': FieldValue.serverTimestamp(),
              });
              _navigateToTallerFlow(isNew: true);
            } else {
              await FirebaseFirestore.instance.collection('usuarios').doc(firebaseUser.uid).set({
                'uid': firebaseUser.uid,
                'correo': firebaseUser.email ?? '',
                'rol': 'conductor',
                'nombre': firebaseUser.displayName ?? 'Usuario de Geocar',
                'photoUrl': firebaseUser.photoURL,
                'vehiculos': [],
                'fecha_registro': FieldValue.serverTimestamp(),
              });
              _navigateToDriverFlow(isNew: true);
            }
          } else {
            // Si no seleccionó rol (entró desde Login), va a la pantalla de selección de rol
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => WelcomeRoleScreen(user: firebaseUser),
              ),
              (route) => false,
            );
          }
        }
      }

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Error con Google Sign In');
    } catch (e) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
      debugPrint("Error Google Sign In: $e");
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // EL CEREBRO DE LA MEMORIA (Guarda el rol de forma segura)
  Future<void> _marcarRolEnMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    // Guardamos un booleano para que sea fácil de leer en la pantalla de bienvenida
    await prefs.setBool('last_role_is_taller', widget.isTaller);
    await prefs.setString('user_role', widget.isTaller ? 'taller' : 'conductor');
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

  Future<void> _marcarRolEnMemoriaEspecifico(bool isTaller) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('last_role_is_taller', isTaller);
    await prefs.setString('user_role', isTaller ? 'taller' : 'conductor');
  }

  void _navigateToDriverFlow({required bool isNew}) {
    if (!mounted) return;
    if (isNew) {
      // Flujo inteligente: ir al mapa y lanzar perfil/garage encima de inmediato
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
        (route) => false,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UserProfileScreen()),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeMapScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToTallerFlow({required bool isNew}) {
    if (!mounted) return;
    Widget proximaPantalla = isNew ? const TallerSetupScreen() : const TallerDashboardScreen();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => proximaPantalla),
      (route) => false,
    );
  }

  Future<String?> _showGoogleRoleSelectionModal(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: false, // Forzar a elegir o cancelar explícitamente
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra decorativa superior
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  '¡Casi Listo!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor selecciona cómo vas a utilizar GeoCar para poder configurar tu experiencia ideal.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                
                // TARJETA 1: Conductor
                GestureDetector(
                  onTap: () => Navigator.pop(context, 'conductor'),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.secondary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.drive_eta_outlined,
                            color: colorScheme.secondary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Necesito un Mecánico',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Soy conductor, deseo reportar averías y buscar auxilio.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: colorScheme.onSurface.withOpacity(0.3),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // TARJETA 2: Taller
                GestureDetector(
                  onTap: () => Navigator.pop(context, 'taller'),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.build_circle_outlined,
                            color: colorScheme.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Soy un Taller / Mecánico',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ofrezco servicios de reparación y auxilio vial.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: colorScheme.onSurface.withOpacity(0.3),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // BOTÓN PARA CANCELAR
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    'Cancelar registro',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
            onPressed: () async {
              final nuevoModo = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              themeNotifier.value = nuevoModo;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('theme_mode', nuevoModo == ThemeMode.dark ? 'dark' : 'light');
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
                _isLogin
                    ? 'Bienvenido'
                    : (_selectedRole == null
                        ? 'Crear Cuenta'
                        : (_selectedRole == 'taller'
                            ? 'Registrarse como Taller'
                            : 'Registrarse como Conductor')),
                style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Tu red mecánica y auxilio vial en tiempo real.'
                    : (_selectedRole == null
                        ? 'Selecciona tu rol para registrarte:'
                        : 'Ingresa tus datos para completar el registro.'),
                style: GoogleFonts.poppins(fontSize: 15, color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 32),

              // 2. El Formulario / Selector de Rol
              if (!_isLogin && _selectedRole == null) ...[
                // Pantalla de selección de Rol
                _buildRoleSelectionCard(
                  context,
                  title: 'Necesito un Mecánico',
                  subtitle: 'Soy conductor, deseo reportar averías y buscar auxilio.',
                  icon: Icons.drive_eta_outlined,
                  color: colorScheme.secondary,
                  role: 'conductor',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 20),
                _buildRoleSelectionCard(
                  context,
                  title: 'Soy un Taller / Mecánico',
                  subtitle: 'Ofrezco servicios de reparación y auxilio vial.',
                  icon: Icons.build_circle_outlined,
                  color: colorScheme.primary,
                  role: 'taller',
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Ya tienes cuenta? ', style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.6))),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isLogin = true;
                        _selectedRole = null;
                      }),
                      child: Text('Inicia sesión', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ] else ...[
                // Pantalla de Login o Formulario de Registro simplificado
                Form(
                  key: _formKey,
                  child: Container(
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El correo es obligatorio';
                            }
                            final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegExp.hasMatch(value.trim())) {
                              return 'Ingresa un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildModernInput(
                          controller: _passwordController,
                          hintText: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscureText: true,
                          colorScheme: colorScheme,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'La contraseña es obligatoria';
                            }
                            if (value.length < 6) {
                              return 'Debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),

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
                ),
                const SizedBox(height: 32),

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

                // 4. Botones Sociales (GATILLO DE GOOGLE)
                _isGoogleLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildSocialButton(
                        onPressed: _submitGoogleAuth,
                        colorScheme: colorScheme,
                        logo: 'G',
                        label: 'Continuar con Google',
                      ),
                const SizedBox(height: 32),

                if (_isLogin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿No tienes cuenta? ', style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.6))),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = false;
                          _selectedRole = null;
                        }),
                        child: Text('Regístrate', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = null;
                        }),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_rounded, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text('Cambiar de rol', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('|', style: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.3))),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = true;
                          _selectedRole = null;
                        }),
                        child: Text('Iniciar sesión', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required ColorScheme colorScheme,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: colorScheme.primary.withOpacity(0.6)),
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
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

  Widget _buildRoleSelectionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String role,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: colorScheme.onSurface.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}