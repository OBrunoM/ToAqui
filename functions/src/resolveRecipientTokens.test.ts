import * as admin from "firebase-admin";
import {resolveRecipientTokens} from "./resolveRecipientTokens";

describe("resolveRecipientTokens", () => {
  let app: admin.app.App;

  beforeAll(() => {
    process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
    app = admin.initializeApp({projectId: "toaqui-test"});
  });

  afterAll(async () => {
    await app.delete();
  });

  it(
    "returns tokens only for contacts that have a linkedUid " +
      "and a saved fcmToken",
    async () => {
      const db = admin.firestore();

      const contacts = db
        .collection("users")
        .doc("owner-uid")
        .collection("contacts");
      await contacts.doc("c1").set({
        name: "Mãe",
        relationship: "Mãe",
        linkedUid: "family-1",
      });
      await contacts.doc("c2").set({
        name: "Amor",
        relationship: "Parceiro(a)",
        linkedUid: null,
      });
      await db
        .collection("users")
        .doc("family-1")
        .set({fcmToken: "token-abc"});

      const tokens = await resolveRecipientTokens(db, "owner-uid");

      expect(tokens).toEqual(["token-abc"]);
    }
  );

  it("returns an empty array when the owner has no contacts", async () => {
    const db = admin.firestore();
    const tokens = await resolveRecipientTokens(db, "nobody-uid");
    expect(tokens).toEqual([]);
  });
});
