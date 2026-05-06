import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// IMPORTANTE: Ajusta esta ruta a donde tengas tu UniversalChatSheet
import '../widgets/chat/universal_chat_sheet.dart';

class ChatInboxScreen extends StatelessWidget {
  final String miRol; // 'taller' o 'conductor'

  const ChatInboxScreen({super.key, required this.miRol});

  @override
  Widget build(BuildContext context) {
    final String miUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    // Determinamos qué campo filtrar según nuestro rol
    final String campoFiltro = miRol == 'taller' ? 'taller_id' : 'conductor_id';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Mensajes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Buscamos los chats donde yo sea el participante
        stream: FirebaseFirestore.instance
            .collection('chats_directos')
            .where(campoFiltro, isEqualTo: miUid)
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

          // Ordenamos los documentos en memoria por fecha (del más reciente al más antiguo)
          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp tA = (a.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            Timestamp tB = (b.data() as Map<String, dynamic>)['timestamp'] ?? Timestamp.now();
            return tB.compareTo(tA);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              var chatData = docs[index].data() as Map<String, dynamic>;
              String chatId = docs[index].id;

              // Extraemos el ID del otro participante
              String otroUid = miRol == 'taller' ? chatData['conductor_id'] : chatData['taller_id'];
              String ultimoMensaje = chatData['ultimo_mensaje'] ?? 'Chat iniciado';
              Timestamp timestamp = chatData['timestamp'] ?? Timestamp.now();
              String hora = DateFormat('hh:mm a').format(timestamp.toDate());

              return FutureBuilder<DocumentSnapshot>(
                // Buscamos el perfil de la otra persona para mostrar su nombre
                future: FirebaseFirestore.instance.collection(miRol == 'taller' ? 'usuarios' : 'talleres').doc(otroUid).get(),
                builder: (context, userSnapshot) {
                  String nombreMostrar = "Cargando...";
                  String telefonoOtro = "";

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    nombreMostrar = userData['nombre'] ?? (miRol == 'taller' ? 'Conductor' : 'Taller');
                    telefonoOtro = userData['telefono'] ?? '';
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                      child: Icon(miRol == 'taller' ? Icons.person : Icons.storefront, color: colorScheme.primary),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            nombreMostrar,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(hora, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Text(
                      ultimoMensaje,
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // EL GATILLO: Abrimos el chat modal directamente desde la lista
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