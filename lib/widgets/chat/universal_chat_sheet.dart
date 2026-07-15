import 'dart:io';
import 'dart:async';
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

  // Lógica de grabación de audio
  bool _estaGrabando = false;
  int _segundosGrabados = 0;
  Timer? _grabacionTimer;

  @override
  void initState() {
    super.initState();
    _marcarComoLeido(); // Ejecuta la limpieza de notificaciones al entrar
    _msgController.addListener(_actualizarUI);
  }

  void _actualizarUI() {
    if (mounted) setState(() {});
  }

  // NUEVO: Función para apagar el punto rojo
  Future<void> _marcarComoLeido() async {
    final String campoLeido = widget.miRol == 'conductor' ? 'leido_por_conductor' : 'leido_por_taller';

    // Marcamos el documento padre como leído
    await FirebaseFirestore.instance
        .collection('chats_directos')
        .doc(widget.referenceId)
        .update({campoLeido: true});
  }

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

    // 2. CRÍTICO: Actualizar el Documento Padre y ACTIVAR NOTIFICACIÓN
    if (widget.modo == ChatMode.directo) {
      List<String> ids = widget.referenceId.split('_');
      if (ids.length == 2) {
        await FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).set({
          'taller_id': ids[0],
          'conductor_id': ids[1],
          'ultimo_mensaje': texto,
          'timestamp': FieldValue.serverTimestamp(),
          'leido_por_conductor': widget.miRol == 'conductor', // Si yo envío, yo ya lo leí
          'leido_por_taller': widget.miRol == 'taller',       // Si yo envío, yo ya lo leí
          'expira_el': DateTime.now().add(const Duration(days: 7))
        }, SetOptions(merge: true));
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

      // 2. CRÍTICO: Actualizar el Documento Padre y ACTIVAR NOTIFICACIÓN
      if (widget.modo == ChatMode.directo) {
        List<String> ids = widget.referenceId.split('_');
        if (ids.length == 2) {
          await FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).set({
            'taller_id': ids[0],
            'conductor_id': ids[1],
            'timestamp': FieldValue.serverTimestamp(),
            'leido_por_conductor': widget.miRol == 'conductor', // Si yo envío, yo ya lo leí
            'leido_por_taller': widget.miRol == 'taller',       // Si yo envío, yo ya lo leí
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

  // --- NUEVA LÓGICA DE GRABACIÓN ---
  void _iniciarGrabacion() {
    setState(() {
      _estaGrabando = true;
      _segundosGrabados = 0;
    });
    _grabacionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _segundosGrabados++;
      });
    });
  }

  void _cancelarGrabacion() {
    _grabacionTimer?.cancel();
    setState(() {
      _estaGrabando = false;
      _segundosGrabados = 0;
    });
  }

  Future<void> _finalizarYEnviarGrabacion() async {
    _grabacionTimer?.cancel();
    if (_segundosGrabados < 1) {
      _cancelarGrabacion();
      return;
    }

    final duracionStr = "${_segundosGrabados ~/ 60}:${(_segundosGrabados % 60).toString().padLeft(2, '0')}";
    setState(() {
      _estaGrabando = false;
      _subiendoImagen = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 800));
      const mockAudioUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";

      Map<String, dynamic> payload = {
        'sender_id': _miUid,
        'sender_rol': widget.miRol,
        'tipo': 'audio',
        'contenido': mockAudioUrl,
        'duracion': duracionStr,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (widget.modo == ChatMode.directo) {
        payload['expira_el'] = DateTime.now().add(const Duration(days: 7));
      }

      await _mensajesRef.add(payload);

      if (widget.modo == ChatMode.directo) {
        List<String> ids = widget.referenceId.split('_');
        if (ids.length == 2) {
          await FirebaseFirestore.instance.collection('chats_directos').doc(widget.referenceId).set({
            'taller_id': ids[0],
            'conductor_id': ids[1],
            'ultimo_mensaje': "🎵 Nota de voz ($duracionStr)",
            'timestamp': FieldValue.serverTimestamp(),
            'leido_por_conductor': widget.miRol == 'conductor',
            'leido_por_taller': widget.miRol == 'taller',
            'expira_el': DateTime.now().add(const Duration(days: 7))
          }, SetOptions(merge: true));
        }
      }

      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar audio: $e')));
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final totalHeight = MediaQuery.of(context).size.height * 0.75;
    final sheetHeight = (totalHeight - viewInsets).clamp(300.0, totalHeight);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Icon(
                  widget.modo == ChatMode.sos ? Icons.warning_amber_rounded : Icons.support_agent_rounded,
                  color: widget.modo == ChatMode.sos ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.modo == ChatMode.sos ? "Sala de Rescate" : "Contacto Taller",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                // EL BOTÓN YUMMY
                TextButton.icon(
                  onPressed: _abrirWhatsAppSOS,
                  icon: const Icon(Icons.wechat_rounded, color: Colors.green),
                  label: Text("WhatsApp", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                )
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

                if (mensajes.isEmpty) {
                  return Center(
                    child: Text(
                      "Envía un mensaje para iniciar",
                      style: GoogleFonts.poppins(color: isDark ? Colors.grey.shade500 : Colors.grey),
                    ),
                  );
                }

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
                          color: soyYo
                              ? const Color(0xFF3B82F6)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: soyYo ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: soyYo ? const Radius.circular(16) : const Radius.circular(0),
                          ),
                        ),
                        // Renderizado condicional: Texto vs Imagen vs Audio
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
                            : (msg['tipo'] == 'audio'
                                ? AudioPlayBubble(
                                    audioUrl: msg['contenido'] ?? '',
                                    duracion: msg['duracion'] ?? '0:05',
                                    soyYo: soyYo,
                                  )
                                : Text(
                                    msg['contenido'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: soyYo ? Colors.white : colorScheme.onSurface,
                                    ),
                                  )),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // INPUT AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
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
                    icon: Icon(Icons.camera_alt_rounded, color: colorScheme.onSurface.withOpacity(0.6)),
                    onPressed: _enviarImagen,
                  ),
                  _estaGrabando
                      ? Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Grabando... ${_segundosGrabados ~/ 60}:${(_segundosGrabados % 60).toString().padLeft(2, '0')}",
                                  style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _cancelarGrabacion,
                                  child: Text(
                                    "Cancelar",
                                    style: GoogleFonts.poppins(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Expanded(
                          child: TextField(
                            controller: _msgController,
                            style: GoogleFonts.poppins(color: colorScheme.onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Mensaje...",
                              hintStyle: GoogleFonts.poppins(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 14),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _estaGrabando ? Colors.redAccent : colorScheme.primary,
                    child: _estaGrabando
                        ? IconButton(
                            icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                            onPressed: _finalizarYEnviarGrabacion,
                          )
                        : IconButton(
                            icon: Icon(
                              _msgController.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _msgController.text.trim().isEmpty ? _iniciarGrabacion : _enviarMensaje,
                          ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _grabacionTimer?.cancel();
    _msgController.removeListener(_actualizarUI);
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// =========================================================================
// WIDGET INTERACTIVO DE PLAYBACK DE AUDIO EN CHAT
// =========================================================================
class AudioPlayBubble extends StatefulWidget {
  final String audioUrl;
  final String duracion;
  final bool soyYo;

  const AudioPlayBubble({
    super.key,
    required this.audioUrl,
    required this.duracion,
    required this.soyYo,
  });

  @override
  State<AudioPlayBubble> createState() => _AudioPlayBubbleState();
}

class _AudioPlayBubbleState extends State<AudioPlayBubble> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  Timer? _playbackTimer;
  late int _totalDurationSeconds;

  @override
  void initState() {
    super.initState();
    final parts = widget.duracion.split(':');
    if (parts.length == 2) {
      _totalDurationSeconds = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    } else {
      _totalDurationSeconds = 5;
    }
    if (_totalDurationSeconds == 0) _totalDurationSeconds = 5;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    setState(() {
      _isPlaying = true;
    });

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _playbackProgress += 0.1 / _totalDurationSeconds;
        if (_playbackProgress >= 1.0) {
          _playbackProgress = 0.0;
          _isPlaying = false;
          _playbackTimer?.cancel();
        }
      });
    });
  }

  void _pause() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = widget.soyYo ? Colors.white : colorScheme.onSurface;
    final iconColor = widget.soyYo ? Colors.white : colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            size: 38,
            color: iconColor,
          ),
          onPressed: _togglePlay,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _playbackProgress,
                  backgroundColor: widget.soyYo ? Colors.white30 : (Theme.of(context).brightness == Brightness.dark ? Colors.white12 : Colors.black12),
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Nota de voz",
                    style: GoogleFonts.poppins(fontSize: 10, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    widget.duracion,
                    style: GoogleFonts.poppins(fontSize: 10, color: textColor.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}