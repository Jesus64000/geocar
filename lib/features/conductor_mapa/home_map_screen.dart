import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

import 'workshop_list_screen.dart';
import 'user_profile_screen.dart';
import 'driver_active_rescue_screen.dart';
// FIX: Ajusta esta ruta si es necesario, pero sácalo de la carpeta models
import '../../models/chat_inbox_screen.dart';

import '../../features/taller_dashboard/taller_rescue_screen.dart';
import 'package:geocar/widgets/chat/universal_chat_sheet.dart';


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

  // --- LÓGICA DE RUTAS INTERNAS ---
  final Set<Polyline> _polylines = {};
  // TODO: Mover a variables de entorno en producción
  final String _googleApiKey = "AIzaSyC_mRW28URYlaVSO6qcGgtedGf7bQKi7Dc";
  // --------------------------------

  // --- FILTRO DE CATEGORÍAS ---
  String _filtroCategoria = "Todos";
  final List<String> _categorias = [
    'Todos', 'Mecánica Ligera', 'Tren Delantero', 'Frenos',
    'Electricidad', 'Aire Acondicionado', 'Vulcanizadora (Cauchos)'
  ];
  // ---------------------------

  @override
  void initState() {
    super.initState();
    _iniciarRastreoGPS();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
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

  // 1. Verificador del Garage
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

      // CASO A: No tiene vehículos
      if (vehiculos.isEmpty) {
        _showSnackBar("Por favor, registra un vehículo en tu Perfil antes de pedir auxilio.", Colors.orange);
        return; // Rompemos el flujo, no lo dejamos pedir SOS vacío
      }

      // CASO B: Tiene 1 solo vehículo
      if (vehiculos.length == 1) {
        var v = vehiculos[0];
        String vehiculoStr = "${v['marca']} ${v['modelo']} (${v['año']})";
        await _ejecutarSOS(user.uid, vehiculoStr);
      }
      // CASO C: Tiene Múltiples vehículos (Abre el selector)
      else {
        _mostrarSelectorVehiculoSOS(user.uid, vehiculos);
      }

    } catch (e) {
      _showSnackBar("Error al verificar vehículos: $e", Colors.redAccent);
    }
  }

  // 2. Selector de UI
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
                    Navigator.pop(context); // Cierra modal
                    _ejecutarSOS(uid, vehiculoStr); // Dispara el cohete
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

  // 3. El Motor de Disparo
  Future<void> _ejecutarSOS(String uid, String vehiculoAfectado) async {
    _showSnackBar("Enviando alerta a los talleres cercanos...", Colors.orange);
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
  // =========================================================================


  Future<void> _dibujarRutaEnMapa(GeoPoint destino) async {
    if (_miPosicionActual == null) {
      _showSnackBar("Esperando tu ubicación GPS...", Colors.orange);
      return;
    }

    PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleApiKey);

    try {
      RoutesApiResponse response = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(_miPosicionActual!.latitude, _miPosicionActual!.longitude),
          destination: PointLatLng(destino.latitude, destino.longitude),
          travelMode: TravelMode.driving,
        ),
      );

      PolylineResult result = polylinePoints.convertToLegacyResult(response);

      if (result.points.isNotEmpty) {
        List<LatLng> pLineCoordinates = [];
        for (var point in result.points) {
          pLineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('ruta_activa'),
              color: Theme.of(context).colorScheme.primary,
              points: pLineCoordinates,
              width: 5,
              jointType: JointType.round,
            ),
          );
        });

        _ajustarCamaraARuta(LatLng(destino.latitude, destino.longitude));

      } else {
        _showSnackBar("No se pudo trazar la ruta. Verifica tu API Key.", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Error al generar ruta: $e", Colors.redAccent);
    }
  }

  Future<void> _ajustarCamaraARuta(LatLng destino) async {
    if (_miPosicionActual == null) return;
    LatLngBounds bounds;
    if (_miPosicionActual!.latitude > destino.latitude && _miPosicionActual!.longitude > destino.longitude) {
      bounds = LatLngBounds(southwest: destino, northeast: _miPosicionActual!);
    } else if (_miPosicionActual!.longitude > destino.longitude) {
      bounds = LatLngBounds(
          southwest: LatLng(_miPosicionActual!.latitude, destino.longitude),
          northeast: LatLng(destino.latitude, _miPosicionActual!.longitude));
    } else if (_miPosicionActual!.latitude > destino.latitude) {
      bounds = LatLngBounds(
          southwest: LatLng(destino.latitude, _miPosicionActual!.longitude),
          northeast: LatLng(_miPosicionActual!.latitude, destino.longitude));
    } else {
      bounds = LatLngBounds(southwest: _miPosicionActual!, northeast: destino);
    }

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  static const LatLng _centerCabimas = LatLng(10.3927, -71.4405);

  final String _mapStyleLimpio = '''
[
  { "featureType": "poi", "elementType": "labels", "stylers": [ { "visibility": "off" } ] },
  { "featureType": "transit", "elementType": "labels", "stylers": [ { "visibility": "off" } ] }
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
        // --- MOTOR DE ANALÍTICAS ---
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

  void _mostrarDetalleTaller(BuildContext context, String tallerId, String nombre, String especialidades, String distancia, bool abierto, ColorScheme colorScheme, GeoPoint posicionTaller, String? telefono) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: abierto ? Colors.green : Colors.grey),
                          const SizedBox(width: 4),
                          Text('Cabimas, Zulia', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: abierto ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: abierto ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Text(abierto ? 'ABIERTO' : 'CERRADO', style: GoogleFonts.poppins(color: abierto ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildMiniBento(Icons.star_rounded, 'Nuevo', 'Rating', Colors.amber, colorScheme),
                const SizedBox(width: 12),
                _buildMiniBento(Icons.location_on_outlined, distancia, 'Distancia', colorScheme.primary, colorScheme),
                const SizedBox(width: 12),
                _buildMiniBento(Icons.verified_user_outlined, 'Sí', 'Verificado', Colors.blue, colorScheme),
              ],
            ),
            const SizedBox(height: 24),

            Text(especialidades, style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 32),

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _estaCargandoMapa
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text("Sincronizando satélites...", style: GoogleFonts.poppins())
        ],
      ))
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

              return GoogleMap(
                style: _mapStyleLimpio,
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

                      GestureDetector(
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
                            smallSize: 10,
                            child: Icon(Icons.forum_rounded, color: colorScheme.primary, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.primary, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: colorScheme.primary,
                            child: const Icon(Icons.person_rounded, color: Colors.white),
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
            bottom: 110, right: 24,
            child: FloatingActionButton(
              heroTag: 'sos_btn',
              onPressed: _lanzarSOS,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.sos_rounded, color: Colors.white, size: 30),
            ),
          ),

          Positioned(
            bottom: 40, right: 24,
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkshopListScreen())),
              backgroundColor: colorScheme.surface,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: Icon(Icons.format_list_bulleted, color: colorScheme.primary),
              label: Text('Directorio', style: GoogleFonts.poppins(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}