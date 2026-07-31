# ToAqui — Emergency Alert Button

**Date:** 2026-07-30
**Status:** Approved

## Context

This builds directly on `2026-07-30-family-invite-notifications-design.md` (Leva A), which gives every user an anonymous account, a way to link family members via invite code, and a working FCM push pipeline triggered by a Firestore document write. This spec reuses that exact pipeline for a second, more urgent purpose: a manual "I need help" button that alerts every linked family member immediately, with the user's current location if available.

Leva A's own Task 10 (the Cloud Function that actually sends pushes) is still blocked on the human partner completing Firebase's Blaze-plan setup (Task 1). This spec's Cloud Function work inherits that same blocker — the client-side pieces (repository, hold-to-confirm UI, location permission) do not.

## Goals

- A prominent, hard-to-trigger-by-accident button on the Home screen that, once held for ~3 seconds, sends an alert to every linked family member (all of them — no per-alert recipient picker).
- The alert includes the user's current location (a single foreground GPS read, not background tracking) when it can be obtained quickly; it is sent without location rather than delayed or blocked if location isn't available.
- Fixed, non-customizable alert message — no time to type during a real emergency.
- Reuses the family-invite pipeline's "resolve linked contacts → send FCM" logic rather than duplicating it.

## Non-Goals

- No SMS/phone-call fallback channel (same cost-driven decision as Leva A).
- No background location tracking or real geofencing (that's Leva B, unrelated to this feature).
- No customizable message text.
- No per-alert recipient selection — always all linked contacts.
- No "undo/cancel after sending" window.
- No retry/resend UI beyond a plain error message if the write itself fails.

## Architecture

- **Firestore:** new top-level collection `emergencies/{id}` — `{ ownerUid, latitude, longitude, createdAt }`. `latitude`/`longitude` are nullable (omitted entirely from the write when a location couldn't be obtained in time).
- **Client:** `EmergencyRepository.recordEmergency({required String ownerUid, double? latitude, double? longitude})`, mirroring `ArrivalRepository`'s shape (Leva A, Task 9) — a thin Firestore `.add()` call.
- **Location read:** a one-off `Geolocator.getCurrentPosition()` call, gated by `Geolocator.checkPermission()`/`requestPermission()` for **foreground ("when in use")** access only — materially simpler than Leva B's future background/"always" permission flow. Wrapped in a short timeout (5 seconds); on denial, error, or timeout, proceed to send the alert with `latitude`/`longitude` omitted rather than blocking or failing the send.
- **Cloud Function:** new `onEmergencyCreated`, Firestore-triggered on `emergencies/{id}` create. Reuses Leva A's `resolveRecipientTokens(db, ownerUid)` helper unchanged (same "which linked contacts should be notified" logic as arrivals) and sends a high-priority FCM push with a fixed title/body, appending a Google Maps link (`https://maps.google.com/?q={lat},{lng}`) to the body only when coordinates are present.
- **Android manifest:** needs `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` added — currently entirely absent from this app (flagged in the original visual-refresh review as a pre-existing gap). Scoped narrowly to what this feature needs; background/"always" location permission remains out of scope (Leva B).

## UI / Interaction

- A coral-accented button on the Home screen (placement: prominent, near the top, below or alongside the existing status card — exact layout is an implementation detail for the plan, not a design decision needing further sign-off).
- **Hold-to-confirm:** press and hold for 3 seconds, with a visible filling/progress indicator during the hold so the user can see it registering. Releasing before 3 seconds cancels with no alert sent and no side effect.
- **Pre-check:** if the user has zero linked contacts (accepted invites) when they press the button, show that fact before or instead of a "no recipients" alert that would silently reach nobody — e.g. a short message directing them to the Família tab first.
- **Confirmation:** on successful send, show a clear, hard-to-miss confirmation (a dialog, not a transient snackbar, given the stakes) stating the alert was sent, to how many people it went, and whether location was included.
- **Failure:** if the Firestore write itself fails (network/permission error), show `AppSnackbar.showError` with a message the user can act on (try again).

## Data Flow

1. User holds the emergency button for 3 seconds.
2. App checks/requests foreground location permission if not already granted.
3. App attempts `Geolocator.getCurrentPosition()` with a 5-second timeout.
4. App calls `EmergencyRepository.recordEmergency(...)` — with coordinates if step 3 succeeded in time, without them otherwise.
5. `onEmergencyCreated` Cloud Function fires, resolves linked contacts via the shared `resolveRecipientTokens`, sends the push (with or without the map link, matching whether coordinates were present).
6. Family member's device shows the high-priority push.

## Error Handling

- Location permission denied / GPS timeout / GPS error → alert still sends, without coordinates. Never blocks or fails the send because of location.
- Zero linked contacts → warn the user before/instead of sending (see Pre-check above), rather than silently succeeding with nobody notified.
- Firestore write failure → `AppSnackbar.showError`, user can try holding the button again.
- No contacts have a saved `fcmToken` yet → Cloud Function sends to zero recipients silently (same accepted limitation as Leva A's arrival pipeline) — not surfaced to the sender in this pass.

## Testing

- `EmergencyRepository` — unit test via `fake_cloud_firestore`, mirroring `ArrivalRepository`'s test, covering both the with-location and without-location (fields omitted) write shapes.
- Hold-to-confirm gesture — widget test simulating a long-press/hold shorter than 3 seconds (verifies no repository call) and one at/over 3 seconds (verifies exactly one call).
- Zero-linked-contacts pre-check — widget test verifying the warning path when `contactsStreamProvider` resolves to an empty or all-unlinked list.
- Location permission denied / timeout path — widget test with an injectable location-fetch seam returning `null`, confirming the repository is still called with no coordinates.
- Cloud Function (`onEmergencyCreated`) — tested against the Firebase Local Emulator Suite, same pattern as `onArrivalCreated`: seed linked contacts + tokens, trigger via a Firestore write, assert the resolved token list and the constructed message body (with and without a map link).
- No test hits a live Firebase project or a live device GPS.
