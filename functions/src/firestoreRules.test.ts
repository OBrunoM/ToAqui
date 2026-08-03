import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

// This suite exercises `firestore.rules` directly against the Firestore
// emulator using `@firebase/rules-unit-testing`. It is intentionally
// self-contained and does not share setup with
// `resolveRecipientTokens.test.ts` (which uses `firebase-functions-test` +
// the Admin SDK, and therefore bypasses security rules entirely).
describe("firestore.rules", () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    // Host/port are deliberately omitted: `@firebase/rules-unit-testing`
    // auto-discovers the running emulator from the
    // `FIRESTORE_EMULATOR_HOST` env var, which `firebase emulators:exec`
    // sets to whatever port it actually bound (the same mechanism
    // `resolveRecipientTokens.test.ts` relies on for the Admin SDK).
    // Hardcoding a port here would break if the emulator picks a
    // different one.
    testEnv = await initializeTestEnvironment({
      projectId: "toaqui-rules-test",
      firestore: {
        rules: fs.readFileSync(
          path.resolve(__dirname, "../../firestore.rules"),
          "utf8"
        ),
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  afterEach(async () => {
    await testEnv.clearFirestore();
  });

  it(
    "allows getting a specific invite by code, but not listing " +
      "the invites collection",
    async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection("invites")
          .doc("CODE01")
          .set({
            ownerUid: "A",
            contactId: "c1",
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
            used: false,
          });
      });

      const bob = testEnv.authenticatedContext("B").firestore();

      await assertSucceeds(bob.collection("invites").doc("CODE01").get());
      await assertFails(bob.collection("invites").get());
    }
  );

  it(
    "does not let a user link a stranger's pending contact to a " +
      "third uid, but does let them link it to their own uid",
    async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection("users")
          .doc("A")
          .collection("contacts")
          .doc("contact1")
          .set({
            name: "Mãe",
            relationship: "Mãe",
            linkedUid: null,
            inviteCode: "CODE01",
          });
      });

      const bob = testEnv.authenticatedContext("B").firestore();
      const contactRef = bob
        .collection("users")
        .doc("A")
        .collection("contacts")
        .doc("contact1");

      // B cannot hijack the contact by pointing it at some other uid
      // (C) that B harvested from an invite code.
      await assertFails(contactRef.update({linkedUid: "C"}));

      // B CAN link the contact to their own uid — this is the
      // legitimate invite-redemption path.
      await assertSucceeds(contactRef.update({linkedUid: "B"}));
    }
  );

  it(
    "does not let a user create their own contact pre-linked to " +
      "someone else's uid",
    async () => {
      const bob = testEnv.authenticatedContext("B").firestore();
      const ownContact = bob
        .collection("users")
        .doc("B")
        .collection("contacts")
        .doc("c1");

      await assertFails(
        ownContact.set({
          name: "Spoofed",
          relationship: "Familiar",
          linkedUid: "victim-uid",
          inviteCode: null,
        })
      );

      await assertSucceeds(
        ownContact.set({
          name: "Real contact",
          relationship: "Familiar",
          linkedUid: null,
          inviteCode: null,
        })
      );
    }
  );

  it(
    "does not let a user read another user's profile or locations",
    async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("users").doc("A").set({
          fcmToken: "token-a",
          createdAt: new Date(),
        });
        await context
          .firestore()
          .collection("users")
          .doc("A")
          .collection("locations")
          .doc("loc1")
          .set({name: "Casa"});
      });

      const bob = testEnv.authenticatedContext("B").firestore();

      await assertFails(bob.collection("users").doc("A").get());
      await assertFails(
        bob
          .collection("users")
          .doc("A")
          .collection("locations")
          .doc("loc1")
          .get()
      );
    }
  );

  it(
    "does not let a user read another user's arrival document",
    async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("arrivals").doc("arrival1").set({
          ownerUid: "A",
          locationId: "loc1",
          message: "Chegou em casa",
          createdAt: new Date(),
        });
      });

      const bob = testEnv.authenticatedContext("B").firestore();

      await assertFails(bob.collection("arrivals").doc("arrival1").get());
    }
  );
});
