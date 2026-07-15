import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// IMPORTANTE: Asegúrate de que esta ruta apunte a tu UniversalChatSheet
import '../widgets/chat/universal_chat_sheet.dart';
// (Si tu carpeta widgets está en lib/widgets, usa esta ruta:)
// import 'package:geocar/widgets/chat/universal_chat_sheet.dart';

class ChatInboxScreen extends StatelessWidget {
  final String miRol; // 'taller' o 'conductor'

  const ChatInboxScreen({super.key, required this.miRol});

  @override
  Widget build(BuildContext context) {
    final String miUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    // Filtros dinámicos basados en el rol
    final String campoFiltroId = miRol == 'taller' ? 'taller_id' : 'conductor_id';
    final String campoLeidoStatus = miRol == 'taller' ? 'leido_por_taller' : 'leido_por_conductor';
    final String coleccionOpuesta = miRol == 'taller' ? 'usuarios' : 'talleres';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Mensajes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats_directos')
            .where(campoFiltroId, isEqualTo: miUid)
        // Se quitó el orderBy porque Firestore requiere índice compuesto cuando se usa where + orderBy. Lo ordenamos en memoria.
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("No tienes mensajes activos", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          // Ordenamiento en memoria por fecha (del más reciente al más antiguo)
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp tA = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            Timestamp tB = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            return tB.compareTo(tA);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade100, height: 24),
            itemBuilder: (context, index) {
              var chatData = docs[index].data() as Map<String, dynamic>;
              String chatId = docs[index].id;

              String otroUid = miRol == 'taller' ? chatData['conductor_id'] : chatData['taller_id'];
              String ultimoMensaje = chatData['ultimo_mensaje'] ?? 'Chat iniciado';
              Timestamp timestamp = chatData['timestamp'] ?? Timestamp.now();
              String hora = DateFormat('hh:mm a').format(timestamp.toDate());

              // Verificamos si este mensaje no ha sido leído por mí
              bool noLeido = !(chatData[campoLeidoStatus] ?? true);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection(coleccionOpuesta).doc(otroUid).get(),
                builder: (context, userSnapshot) {
                  String nombreMostrar = "Usuario de Geocar";
                  String telefonoOtro = "";
                  String? photoUrl; // Soporte para foto de perfil en el chat

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    nombreMostrar = userData['nombre'] ?? (miRol == 'taller' ? 'Conductor' : 'Taller');
                    telefonoOtro = userData['telefono'] ?? '';
                    photoUrl = userData['photoUrl']; // Extraemos la foto
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    // Avatar Dinámico (Foto o Ícono)
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Icon(miRol == 'taller' ? Icons.person : Icons.storefront, color: colorScheme.primary)
                          : null,
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nombreMostrar,
                            style: GoogleFonts.poppins(
                                fontWeight: noLeido ? FontWeight.bold : FontWeight.w600, // Negrita si no leído
                                fontSize: 16,
                                color: colorScheme.onSurface
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Hora y Badge de No Leído
                        Row(
                          children: [
                            if (noLeido)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              ),
                            Text(
                                hora,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: noLeido ? colorScheme.primary : Colors.grey.shade500,
                                    fontWeight: noLeido ? FontWeight.bold : FontWeight.normal
                                )
                            ),
                          ],
                        ),
                      ],
                    ),
                    subtitle: Text(
                      ultimoMensaje,
                      style: GoogleFonts.poppins(
                          color: noLeido ? colorScheme.onSurface : Colors.grey.shade600,
                          fontWeight: noLeido ? FontWeight.w600 : FontWeight.normal // Negrita si no leído
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // 1. Marcar como leído en UI y BD al abrir
                      FirebaseFirestore.instance.collection('chats_directos').doc(chatId).update({
                        campoLeidoStatus: true
                      });

                      // 2. Abrir el modal del chat
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: UniversalChatSheet(
                            modo: ChatMode.directo,
                            referenceId: chatId,
                            tallerPhone: miRol == 'conductor' ? telefonoOtro : '',
                            miRol: miRol,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}