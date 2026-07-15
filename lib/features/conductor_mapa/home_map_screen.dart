import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'workshop_list_screen.dart';
import 'user_profile_screen.dart';
import 'driver_active_rescue_screen.dart';
// FIX: Ajusta esta ruta si es necesario, pero sácalo de la carpeta models
import '../../models/chat_inbox_screen.dart';

import '../../features/taller_dashboard/taller_rescue_screen.dart';
import 'package:geocar/widgets/chat/universal_chat_sheet.dart';
import '../../services/voice_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/connectivity_service.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  LatLng? _miPosicionActual;
  bool _estaCargandoMapa = true;
  StreamSubscription<Position>? _positionStream;

  // --- CACHE DE STREAMS DE FIRESTORE ---
  Stream<QuerySnapshot>? _chatsDirectosStream;
  Stream<DocumentSnapshot>? _usuarioPerfilStream;
  String? _cachedUserId;

  void _inicializarStreams(String uid) {
    if (_cachedUserId == uid) return;
    _cachedUserId = uid;
    _chatsDirectosStream = FirebaseFirestore.instance
        .collection('chats_directos')
        .where('conductor_id', isEqualTo: uid)
        .where('leido_por_conductor', isEqualTo: false)
        .snapshots();
    _usuarioPerfilStream = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .snapshots();
  }

  // --- LÓGICA DE RUTAS INTERNAS ---
  final Set<Polyline> _polylines = {};
  // --------------------------------

  // --- FILTRO DE CATEGORÍAS ---
  String _filtroCategoria = "Todos";
  final List<String> _categorias = [
    'Todos', 'Mecánica Ligera', 'Tren Delantero', 'Frenos',
    'Electricidad', 'Aire Acondicionado', 'Vulcanizadora (Cauchos)'
  ];
  // ---------------------------
  StreamSubscription<bool>? _connectivitySub;
  bool _conectado = true;

  @override
  void initState() {
    super.initState();
    _iniciarRastreoGPS();
    _connectivitySub = ConnectivityService.instance.connectionStream.listen((conectado) {
      if (mounted) {
        setState(() {
          _conectado = conectado;
        });
        if (!conectado) {
          _showSnackBar("Sin conexión a Internet. GeoCar funcionará de forma limitada.", Colors.redAccent);
        } else {
          _showSnackBar("Conexión restablecida.", Colors.green);
        }
      }
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _iniciarRastreoGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar("Por favor habilita el GPS", Colors.redAccent);
      setState(() => _estaCargandoMapa = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Permisos de ubicación denegados", Colors.redAccent);
        setState(() => _estaCargandoMapa = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar("Permisos denegados permanentemente", Colors.redAccent);
      setState(() => _estaCargandoMapa = false);
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _miPosicionActual = LatLng(position.latitude, position.longitude);
          _estaCargandoMapa = false;
        });
      }
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
    return "${(distanciaEnMetros / 1000).toStringAsFixed(1)} km";
  }

  // =========================================================================
  // MOTOR SOS REFACTORIZADO (SPRINT 18: LÓGICA DE GARAGE)
  // =========================================================================

  Future<void> _lanzarSOS() async {
    if (_miPosicionActual == null) {
      _showSnackBar("Esperando señal GPS para ubicarte...", Colors.orange);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      List<dynamic> vehiculos = [];

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        if (data['vehiculos'] != null && data['vehiculos'] is List) {
          vehiculos = data['vehiculos'];
        }
      }

      if (vehiculos.isEmpty) {
        _showSnackBar("Por favor, registra un vehículo en tu Perfil antes de pedir auxilio.", Colors.orange);
        return;
      }

      if (vehiculos.length == 1) {
        var v = vehiculos[0];
        String vehiculoStr = "${v['marca']} ${v['modelo']} (${v['año']})";
        await _ejecutarSOS(user.uid, vehiculoStr);
      } else {
        _mostrarSelectorVehiculoSOS(user.uid, vehiculos);
      }

    } catch (e) {
      _showSnackBar("Error al verificar vehículos: $e", Colors.redAccent);
    }
  }

  void _mostrarSelectorVehiculoSOS(String uid, List<dynamic> vehiculos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Text('🚨 ¿Qué vehículo falló?', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...vehiculos.map((v) {
              String vehiculoStr = "${v['marca']} ${v['modelo']} (${v['año']})";
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    child: const Icon(Icons.car_crash_rounded, color: Colors.redAccent),
                  ),
                  title: Text(vehiculoStr, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _ejecutarSOS(uid, vehiculoStr);
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarSOS(String uid, String vehiculoAfectado) async {
    _showSnackBar("Enviando alerta a los talleres cercanos...", Colors.orange);
    VoiceService().speak("Solicitud de rescate enviada. Buscando talleres cercanos.");
    try {
      DocumentReference docRef = await FirebaseFirestore.instance.collection('emergencias').add({
        'conductor_id': uid,
        'posicion': GeoPoint(_miPosicionActual!.latitude, _miPosicionActual!.longitude),
        'vehiculo': vehiculoAfectado,
        'fecha': FieldValue.serverTimestamp(),
        'estado': 'activa',
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverActiveRescueScreen(emergenciaId: docRef.id),
          ),
        );
      }
    } catch (e) {
      _showSnackBar("Error al enviar SOS: $e", Colors.redAccent);
    }
  }



  static const LatLng _centerCabimas = LatLng(10.3927, -71.4405);

  final String _mapStyleLimpio = '''
[
  { "featureType": "poi", "elementType": "labels", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "transit", "elementType": "labels", "stylers": [ { "visibility": "off" } ] }
]
''';

  final String _mapStyleOscuro = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#242f3e" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#746855" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#242f3e" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "poi", "elementType": "labels", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#38414e" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#212a37" } ] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [ { "color": "#9ca5b3" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#746855" } ] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [ { "color": "#1f2835" } ] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [ { "color": "#f3d19c" } ] },
  { "featureType": "transit", "elementType": "labels", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#17263c" } ] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#515c6d" } ] },
  { "featureType": "water", "elementType": "labels.text.stroke", "stylers": [ { "color": "#17263c" } ] }
]
''';

  Marker _crearMarcadorReal(String id, Map<String, dynamic> data, ColorScheme colorScheme) {
    GeoPoint pos = data['position'];
    bool estaAbierto = data['estado'] == 'abierto';

    return Marker(
      markerId: MarkerId(id),
      position: LatLng(pos.latitude, pos.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        estaAbierto ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
      ),
      onTap: () {
        FirebaseFirestore.instance.collection('talleres').doc(id).update({
          'visitas': FieldValue.increment(1)
        }).catchError((e) => debugPrint("Error actualizando visitas: $e"));

        _mostrarDetalleTaller(
            context,
            id,
            data['nombre'] ?? 'Taller',
            data['especialidades']?.join(' • ') ?? 'Mecánica',
            _calcularDistanciaReal(pos),
            estaAbierto,
            colorScheme,
            pos,
            data['telefono']
        );
      },
    );
  }

  void _verImagenGrande(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleTaller(BuildContext context, String tallerId, String nombre, String especialidades, String distancia, bool abierto, ColorScheme colorScheme, GeoPoint posicionTaller, String? telefono) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('talleres').doc(tallerId).snapshots(),
          builder: (context, snapshot) {
            // Extraemos los datos en tiempo real para ver las fotos
            var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            String? photoUrl = data['photoUrl'];
            List<dynamic> galeria = data['fotos'] ?? [];

            return Container(
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

                  // GALERÍA DE FOTOS ESTILO GOOGLE MAPS (AL COMIENZO DE LA FICHA)
                  if (galeria.isNotEmpty) ...[
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: galeria.length,
                        itemBuilder: (context, index) {
                          final imageUrl = galeria[index];
                          return GestureDetector(
                            onTap: () => _verImagenGrande(context, imageUrl),
                            child: Container(
                              width: 220,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(imageUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else if (photoUrl != null && photoUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _verImagenGrande(context, photoUrl),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          image: DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // CABECERA CON FOTO DEL TALLER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // AQUI VA LA FOTO DE PERFIL DEL TALLER
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null ? Icon(Icons.build_circle_rounded, size: 30, color: colorScheme.primary) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: abierto ? Colors.green : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('Cabimas, Zulia', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: abierto ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: abierto ? Colors.green.shade300 : Colors.red.shade300),
                        ),
                        child: Text(abierto ? 'ABIERTO' : 'CERRADO', style: GoogleFonts.poppins(color: abierto ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // MÉTRICAS
                  Row(
                    children: [
                      _buildMiniBento(Icons.star_rounded, 'Nuevo', 'Rating', Colors.amber, colorScheme),
                      const SizedBox(width: 12),
                      _buildMiniBento(Icons.location_on_outlined, distancia, 'Distancia', colorScheme.primary, colorScheme),
                      const SizedBox(width: 12),
                      _buildMiniBento(Icons.verified_user_outlined, 'Sí', 'Verificado', Colors.blue, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(especialidades, style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 24),

                  const SizedBox(height: 16),

                  // BOTONES DE ACCIÓN (Mantenemos tu lógica intacta)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TallerRescueScreen(
                                  emergenciaId: "DIRECTORIO",
                                  destinoManual: LatLng(posicionTaller.latitude, posicionTaller.longitude),
                                  nombreDestino: nombre,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions_car_rounded),
                          label: Text('IR AL TALLER', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
                          onPressed: () {
                            Navigator.pop(context);
                            final String miUid = FirebaseAuth.instance.currentUser?.uid ?? 'anonimo';
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Padding(
                                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                child: UniversalChatSheet(
                                  modo: ChatMode.directo,
                                  referenceId: '${tallerId}_$miUid',
                                  tallerPhone: telefono ?? '',
                                  miRol: 'conductor',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
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
            );
          }
      ),
    );
  }

  Widget _buildMiniBento(IconData icon, String value, String label, Color accentColor, ColorScheme colorScheme) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: accentColor, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                Text(label, style: GoogleFonts.poppins(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildMapShimmer(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: GridPaper(
                color: colorScheme.onSurface,
                divisions: 2,
                subdivisions: 1,
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: ShimmerLoading.rounded(
              width: MediaQuery.of(context).size.width - 40,
              height: 55,
              borderRadius: 24,
            ),
          ),
          Positioned(
            top: 135,
            left: 20,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: List.generate(4, (index) => Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ShimmerLoading.rounded(
                    width: 100,
                    height: 38,
                    borderRadius: 16,
                  ),
                )),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 220,
            child: Column(
              children: [
                const ShimmerLoading.circular(width: 50, height: 50),
                const SizedBox(height: 16),
                const ShimmerLoading.circular(width: 50, height: 50),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ShimmerLoading.rounded(
              width: MediaQuery.of(context).size.width - 40,
              height: 90,
              borderRadius: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid; // Declaración de variable para el UID
    if (currentUserUid != null) {
      _inicializarStreams(currentUserUid);
    }

    return Scaffold(
      body: _estaCargandoMapa
          ? _buildMapShimmer(context, colorScheme)
          : Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('talleres').snapshots(),
            builder: (context, snapshot) {
              Set<Marker> marcadoresDinamicos = {};

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  bool estaAbierto = data['estado'] == 'abierto';

                  if (!estaAbierto) continue;

                  if (_filtroCategoria != 'Todos') {
                    List especialidades = data['especialidades'] ?? [];
                    if (!especialidades.contains(_filtroCategoria)) continue;
                  }

                  if (data.containsKey('position') && data['position'] is GeoPoint) {
                    marcadoresDinamicos.add(_crearMarcadorReal(doc.id, data, colorScheme));
                  }
                }
              }

              final bool isDark = colorScheme.brightness == Brightness.dark;
              return GoogleMap(
                style: isDark ? _mapStyleOscuro : _mapStyleLimpio,
                initialCameraPosition: CameraPosition(
                  target: _miPosicionActual ?? _centerCabimas,
                  zoom: 14.5,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController.complete(controller);
                },
                markers: marcadoresDinamicos,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: const EdgeInsets.only(bottom: 30, left: 24),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
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

                      // --- FIX: GATILLO DINÁMICO DE BANDEJA DE MENSAJES ---
                      StreamBuilder<QuerySnapshot>(
                        stream: _chatsDirectosStream,
                        builder: (context, snapshot) {
                          bool tieneMensajesNuevos = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ChatInboxScreen(miRol: 'conductor'))
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
                              ),
                              child: Badge(
                                backgroundColor: Colors.redAccent,
                                label: Text(snapshot.data?.docs.length.toString() ?? ''),
                                isLabelVisible: tieneMensajesNuevos, // Control dinámico del punto rojo
                                child: Icon(Icons.forum_rounded, color: colorScheme.primary, size: 22),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),

                      // --- FIX: FOTO DE PERFIL DINÁMICA DEL CONDUCTOR ---
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.primary, width: 2),
                          ),
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: _usuarioPerfilStream,
                            builder: (context, userSnap) {
                              String? photoUrl;
                              if (userSnap.hasData && userSnap.data!.exists) {
                                photoUrl = (userSnap.data!.data() as Map<String, dynamic>)['photoUrl'];
                              }

                              return CircleAvatar(
                                radius: 22,
                                backgroundColor: colorScheme.primary,
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null
                                    ? const Icon(Icons.person_rounded, color: Colors.white)
                                    : null,
                              );
                            },
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(
                  height: 40,
                  child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _categorias.length,
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        final isSelected = _filtroCategoria == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(cat, style: GoogleFonts.poppins(fontSize: 12, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface)),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() {
                                _filtroCategoria = cat;
                              });
                            },
                            backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
                            selectedColor: colorScheme.primary,
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        );
                      }
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 88, left: 16,
            child: FloatingActionButton(
              heroTag: 'sos_btn',
              onPressed: _lanzarSOS,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.sos_rounded, color: Colors.white, size: 30),
            ),
          ),

          Positioned(
            bottom: 24, left: 16,
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkshopListScreen())),
              backgroundColor: colorScheme.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(Icons.format_list_bulleted, color: colorScheme.primary),
              label: Text('Directorio', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ),

          if (!_conectado)
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.redAccent.withValues(alpha: 0.95),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Sin conexión a Internet. Funciones limitadas.",
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}