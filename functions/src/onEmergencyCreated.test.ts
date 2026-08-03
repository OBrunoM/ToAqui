import * as admin from "firebase-admin";
import {resolveRecipientTokens} from "./resolveRecipientTokens";

describe("emergency notification payload", () => {
  let app: admin.app.App;

  beforeAll(() => {
    app = admin.initializeApp({projectId: "toaqui-test-emergency"});
  });

  afterAll(async () => {
    await app.delete();
  });

  it("resolves the same linked-contact tokens as arrivals do", async () => {
    const db = admin.firestore();

    const contactRef = db
      .collection("users")
      .doc("owner-uid")
      .collection("contacts")
      .doc("c1");
    await contactRef.set({
      name: "Mãe",
      relationship: "Mãe",
      linkedUid: "family-1",
    });
    await db.collection("users").doc("family-1").set({fcmToken: "token-abc"});

    const tokens = await resolveRecipientTokens(db, "owner-uid");

    expect(tokens).toEqual(["token-abc"]);
  });
});
