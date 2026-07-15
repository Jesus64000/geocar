import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Este método DEBE estar fuera de cualquier clase para funcionar en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Manejando mensaje en segundo plano: ${message.messageId}");
  // Aquí podríamos reproducir un sonido de sirena custom en el futuro
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> inicializar() async {
    try {
      // 1. Pedir permisos al usuario (Obligatorio en iOS y Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Permisos de Notificación Concedidos');

        // 2. Obtener el Token del dispositivo
        String? token = await _messaging.getToken();
        if (token != null) {
          await guardarTokenEnFirestore(token);
        }

        // 3. Escuchar si el token cambia (por reinstalación o seguridad)
        _messaging.onTokenRefresh.listen(guardarTokenEnFirestore);

        // 4. Configurar el manejador de Background
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // 5. Escuchar notificaciones con la app abierta (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Notificación recibida en primer plano: ${message.notification?.title}');
          // NOTA: Como la app está abierta, el Radar SOS del Dashboard ya hace el trabajo visual.
          // Pero el teléfono de todos modos sonará/vibrará gracias a este listener.
        });

      } else {
        debugPrint('El usuario denegó los permisos de notificación');
      }
    } catch (e) {
      debugPrint('Error inicializando servicio de notificaciones FCM: $e');
      // No re-lanzamos el error para evitar que la app crasheé en el arranque
    }
  }

  static Future<void> guardarTokenEnFirestore(String token) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Intentamos en talleres primero
      final docTaller = await FirebaseFirestore.instance.collection('talleres').doc(user.uid).get();
      if (docTaller.exists) {
        await FirebaseFirestore.instance.collection('talleres').doc(user.uid).update({
          'fcm_token': token,
          'ultimo_acceso': FieldValue.serverTimestamp(),
        });
        return;
      }

      // Si no existe, guardamos en usuarios (conductor)
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (docUsuario.exists) {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'fcm_token': token,
          'ultimo_acceso': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error guardando FCM Token en Firestore: $e");
    }
  }
}