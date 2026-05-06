const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Inicializamos el SDK de Admin
admin.initializeApp();

exports.alertaNuevoSOS = onDocumentCreated("emergencias/{emergenciaId}", async (event) => {
    // En la v2, la data viene encapsulada dentro del objeto 'event'
    const snapshot = event.data;

    if (!snapshot) {
        console.log("No hay datos asociados al evento.");
        return;
    }

    const emergencia = snapshot.data();
    const emergenciaId = event.params.emergenciaId;

    // 1. Filtro de seguridad: Solo alertar si nace como "activa"
    if (emergencia.estado !== "activa") {
        console.log("Emergencia creada pero no activa. Ignorando.");
        return;
    }

    console.log(`SOS Detectado: ${emergenciaId}`);

    // 2. Buscar a todos los talleres que estén en turno (abiertos)
    const talleresSnapshot = await admin.firestore()
      .collection("talleres")
      .where("estado", "==", "abierto")
      .get();

    if (talleresSnapshot.empty) {
      console.log("CRÍTICO: No hay talleres abiertos para recibir el SOS.");
      return;
    }

    // 3. Recolectar los "FCM Tokens"
    const tokens = [];
    talleresSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.fcm_token) {
        tokens.push(data.fcm_token);
      }
    });

    if (tokens.length === 0) {
      console.log("Los talleres abiertos no tienen token de notificación registrado.");
      return;
    }

    // 4. Construir el misil (Payload de Notificación)
    const vehiculoInfo = emergencia.vehiculo || "vehículo";
    const payload = {
      notification: {
        title: "🚨 ¡NUEVO RESCATE DISPONIBLE!",
        body: `Un ${vehiculoInfo} necesita asistencia inmediata. Abre para aceptar.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        emergenciaId: emergenciaId,
        tipo: "SOS_NUEVO"
      }
    };

    // 5. Disparar el Push Multicast (Actualizado a sendEachForMulticast)
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: payload.notification,
        data: payload.data
      });
      console.log(`Push Multicast enviado. Éxitos: ${response.successCount}, Fallos: ${response.failureCount}`);
    } catch (error) {
      console.error("Error disparando el FCM:", error);
    }
});