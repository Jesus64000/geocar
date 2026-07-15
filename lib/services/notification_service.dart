import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';

// Función global requerida para manejar mensajes en segundo plano
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Mensaje recibido en segundo plano: ${message.messageId}');
  // Aquí se podría guardar localmente el estado de la notificación
}

class NotificationService {
  NotificationService._privateConstructor();

  static final NotificationService instance = NotificationService._privateConstructor();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      // 1. Solicitar permisos de notificación (esencial para iOS y Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      developer.log('Permisos de notificaciones concedidos: ${settings.authorizationStatus}');

      // 2. Obtener el token único del dispositivo
      String? token = await _fcm.getToken();
      developer.log('FCM Token de GeoCar: $token');

      // 3. Configurar el manejador de mensajes en segundo plano/terminado
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Escuchar mensajes en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log('Mensaje recibido en primer plano: ${message.notification?.title}');
        // Aquí podríamos disparar alertas internas o banners de UI locales
      });

      // 5. Manejar clicks en notificaciones cuando la app está abierta en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log('App abierta desde una notificación: ${message.data}');
      });

      _inicializado = true;
    } catch (e) {
      developer.log('Error al inicializar NotificationService: $e');
    }
  }
}
