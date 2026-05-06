import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geocar/widgets/chat/universal_chat_sheet.dart';

class TallerRescueScreen extends StatefulWidget {
  final String emergenciaId;
  final LatLng? destinoManual; // Para cuando venimos del Directorio
  final String? nombreDestino; // Nombre del Taller a visitar

  const TallerRescueScreen({
    super.key,
    required this.emergenciaId,
    this.destinoManual,
    this.nombreDestino,
  });

  @override
  State<TallerRescueScreen> createState() => _TallerRescueScreenState();
}

class _TallerRescueScreenState extends State<TallerRescueScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final FlutterTts _tts = FlutterTts();

  // ⚠️ API KEY (Nota del Tech Lead: Para producción, pasaremos esto a un archivo .env)
  final String _googleApiKey = "AIzaSyC_mRW28URYlaVSO6qcGgtedGf7bQKi7Dc";

  LatLng? _miUbicacion;
  LatLng? _ubicacionConductor;
  Set<Polyline> _polylines = {};

  // Variables de Navegación
  List<dynamic> _pasos = [];
  int _pasoActualIndex = 0;
  String _instruccionActual = "Calculando ruta...";
  String _distanciaAlSiguientePaso = "";
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _prepararRescate();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _initTTS() async {
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _prepararRescate() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _miUbicacion = LatLng(pos.latitude, pos.longitude);

      // --- LÓGICA OMNIDIRECCIONAL: ¿Es Directorio o es Rescate SOS? ---
      if (widget.emergenciaId == "DIRECTORIO" && widget.destinoManual != null) {
        _ubicacionConductor = widget.destinoManual;
        _instruccionActual = "Navegando hacia: ${widget.nombreDestino}";
        await _obtenerRutaDetallada();
        _iniciarSeguimientoEnVivo();
      } else {
        // Flujo tradicional de Rescate SOS
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('emergencias')
            .doc(widget.emergenciaId)
            .get();

        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          GeoPoint conductorGeo = data['posicion'];
          _ubicacionConductor = LatLng(conductorGeo.latitude, conductorGeo.longitude);

          await _obtenerRutaDetallada();
          _iniciarSeguimientoEnVivo();
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error inicializando mapa: $e");
    }
  }

  Future<void> _obtenerRutaDetallada() async {
    final url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${_miUbicacion!.latitude},${_miUbicacion!.longitude}&"
        "destination=${_ubicacionConductor!.latitude},${_ubicacionConductor!.longitude}&"
        "mode=driving&language=es&key=$_googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final route = data['routes'][0];
      final leg = route['legs'][0];

      _pasos = leg['steps'];
      _actualizarInstruccion(0);

      // Dibujar Polyline
      List<LatLng> points = _decodePoly(route['overview_polyline']['points']);
      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId("ruta"),
          color: Colors.blueAccent,
          width: 8,
          points: points,
        ));
      });
    }
  }

  void _actualizarInstruccion(int index) {
    if (index < _pasos.length) {
      String rawText = _pasos[index]['html_instructions'];
      String cleanText = rawText.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');

      setState(() {
        _pasoActualIndex = index;
        _instruccionActual = cleanText;
        _distanciaAlSiguientePaso = _pasos[index]['distance']['text'];
      });

      _tts.speak(cleanText);
    }
  }

  void _iniciarSeguimientoEnVivo() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) async {
      _miUbicacion = LatLng(position.latitude, position.longitude);

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _miUbicacion!, zoom: 18, tilt: 45, bearing: position.heading)
      ));

      _verificarProgreso(position);
    });
  }

  void _verificarProgreso(Position currentPos) {
    if (_pasos.isEmpty || _pasoActualIndex >= _pasos.length) return;

    var nextStepPos = _pasos[_pasoActualIndex]['end_location'];
    double distance = Geolocator.distanceBetween(
        currentPos.latitude, currentPos.longitude,
        nextStepPos['lat'], nextStepPos['lng']
    );

    if (distance < 20) { // Tolerancia de 20m para cambiar instrucción
      _actualizarInstruccion(_pasoActualIndex + 1);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _miUbicacion!, zoom: 15),
            onMapCreated: (c) => _mapController.complete(c),
            polylines: _polylines,
            myLocationEnabled: true,
            compassEnabled: false,
            mapToolbarEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId("destino"),
                position: _ubicacionConductor!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              ),
            },
          ),

          // PANEL DE NAVEGACIÓN SUPERIOR
          Positioned(
            top: 60, left: 15, right: 15,
            child: _buildNavigationCard(),
          ),

          // CARD INFERIOR DINÁMICA (Rescate vs Directorio)
          Positioned(
              bottom: 30, left: 15, right: 15,
              child: widget.emergenciaId == "DIRECTORIO"
                  ? _buildDirectorioCard()
                  : _buildEmergencyCard()
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade900.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_instruccionActual, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("En $_distanciaAlSiguientePaso", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TARJETA PARA CUANDO EL CONDUCTOR VA AL TALLER ---
  Widget _buildDirectorioCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue.shade100, child: const Icon(Icons.storefront_rounded, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.nombreDestino ?? 'Taller', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text("FINALIZAR VIAJE"),
            ),
          ),
        ],
      ),
    );
  }

  // --- TARJETA PARA CUANDO EL TALLER VA AL RESCATE (CON CHAT INYECTADO) ---
  Widget _buildEmergencyCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.red.shade100, child: const Icon(Icons.car_repair, color: Colors.red)),
                  const SizedBox(width: 12),
                  Text(data['vehiculo'] ?? 'Vehículo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  // EL GATILLO DEL CHAT PARA EL MECÁNICO
                  IconButton(
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
                              tallerPhone: '', // No hace falta fallback hacia WP para sí mismo
                              miRol: 'taller', // CRÍTICO: Define las burbujas azules para el mecánico
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_rounded, color: Colors.blue, size: 28)
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).update({'estado': 'finalizada'}).then((_) => Navigator.pop(context)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("RESCATE FINALIZADO"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}