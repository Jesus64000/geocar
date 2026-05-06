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
  }

  static Future<void> guardarTokenEnFirestore(String token) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Intentamos actualizar en talleres, si no, lo guardamos en un lugar central
      try {
        await FirebaseFirestore.instance.collection('talleres').doc(user.uid).set({
          'fcm_token': token,
          'ultimo_acceso': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error guardando FCM Token: $e");
      }
    }
  }
}