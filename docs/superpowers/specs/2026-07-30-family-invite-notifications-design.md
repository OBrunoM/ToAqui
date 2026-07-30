# ToAqui — Family Invite & Arrival Push Notifications (Leva A)

**Date:** 2026-07-30
**Status:** Approved

## Context

The visual refresh (see `2026-07-29-visual-refresh-design.md`) made every screen look and feel real, but the app has no working backend: Firebase is fully commented out, locations/contacts live only in in-memory Riverpod state, and the geofencing service that would detect an arrival is never started. Adding a "family member" today only stores a name and relationship locally — nothing is ever sent to anyone.

This spec covers the first of two follow-up levas that give the app a real backend:

- **Leva A (this spec):** accounts, an invite-code flow for linking a family member, and a working push-notification pipeline — triggered manually (a "Simular chegada" button) since real geofencing isn't wired up yet.
- **Leva B (future, separate spec):** replaces the manual trigger with real background geofencing and the Android/iOS location-permission flows.

Splitting this way keeps each spec reviewable and lets the notification pipeline be proven end-to-end before tackling background location permissions, which are a substantial platform-specific effort on their own.

## Goals

- Turn on Firebase for real: Firebase Auth (anonymous), Cloud Firestore, Firebase Cloud Messaging, and a Cloud Function.
- Let a user add a family member and generate a single-use, expiring invite code for them.
- Let the invited person install the app, join with zero login screens (anonymous auth), redeem the code, and become linked.
- When an arrival is (manually, for now) recorded for a location, push a notification containing that location's custom message to every linked, accepted family member.
- Keep the existing local screens' look and feel; swap their data source from local Riverpod state to Firestore-backed state without changing their UI contracts more than necessary.

## Non-Goals

- Real geofencing / background location detection (Leva B).
- Android/iOS background location permission flows (Leva B).
- Account recovery — anonymous auth is accepted as "lose the device, lose the link; redeem a new invite to relink."
- Revoking an accepted invite independently of deleting the contact entirely.
- Multiple devices per person.
- Any paid messaging channel (WhatsApp Business API, SMS) — explicitly rejected in favor of free push, per the cost discussion that led to this spec.

## Practical Note: Firebase Blaze Plan

Cloud Functions require Firebase's "Blaze" (pay-as-you-go) plan rather than the free "Spark" plan, even though the free monthly quota is the same. This means adding a billing card to the Firebase project. At this app's personal scale, expected cost is $0/month, but the account itself must be upgraded before Cloud Functions can be deployed.

## Architecture

- **Firebase Auth:** anonymous sign-in on first launch for every install — no login UI, no email/password, no phone verification.
- **Cloud Firestore** collections:
  - `users/{uid}` — `{ fcmToken, createdAt }`.
  - `users/{uid}/locations/{locationId}` — mirrors today's `LocationModel` (`name`, `latitude`, `longitude`, `radius`, `message`, `isActive`), now Firestore-backed instead of in-memory.
  - `users/{uid}/contacts/{contactId}` — mirrors today's `ContactModel` (`name`, `relationship`) plus `linkedUid` (null until the invite is redeemed) and `inviteCode`.
  - `invites/{code}` — `{ ownerUid, contactId, createdAt, expiresAt, used }`. 6-character alphanumeric code, single-use, expires after 24 hours.
  - `arrivals/{arrivalId}` — `{ ownerUid, locationId, message, createdAt }`, written when an arrival is recorded (manually triggered in this leva).
- **Cloud Function** (`onArrivalCreated`, Firestore trigger on `arrivals/{arrivalId}` create): reads the arrival, looks up the location owner's contacts where `linkedUid` is set, fetches each linked user's `fcmToken`, and sends an FCM push with the location's custom message. Missing/invalid tokens are skipped, not treated as errors.
- **Client (Flutter)**: `firebase_messaging` requests notification permission and stores the resulting token in `users/{uid}.fcmToken` on launch and on token refresh.

## Invite Flow

1. Owner adds a contact (name + relationship, same form as today) → app writes the contact doc and generates an `invites/{code}` doc tied to it, shown on screen for the owner to share however they like (WhatsApp, SMS, in person — outside the app, no cost to ToAqui).
2. Family member installs the app, is anonymously signed in automatically, and finds a "Tenho um convite" entry point where they type the code.
3. App validates the code (`invites/{code}`: exists, not `used`, not expired) against Firestore, sets `contacts/{contactId}.linkedUid` to the redeemer's uid, marks the invite `used: true`.
4. Deleting a contact clears `linkedUid` implicitly (the contact doc is gone), stopping further notifications to that person.

## Notification Flow

1. Owner taps a temporary "Simular chegada" action on a location (stands in for Leva B's real geofence trigger).
2. Client writes an `arrivals` doc.
3. `onArrivalCreated` Cloud Function fires, resolves linked+accepted contacts for that location's owner, sends FCM push with the location's `message` to each.
4. Family member's device shows the push (foreground or background) via `firebase_messaging`; tapping it simply opens the app in this leva — no deep link into a specific screen yet.

## Error Handling

- Invalid/expired/already-used invite code → clear inline error, reusing `AppSnackbar.showError`.
- Linked contact with no `fcmToken` yet (notifications not yet granted, or app not fully initialized) → Cloud Function skips that recipient silently; not surfaced to the owner in this leva (documented limitation).
- Firestore write failures when saving a location/contact → `AppSnackbar.showError`.

## Testing

This leva introduces real cloud infrastructure, which changes the testing approach from the purely local, widget-test-only style of the visual refresh:

- **Cloud Function logic** (`onArrivalCreated`): tested against the **Firebase Local Emulator Suite** (Firestore + Functions emulators), not a live project.
- **Client code that touches Firebase** (invite redemption, contact/location repositories): widget/unit tests using `fake_cloud_firestore` and `firebase_auth_mocks` (or equivalent) rather than a real Firebase project.
- **Existing widget tests** for screens (Locations, Contacts, Home) get updated to inject a fake Firestore-backed repository instead of the current in-memory `StateNotifier`, preserving the same assertions where the UI contract hasn't changed.
- No test depends on a live Firebase project or real push delivery — that's a manual verification step (send a real invite to a second test device/account) called out separately, similar to how the visual refresh's manual QA was called out.
