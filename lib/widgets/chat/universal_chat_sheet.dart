import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum ChatMode { sos, directo }

class UniversalChatSheet extends StatefulWidget {
  final ChatMode modo;
  final String referenceId; // SOS: emergenciaId | Directo: tallerId_conductorId
  final String tallerPhone; // Para el Fallback de WhatsApp
  final String miRol; // 'taller' o 'conductor'

  const UniversalChatSheet({
    super.key,
    required this.modo,
    required this.referenceId,
    required this.tallerPhone,
    required this.miRol,
  });

  @override
  State<UniversalChatSheet> createState() => _UniversalChatSheetState();
}

class _UniversalChatSheetState extends State<UniversalChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final String _miUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final ScrollController _scrollController = ScrollController();

  // Motores Multimedia
  final ImagePicker _picker = ImagePicker();
  bool _subiendoImagen = false;

  // Define la ruta en Firestore según el modo
  CollectionReference get _mensajesRef {
    if (widget.modo == ChatMode.sos) {
      return FirebaseFirestore.instance.collection('emergencias').doc(widget.referenceId).collection('mensajes');
    } else {
      return FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).collection('mensajes');
    }
  }

  Future<void> _enviarMensaje() async {
    if (_msgController.text.trim().isEmpty) return;

    final texto = _msgController.text.trim();
    _msgController.clear();

    Map<String, dynamic> payload = {
      'sender_id': _miUid,
      'sender_rol': widget.miRol,
      'tipo': 'texto',
      'contenido': texto,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (widget.modo == ChatMode.directo) {
      payload['expira_el'] = DateTime.now().add(const Duration(days: 7));
    }

    // 1. Guardar el mensaje en la burbuja del chat
    await _mensajesRef.add(payload);

    // 2. CRÍTICO: Crear/Actualizar el Documento Padre para la Bandeja de Entrada
    if (widget.modo == ChatMode.directo) {
      List<String> ids = widget.referenceId.split('_');
      if (ids.length == 2) {
        await FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).set({
          'taller_id': ids[0],
          'conductor_id': ids[1],
          'ultimo_mensaje': texto,
          'timestamp': FieldValue.serverTimestamp(),
          'expira_el': DateTime.now().add(const Duration(days: 7))
        }, SetOptions(merge: true)); // 'merge: true' evita borrar datos anteriores
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // RESTAURADO: Motor de imágenes (Se había borrado accidentalmente)
  Future<void> _enviarImagen() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _subiendoImagen = true);

    try {
      File file = File(image.path);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      Reference ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.referenceId)
          .child(fileName);

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      Map<String, dynamic> payload = {
        'sender_id': _miUid,
        'sender_rol': widget.miRol,
        'tipo': 'imagen',
        'contenido': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (widget.modo == ChatMode.directo) {
        payload['expira_el'] = DateTime.now().add(const Duration(days: 7));
      }

      // 1. Guardar mensaje de imagen
      await _mensajesRef.add(payload);

      // 2. CRÍTICO: Actualizar Bandeja de Entrada indicando que se envió una foto
      if (widget.modo == ChatMode.directo) {
        List<String> ids = widget.referenceId.split('_');
        if (ids.length == 2) {
          await FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).set({
            'taller_id': ids[0],
            'conductor_id': ids[1],
            'ultimo_mensaje': '📷 Imagen adjunta', // Texto de previsualización
            'timestamp': FieldValue.serverTimestamp(),
            'expira_el': DateTime.now().add(const Duration(days: 7))
          }, SetOptions(merge: true));
        }
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
    } finally {
      if (mounted) setState(() => _subiendoImagen = false);
    }
  }

  // BOTÓN YUMMY (Fallback a WhatsApp)
  Future<void> _abrirWhatsAppSOS() async {
    String cleanedPhone = widget.tallerPhone.replaceAll(RegExp(r'\D'), '');
    if (!cleanedPhone.startsWith('58')) cleanedPhone = '58$cleanedPhone';

    String prefijo = widget.modo == ChatMode.sos ? "🚨 URGENTE (Geocar SOS): " : "Hola (Geocar): ";
    var url = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(prefijo)}";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Alto del BottomSheet
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              children: [
                Icon(widget.modo == ChatMode.sos ? Icons.warning_amber_rounded : Icons.support_agent_rounded,
                    color: widget.modo == ChatMode.sos ? Colors.red : Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.modo == ChatMode.sos ? "Sala de Rescate" : "Contacto Taller",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                // EL BOTÓN YUMMY
                TextButton.icon(
                  onPressed: _abrirWhatsAppSOS,
                  icon: const Icon(Icons.wechat_rounded, color: Colors.green),
                  label: Text("WhatsApp", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),

          // ZONA DE MENSAJES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _mensajesRef.orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var mensajes = snapshot.data!.docs;

                if (mensajes.isEmpty) return Center(child: Text("Envía un mensaje para iniciar", style: GoogleFonts.poppins(color: Colors.grey)));

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    var msg = mensajes[index].data() as Map<String, dynamic>;
                    bool soyYo = msg['sender_id'] == _miUid;

                    return Align(
                      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: soyYo ? Colors.blue.shade600 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: soyYo ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: soyYo ? const Radius.circular(16) : const Radius.circular(0),
                          ),
                        ),
                        // Renderizado condicional: Texto vs Imagen
                        child: msg['tipo'] == 'imagen'
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            msg['contenido'],
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                  width: 200, height: 200,
                                  child: Center(child: CircularProgressIndicator())
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white),
                          ),
                        )
                            : Text(
                            msg['contenido'] ?? '',
                            style: GoogleFonts.poppins(color: soyYo ? Colors.white : Colors.black87)
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Row(
                children: [
                  // Botón de Cámara con estado de carga
                  _subiendoImagen
                      ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                      : IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.blueGrey),
                    onPressed: _enviarImagen,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: "Mensaje...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade600,
                    child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _enviarMensaje),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}