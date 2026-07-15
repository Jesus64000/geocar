import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// Importa las herramientas necesarias (Ajusta las rutas a tu proyecto)
import '../../widgets/chat/universal_chat_sheet.dart';
import 'driver_review_modal.dart'; // <-- NUESTRO NUEVO MOTOR DE RESEÑAS
import '../../core/config/app_config.dart';
import '../../services/voice_service.dart';

class DriverActiveRescueScreen extends StatefulWidget {
  final String emergenciaId;

  const DriverActiveRescueScreen({super.key, required this.emergenciaId});

  @override
  State<DriverActiveRescueScreen> createState() => _DriverActiveRescueScreenState();
}

class _DriverActiveRescueScreenState extends State<DriverActiveRescueScreen> {
  StreamSubscription<DocumentSnapshot>? _emergenciaSub;
  bool _modalAbierto = false;
  String _ultimoEstado = "";
  Timer? _requeueTimer;

  // Map variables
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  Set<Polyline> _polylines = {};
  LatLng? _ultimoTallerPos;

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

  @override
  void initState() {
    super.initState();
    _iniciarEscuchaEventosBaseDeDatos();
    _iniciarTimerRequeue();
  }

  void _iniciarEscuchaEventosBaseDeDatos() {
    _emergenciaSub = FirebaseFirestore.instance
        .collection('emergencias')
        .doc(widget.emergenciaId)
        .snapshots()
        .listen((snapshot) {

      if (!snapshot.exists) return;

      var data = snapshot.data() as Map<String, dynamic>;
      String estado = data['estado'] ?? '';

      // Control por voz al cambiar el estado
      if (estado != _ultimoEstado) {
        _ultimoEstado = estado;
        if (estado == 'en_camino') {
          VoiceService().speak("El taller ha aceptado tu auxilio y se encuentra en camino.");
        } else if (estado == 'finalizada') {
          VoiceService().speak("El servicio ha finalizado. Por favor, califica al mecánico.");
        }
      }

      // EVENTO A: El taller finalizó el trabajo
      if (estado == 'finalizada' && !_modalAbierto) {
        _modalAbierto = true;
        _mostrarModalCalificacion(data['taller_id']);
      }
      // EVENTO B: Se canceló la emergencia
      else if (estado == 'cancelada') {
        _emergenciaSub?.cancel();
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
    });
  }

  void _iniciarTimerRequeue() {
    _requeueTimer = Timer(const Duration(seconds: 180), () async {
      try {
        final doc = await FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final estado = data['estado'] ?? 'activa';
          if (estado == 'activa') {
            await FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).update({
              'prioridad': 'alta',
              'escala_radio': true,
              'reintento_at': FieldValue.serverTimestamp(),
            });
            VoiceService().speak("Extendiendo el radio de búsqueda para encontrar un auxilio vial rápido.");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Extendiendo radio de búsqueda a talleres más lejanos...",
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error en re-queue automático: $e");
      }
    });
  }

  @override
  void dispose() {
    _emergenciaSub?.cancel();
    _requeueTimer?.cancel();
    super.dispose();
  }

  void _mostrarModalCalificacion(String tallerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PopScope(
        canPop: false,
        child: DriverReviewModal(
          tallerId: tallerId,
          emergenciaId: widget.emergenciaId,
        ),
      ),
    ).then((_) {
      _emergenciaSub?.cancel();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  // Decodificador de Polyline
  List<LatLng> _decodePoly(String poly) {
    var list = poly.codeUnits;
    var lList = <double>[];
    int index = 0;
    int len = poly.length;
    int c = 0;
    do {
      var shift = 0;
      int result = 0;
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1).toDouble();
      lList.add(result1);
    } while (index < len);

    for (var i = 2; i < lList.length; i++) {
      lList[i] += lList[i - 2];
    }

    var res = <LatLng>[];
    for (var i = 0; i < lList.length; i += 2) {
      res.add(LatLng(lList[i] / 1e5, lList[i + 1] / 1e5));
    }
    return res;
  }

  Future<void> _obtenerRutaConductorTaller(LatLng driver, LatLng taller) async {
    if (_ultimoTallerPos != null &&
        Geolocator.distanceBetween(
            _ultimoTallerPos!.latitude,
            _ultimoTallerPos!.longitude,
            taller.latitude,
            taller.longitude) < 50) {
      return;
    }
    _ultimoTallerPos = taller;

    try {
      final apiKey = AppConfig.googleApiKey;
      final url = "https://maps.googleapis.com/maps/api/directions/json?"
          "origin=${taller.latitude},${taller.longitude}&"
          "destination=${driver.latitude},${driver.longitude}&"
          "mode=driving&language=es&key=$apiKey";

      final response = await http.get(Uri.parse(url));
      final responseData = json.decode(response.body);

      if (responseData['status'] == 'OK') {
        final route = responseData['routes'][0];
        final points = _decodePoly(route['overview_polyline']['points']);
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId("ruta_rescate"),
              color: Colors.blueAccent,
              width: 6,
              points: points,
            )
          };
        });
      }
    } catch (e) {
      debugPrint("Error al obtener ruta: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text("Rescate en Curso", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Center(child: CircularProgressIndicator());

            bool estaEnCamino = data['estado'] == 'en_camino';
            bool estaFinalizada = data['estado'] == 'finalizada';

            if (estaEnCamino) {
              GeoPoint conductorGeo = data['posicion'];
              GeoPoint? tallerGeo = data['taller_posicion'];
              LatLng driverLatLng = LatLng(conductorGeo.latitude, conductorGeo.longitude);
              LatLng? tallerLatLng = tallerGeo != null ? LatLng(tallerGeo.latitude, tallerGeo.longitude) : null;

              if (tallerLatLng != null) {
                _obtenerRutaConductorTaller(driverLatLng, tallerLatLng);
              }

              Set<Marker> markers = {
                Marker(
                  markerId: const MarkerId("conductor"),
                  position: driverLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                )
              };

              if (tallerLatLng != null) {
                markers.add(Marker(
                  markerId: const MarkerId("taller"),
                  position: tallerLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ));
              }

              return Stack(
                children: [
                  // MAPA BASE DE RESCATE
                  GoogleMap(
                    style: isDark ? _mapStyleOscuro : _mapStyleLimpio,
                    initialCameraPosition: CameraPosition(target: driverLatLng, zoom: 15),
                    onMapCreated: (controller) {
                      if (!_mapController.isCompleted) {
                        _mapController.complete(controller);
                      }
                    },
                    markers: markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    compassEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    padding: const EdgeInsets.only(bottom: 240, left: 10), // Padding legal del logo Google
                  ),

                  // TARJETA DE INFORMACIÓN SOBRE EL MAPA
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                                child: const Icon(Icons.airport_shuttle_rounded, color: Colors.blue, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("¡Mecánico en Camino!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface)),
                                    const SizedBox(height: 2),
                                    Text(data['taller_nombre'] ?? 'Taller de Geocar', style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.7))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => Padding(
                                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                        child: UniversalChatSheet(
                                          modo: ChatMode.sos,
                                          referenceId: widget.emergenciaId,
                                          tallerPhone: data['taller_telefono'] ?? '',
                                          miRol: 'conductor',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_rounded),
                                  label: Text("CHAT EN VIVO", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () async {
                                  final tel = data['taller_telefono'] ?? '';
                                  if (tel.isNotEmpty) {
                                    final uri = Uri.parse("tel:$tel");
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              );
            }

            // MIENTRAS BUSCA TALLERES (DISEÑO CLÁSICO DE RADAR)
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: estaFinalizada
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                    ),
                    child: Icon(
                      estaFinalizada ? Icons.stars_rounded : Icons.radar_rounded,
                      size: 80,
                      color: estaFinalizada ? Colors.blue : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    estaFinalizada ? "Misión Cumplida" : "Buscando Talleres...",
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    estaFinalizada
                        ? "Por favor, evalúa el servicio del mecánico."
                        : "Estamos alertando a los mecánicos disponibles en un radio cercano.",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  if (!estaFinalizada)
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        bool? confirmar = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text("¿Cancelar solicitud?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            content: Text("¿Estás seguro de que deseas cancelar la solicitud de auxilio vial actual?", style: GoogleFonts.poppins()),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text("No", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey))
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text("Sí, cancelar", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (confirmar == true) {
                          try {
                            await FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).update({
                              'estado': 'cancelada',
                              'cancelada_por': 'conductor',
                              'cancelada_at': FieldValue.serverTimestamp(),
                            });
                            VoiceService().speak("Solicitud de rescate cancelada.");
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("Solicitud de auxilio vial cancelada con éxito.", style: GoogleFonts.poppins()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            navigator.pop();
                          } catch (e) {
                            debugPrint("Error cancelando emergencia: $e");
                          }
                        }
                      },
                      child: Text("Cancelar Solicitud", style: GoogleFonts.poppins(color: Colors.grey, decoration: TextDecoration.underline)),
                    )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}