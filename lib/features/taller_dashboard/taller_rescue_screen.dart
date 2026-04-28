import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

class TallerRescueScreen extends StatefulWidget {
  final String emergenciaId; // Recibimos el ID de la alerta SOS

  const TallerRescueScreen({super.key, required this.emergenciaId});

  @override
  State<TallerRescueScreen> createState() => _TallerRescueScreenState();
}

class _TallerRescueScreenState extends State<TallerRescueScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  // ⚠️ PON TU CLAVE API AQUÍ PARA DIBUJAR LA RUTA
  final String _googleApiKey = "AIzaSyC_mRW28URYlaVSO6qcGgtedGf7bQKi7Dc";

  LatLng? _miUbicacion;
  LatLng? _ubicacionConductor;
  Set<Polyline> _polylines = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepararRescate();
  }

  Future<void> _prepararRescate() async {
    try {
      // 1. Obtener mi ubicación actual (Taller)
      Position pos = await Geolocator.getCurrentPosition();
      _miUbicacion = LatLng(pos.latitude, pos.longitude);

      // 2. Obtener datos de la emergencia
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('emergencias')
          .doc(widget.emergenciaId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        GeoPoint conductorGeo = data['posicion'];
        _ubicacionConductor = LatLng(conductorGeo.latitude, conductorGeo.longitude);

        // 3. Dibujar la ruta entre ambos
        await _trazarRuta();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error preparando rescate: $e");
    }
  }

  Future<void> _trazarRuta() async {
    if (_miUbicacion == null || _ubicacionConductor == null) return;

    PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleApiKey);

    RoutesApiResponse response = await polylinePoints.getRouteBetweenCoordinatesV2(
      request: RoutesApiRequest(
        origin: PointLatLng(_miUbicacion!.latitude, _miUbicacion!.longitude),
        destination: PointLatLng(_ubicacionConductor!.latitude, _ubicacionConductor!.longitude),
        travelMode: TravelMode.driving,
      ),
    );

    PolylineResult result = polylinePoints.convertToLegacyResult(response);

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = result.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId("ruta_rescate"),
          color: Colors.redAccent,
          width: 6,
          points: polylineCoordinates,
        ));
      });
    }
  }

  Future<void> _finalizarRescate() async {
    await FirebaseFirestore.instance
        .collection('emergencias')
        .doc(widget.emergenciaId)
        .update({'estado': 'finalizada'});

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rescate finalizado con éxito"), backgroundColor: Colors.green)
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // EL MAPA DE RESCATE
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _ubicacionConductor!,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController.complete(controller),
            polylines: _polylines,
            myLocationEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId("conductor"),
                position: _ubicacionConductor!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: "Conductor varado"),
              ),
            },
          ),

          // BOTÓN VOLVER
          Positioned(
            top: 50, left: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 18),
            ),
          ),

          // CARD DE INFORMACIÓN DEL CONDUCTOR
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.emergenciaId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  var data = snapshot.data!.data() as Map<String, dynamic>;

                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.redAccent.withOpacity(0.1),
                              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['vehiculo'] ?? 'Vehículo', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                                  Text('Ubicación: Sector Delicias', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _finalizarRescate,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('FINALIZAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                              child: IconButton(
                                onPressed: () {
                                  // Aquí conectarías al WhatsApp del conductor
                                },
                                icon: const Icon(Icons.chat_bubble_rounded, color: Colors.green),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                }
            ),
          ),
        ],
      ),
    );
  }
}