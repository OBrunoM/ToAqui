import {Firestore} from "firebase-admin/firestore";

/**
 * Resolves the FCM tokens for the linked contacts of an owner.
 *
 * Reads the owner's `contacts` subcollection, and for each contact that
 * has a `linkedUid`, looks up that user's saved `fcmToken`.
 *
 * @param {Firestore} db - The Firestore instance to read from.
 * @param {string} ownerUid - The uid of the user whose contacts to resolve.
 * @return {Promise<string[]>} The list of resolved FCM tokens.
 */
export async function resolveRecipientTokens(
  db: Firestore,
  ownerUid: string
): Promise<string[]> {
  const contactsSnap = await db
    .collection("users")
    .doc(ownerUid)
    .collection("contacts")
    .get();

  const tokens: string[] = [];
  for (const contactDoc of contactsSnap.docs) {
    const linkedUid = contactDoc.data().linkedUid as string | null | undefined;
    if (!linkedUid) continue;

    const userDoc = await db.collection("users").doc(linkedUid).get();
    const token = userDoc.data()?.fcmToken as string | undefined;
    if (token) tokens.push(token);
  }

  return tokens;
}
