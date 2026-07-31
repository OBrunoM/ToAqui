# ToAqui Emergency Alert Button — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Task 6 (Cloud Function) must NOT be dispatched until two things are both true: (a) `functions/` exists (Task 1 of the sibling `2026-07-30-family-invite-notifications-plan.md`), and (b) that same plan's Task 10 (`functions/src/resolveRecipientTokens.ts`, `functions/src/index.ts`) is merged. Everything else in this plan (Tasks 1-5, 7) has no such dependency and can run now.**

**Goal:** A hold-to-confirm emergency button on the Home screen that records the user's current location (best-effort, non-blocking) and triggers a high-priority push to every linked family member, reusing the family-invite pipeline's contact-resolution logic.

**Architecture:** A new `EmergencyRepository` (mirrors `ArrivalRepository`) writes to a new top-level `emergencies/` Firestore collection. A new `EmergencyButton` widget owns the hold-gesture, the best-effort location fetch, the zero-contacts pre-check, and the confirmation/error UI. A new Cloud Function `onEmergencyCreated` reuses the existing `resolveRecipientTokens` helper (from the sibling plan's Task 10) rather than reimplementing contact resolution.

**Tech Stack:** `geolocator` (already a dependency, currently unused elsewhere in the app), `fake_cloud_firestore` (already a dev dependency) for repository tests, plain Flutter `AnimationController`-driven hold gesture (no new package needed) for the button.

## Global Constraints

- Firestore layout (exact): `emergencies/{id}` — `ownerUid` (String), `latitude`/`longitude` (nullable double, omitted entirely from the write when unavailable), `createdAt` (`FieldValue.serverTimestamp()`).
- Location is a single foreground ("when in use") read with a 5-second timeout. It NEVER blocks or fails the alert send — on denial, error, or timeout, the alert sends with `latitude`/`longitude` omitted.
- Hold-to-confirm duration is 3 seconds in production; the widget accepts an injectable duration so tests can use a short one.
- Alert message is fixed text — no customization, no per-alert recipient picker, no SMS/phone fallback, no undo window (see spec's Non-Goals).
- The Cloud Function must call the existing `resolveRecipientTokens(db, ownerUid)` helper — do not reimplement contact-token resolution.
- No test may hit a live Firebase project or a real device's GPS.
- Spec reference: `docs/superpowers/specs/2026-07-30-emergency-alert-design.md`

---

### Task 1: `EmergencyRepository`

**Files:**
- Create: `lib/repositories/emergency_repository.dart`
- Test: `test/repositories/emergency_repository_test.dart`

**Interfaces:**
- Produces: `EmergencyRepository(FirebaseFirestore)` with `recordEmergency({required String ownerUid, double? latitude, double? longitude})` → `Future<void>`, writing to the top-level `emergencies` collection.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/emergency_repository.dart';

void main() {
  test('recordEmergency writes ownerUid, coordinates, and createdAt', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmergencyRepository(firestore);

    await repo.recordEmergency(ownerUid: 'owner-uid', latitude: -23.55, longitude: -46.63);

    final snapshot = await firestore.collection('emergencies').get();
    expect(snapshot.docs, hasLength(1));
    final data = snapshot.docs.single.data();
    expect(data['ownerUid'], 'owner-uid');
    expect(data['latitude'], -23.55);
    expect(data['longitude'], -46.63);
    expect(data['createdAt'], isNotNull);
  });

  test('recordEmergency omits coordinates when not provided', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = EmergencyRepository(firestore);

    await repo.recordEmergency(ownerUid: 'owner-uid');

    final data = (await firestore.collection('emergencies').get()).docs.single.data();
    expect(data.containsKey('latitude'), isFalse);
    expect(data.containsKey('longitude'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/repositories/emergency_repository_test.dart`
Expected: FAIL — `lib/repositories/emergency_repository.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/repositories/emergency_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyRepository {
  EmergencyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> recordEmergency({
    required String ownerUid,
    double? latitude,
    double? longitude,
  }) {
    return _firestore.collection('emergencies').add({
      'ownerUid': ownerUid,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/repositories/emergency_repository_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/emergency_repository.dart test/repositories/emergency_repository_test.dart
git commit -m "feat: add EmergencyRepository for recording emergency alerts"
```

---

### Task 2: Best-effort location fetch

**Files:**
- Create: `lib/services/location_service.dart`

**Interfaces:**
- Produces: `typedef LocationFetcher = Future<Position?> Function();` and a top-level `Future<Position?> fetchCurrentLocation()` matching that typedef — checks/requests foreground permission, reads current position with a 5-second timeout, returns `null` on any denial/error/timeout instead of throwing.

This task has no dedicated automated test: it wraps the real `geolocator` plugin, which requires platform channels unavailable in `flutter test` (the same class of limitation already accepted for `FcmService.registerToken` in the sibling plan's Task 8). Task 3 makes the function injectable specifically so the *consumer* (`EmergencyButton`) can be tested without ever calling this real implementation.

- [ ] **Step 1: Implement `lib/services/location_service.dart`**

```dart
import 'package:geolocator/geolocator.dart';

typedef LocationFetcher = Future<Position?> Function();

Future<Position?> fetchCurrentLocation() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 5));
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 2: Run the full suite to confirm nothing else broke**

Run: `flutter test`
Expected: PASS (no new tests added by this task; this file has no direct test, per the note above).

- [ ] **Step 3: Commit**

```bash
git add lib/services/location_service.dart
git commit -m "feat: add best-effort foreground location fetch for emergency alerts"
```

---

### Task 3: `EmergencyButton` widget

**Files:**
- Create: `lib/widgets/emergency_button.dart`
- Test: `test/widgets/emergency_button_test.dart`

**Interfaces:**
- Consumes: `EmergencyRepository` (Task 1), `LocationFetcher`/`fetchCurrentLocation` (Task 2), `currentUidProvider` (sibling plan Task 2), `firestoreProvider` (sibling plan Task 6), `contactsStreamProvider` (sibling plan Task 4/6), `AppSnackbar.showError` (pre-existing).
- Produces: `EmergencyButton({LocationFetcher fetchLocation = fetchCurrentLocation, Duration holdDuration = const Duration(seconds: 3)})` — a `ConsumerStatefulWidget`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/widgets/emergency_button.dart';

void main() {
  Future<void> seedLinkedContact(FakeFirebaseFirestore firestore) async {
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await contacts.addContact(contact);
    await contacts.linkContact(contact.id, 'family-uid');
  }

  Widget buildApp(FakeFirebaseFirestore firestore, {LocationFetcher? fetchLocation}) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: EmergencyButton(
            holdDuration: const Duration(milliseconds: 50),
            fetchLocation: fetchLocation ?? () async => null,
          ),
        ),
      ),
    );
  }

  testWidgets('releasing before the hold completes does not record an emergency', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 10));
    await gesture.up();
    await tester.pumpAndSettle();

    expect((await firestore.collection('emergencies').get()).docs, isEmpty);
  });

  testWidgets('holding for the full duration records an emergency without location', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    final docs = (await firestore.collection('emergencies').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['ownerUid'], 'owner-uid');
    expect(docs.single.data().containsKey('latitude'), isFalse);
    expect(find.text('Alerta enviado'), findsOneWidget);
  });

  testWidgets('holding with a location fetcher that returns a position includes coordinates', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await seedLinkedContact(firestore);
    await tester.pumpWidget(buildApp(
      firestore,
      fetchLocation: () async => Position(
        latitude: -23.55,
        longitude: -46.63,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    final data = (await firestore.collection('emergencies').get()).docs.single.data();
    expect(data['latitude'], -23.55);
    expect(data['longitude'], -46.63);
  });

  testWidgets('with no linked contacts, holding shows a warning and records nothing', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.startGesture(tester.getCenter(find.byType(EmergencyButton)));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect((await firestore.collection('emergencies').get()).docs, isEmpty);
    expect(find.textContaining('não tem familiares vinculados'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/emergency_button_test.dart`
Expected: FAIL — `lib/widgets/emergency_button.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/widgets/emergency_button.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/contact_provider.dart';
import '../repositories/emergency_repository.dart';
import '../services/location_service.dart';
import 'app_snackbar.dart';

class EmergencyButton extends ConsumerStatefulWidget {
  final LocationFetcher fetchLocation;
  final Duration holdDuration;

  const EmergencyButton({
    super.key,
    this.fetchLocation = fetchCurrentLocation,
    this.holdDuration = const Duration(seconds: 3),
  });

  @override
  ConsumerState<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends ConsumerState<EmergencyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: widget.holdDuration);
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _trigger();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_sending) return;
    _holdController.forward(from: 0);
  }

  void _cancelHold() {
    if (_holdController.isAnimating) {
      _holdController.stop();
      _holdController.value = 0;
    }
  }

  Future<void> _trigger() async {
    final contacts = ref.read(contactsStreamProvider).value ?? [];
    final linked = contacts.where((c) => c.linkedUid != null).toList();
    if (linked.isEmpty) {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Você ainda não tem familiares vinculados. Convide alguém na aba Família primeiro.',
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final position = await widget.fetchLocation();
      await EmergencyRepository(ref.read(firestoreProvider)).recordEmergency(
        ownerUid: ref.read(currentUidProvider),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alerta enviado'),
          content: Text(
            position != null
                ? 'Sua localização foi enviada para ${linked.length} familiar(es).'
                : 'Alerta enviado para ${linked.length} familiar(es), sem localização.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Não foi possível enviar o alerta. Tente de novo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coral = Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 4,
                  color: coral,
                  backgroundColor: coral.withOpacity(0.2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(shape: BoxShape.circle, color: coral),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sos, color: Colors.white, size: 32),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widgets/emergency_button_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/emergency_button.dart test/widgets/emergency_button_test.dart
git commit -m "feat: add hold-to-confirm EmergencyButton widget"
```

---

### Task 4: Wire `EmergencyButton` into the Home screen

**Files:**
- Modify: `lib/screens/home_screen.dart`

**Interfaces:**
- Consumes: `EmergencyButton` (Task 3).

- [ ] **Step 1: Add the button to the Home screen layout**

Open `lib/screens/home_screen.dart`. Add the import:

```dart
import '../widgets/emergency_button.dart';
```

Add `const EmergencyButton()` to the `Column` inside `build()`, placed right after the existing status `Card` (before the `SizedBox(height: 24)` that precedes "Últimos Envios"), wrapped so it's centered:

```dart
              const SizedBox(height: 16),
              const Center(child: EmergencyButton()),
```

(Insert this between the closing of the status `Card(...)` widget and the existing `const SizedBox(height: 24)` / "Últimos Envios" section — read the current file to place it precisely; the exact surrounding widget is a `Column` with `crossAxisAlignment: CrossAxisAlignment.stretch`, so wrapping the button in `Center` keeps it from stretching to full width.)

- [ ] **Step 2: Run the full suite**

Run: `flutter test`
Expected: PASS — `test/screens/home_screen_test.dart` (from the earlier visual-refresh plan) doesn't assert on the full widget tree exhaustively, so adding a widget should not break its existing assertions; confirm this is actually true by running it.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: add emergency button to the Home screen"
```

---

### Task 5: Location permissions (Android + iOS)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:** none (platform configuration only).

- [ ] **Step 1: Add Android location permissions**

Open `android/app/src/main/AndroidManifest.xml`. Add these two lines as direct children of the top-level `<manifest ...>` element, before the `<application ...>` tag:

```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

- [ ] **Step 2: Add the iOS usage-description string**

Open `ios/Runner/Info.plist`. Add this key/value pair as a direct child of the top-level `<dict>` element (anywhere among the other `<key>`/`<value>` pairs is fine):

```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>O ToAqui usa sua localização para incluir no alerta de emergência quando você aciona o botão.</string>
```

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: PASS (these are platform config files with no Dart test coverage; this step just confirms the rest of the app didn't regress).

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat: declare foreground location permission for emergency alerts"
```

---

### Task 6: Cloud Function — `onEmergencyCreated`

**Do not dispatch this task until BOTH of the following are true:**
1. `functions/` exists in this repo (created by the sibling plan's Task 1, currently blocked on the human partner's Firebase Blaze setup).
2. The sibling plan's Task 10 (`functions/src/resolveRecipientTokens.ts` and `functions/src/index.ts`) is merged — this task imports `resolveRecipientTokens` from that file rather than reimplementing it.

If dispatched anyway and either prerequisite is missing, report BLOCKED immediately rather than attempting a workaround.

**Files:**
- Modify: `functions/src/index.ts`
- Test: `functions/src/onEmergencyCreated.test.ts`

**Interfaces:**
- Consumes: `resolveRecipientTokens(db, ownerUid)` from `functions/src/resolveRecipientTokens.ts` (sibling plan, Task 10) — reused unchanged.
- Produces: exported Cloud Function `onEmergencyCreated`, Firestore-triggered on `emergencies/{emergencyId}`.

- [ ] **Step 1: Write the failing test**

Create `functions/src/onEmergencyCreated.test.ts`:

```typescript
import * as admin from "firebase-admin";
import { resolveRecipientTokens } from "./resolveRecipientTokens";

describe("emergency notification payload", () => {
  let app: admin.app.App;

  beforeAll(() => {
    process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
    app = admin.initializeApp({ projectId: "toaqui-test-emergency" });
  });

  afterAll(async () => {
    await app.delete();
  });

  it("resolves the same linked-contact tokens as arrivals do", async () => {
    const db = admin.firestore();

    await db.collection("users").doc("owner-uid").collection("contacts").doc("c1").set({
      name: "Mãe",
      relationship: "Mãe",
      linkedUid: "family-1",
    });
    await db.collection("users").doc("family-1").set({ fcmToken: "token-abc" });

    const tokens = await resolveRecipientTokens(db, "owner-uid");

    expect(tokens).toEqual(["token-abc"]);
  });
});
```

This test intentionally only re-verifies that `resolveRecipientTokens` (already tested exhaustively in the sibling plan's Task 10) is importable and usable from this module — it does not re-test resolution logic itself, avoiding duplicate test coverage. The actual `onEmergencyCreated` trigger function is thin glue over this helper plus `getMessaging().sendEachForMulticast(...)`, following the exact same untested-thin-wrapper pattern already accepted for `onArrivalCreated`.

- [ ] **Step 2: Run it to verify it fails**

From `functions/`, run: `firebase emulators:exec --only firestore "npm test -- onEmergencyCreated"`
Expected: FAIL — `onEmergencyCreated.test.ts` exists but nothing in `index.ts` references it yet (the test itself only needs `resolveRecipientTokens`, which already exists from the sibling plan's Task 10 — if this import fails, STOP: the prerequisite wasn't actually met).

- [ ] **Step 3: Add `onEmergencyCreated` to `functions/src/index.ts`**

Add this export alongside the existing `onArrivalCreated`:

```typescript
export const onEmergencyCreated = onDocumentCreated("emergencies/{emergencyId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const { ownerUid, latitude, longitude } = snap.data() as {
    ownerUid: string;
    latitude?: number;
    longitude?: number;
  };
  const db = getFirestore();
  const tokens = await resolveRecipientTokens(db, ownerUid);

  if (tokens.length === 0) return;

  const mapLink =
    latitude !== undefined && longitude !== undefined
      ? ` https://maps.google.com/?q=${latitude},${longitude}`
      : "";

  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: "🆘 ToAqui — Alerta de emergência",
      body: `Uma pessoa da sua família apertou o botão de emergência.${mapLink}`,
    },
    android: { priority: "high" },
  });
});
```

(This reuses the same `initializeApp()`, `getFirestore`, `getMessaging`, and `resolveRecipientTokens` imports already present at the top of `functions/src/index.ts` from the sibling plan's Task 10 — no new imports needed beyond what's already there.)

- [ ] **Step 4: Run the test to verify it passes**

From `functions/`, run: `firebase emulators:exec --only firestore "npm test -- onEmergencyCreated"`
Expected: PASS (1 test).

- [ ] **Step 5: Type-check and build**

From `functions/`, run: `npm run build`
Expected: no type errors.

- [ ] **Step 6: Run the full Cloud Functions test suite**

From `functions/`, run: `firebase emulators:exec --only firestore "npm test"`
Expected: PASS (all tests, including `resolveRecipientTokens.test.ts` from the sibling plan and this task's new test).

- [ ] **Step 7: Commit**

```bash
git add functions/src/index.ts functions/src/onEmergencyCreated.test.ts
git commit -m "feat: send FCM push to linked contacts when an emergency is recorded"
```

---

### Task 7: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass (Tasks 1, 3, 4 each contributed tests).

- [ ] **Step 2: Static analysis**

Run: `flutter analyze` (or `dart analyze lib test` if `flutter analyze` crashes in this environment, as noted in prior tasks of the sibling plan)
Expected: no new errors/warnings beyond already-known, out-of-scope pre-existing ones.

- [ ] **Step 3: [MANUAL — human partner] Manual walkthrough**

This requires a real device/emulator (location permission prompts and GPS don't work meaningfully in this sandbox):
- [ ] Run the app on a device. Deny location permission when first prompted, then hold the emergency button for 3 seconds — confirm it still sends and the dialog says "sem localização."
- [ ] Grant location permission, hold the button again — confirm the dialog mentions your location was included, and (once Task 6's Cloud Function is deployed and the sibling plan's Task 12 is done) confirm a linked family member's device receives the push with a working map link.
- [ ] With zero linked contacts, hold the button — confirm the warning message appears and nothing is sent.
- [ ] Tap-and-release quickly (well under 3 seconds) several times — confirm nothing is ever sent accidentally.

- [ ] **Step 4: Final commit (only if Step 2 produced fixes)**

```bash
git add -A
git commit -m "chore: address flutter analyze findings from emergency alert pass"
```
