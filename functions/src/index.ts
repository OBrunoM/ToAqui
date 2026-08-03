import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {resolveRecipientTokens} from "./resolveRecipientTokens";

initializeApp();

export const onArrivalCreated = onDocumentCreated(
  {document: "arrivals/{arrivalId}", region: "southamerica-east1"},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const {ownerUid, message} = snap.data() as {
      ownerUid: string;
      message: string;
    };
    const db = getFirestore();
    const tokens = await resolveRecipientTokens(db, ownerUid);

    if (tokens.length === 0) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "ToAqui",
        body: message,
      },
    });
  }
);

export const onEmergencyCreated = onDocumentCreated(
  {document: "emergencies/{emergencyId}", region: "southamerica-east1"},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const {ownerUid, latitude, longitude} = snap.data() as {
      ownerUid: string;
      latitude?: number;
      longitude?: number;
    };
    const db = getFirestore();
    const tokens = await resolveRecipientTokens(db, ownerUid);

    if (tokens.length === 0) return;

    const mapLink =
      latitude !== undefined && longitude !== undefined ?
        ` https://maps.google.com/?q=${latitude},${longitude}` :
        "";

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "🆘 ToAqui — Alerta de emergência",
        body:
          "Uma pessoa da sua família apertou o botão de emergência." +
          mapLink,
      },
      android: {priority: "high"},
    });
  }
);
