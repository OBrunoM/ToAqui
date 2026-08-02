import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {resolveRecipientTokens} from "./resolveRecipientTokens";

initializeApp();

export const onArrivalCreated = onDocumentCreated(
  "arrivals/{arrivalId}",
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
