# ToAqui Family Invite & Arrival Push Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Task 1 is a MANUAL task for the human partner — no subagent can complete it (it requires an interactive Google login). Do not dispatch it.**

**Goal:** Turn on real Firebase infrastructure — anonymous accounts, Firestore-backed locations/contacts, a single-use invite-code flow to link a family member, and a Cloud Function that pushes a notification to linked family members when an arrival is (manually, for now) recorded.

**Architecture:** Flutter client talks only to Firestore/Auth/FCM directly (no custom HTTP backend). A single Cloud Function, triggered by a new Firestore document under `arrivals/`, resolves which linked contacts should be notified and sends the push via FCM. Anonymous auth removes any login screen; a short-lived, single-use invite code is the only way two accounts become linked.

**Tech Stack:** firebase_core, firebase_auth (anonymous), cloud_firestore, firebase_messaging (already in `pubspec.yaml`, currently unused) + `fake_cloud_firestore`/`firebase_auth_mocks` (new, dev-only, for tests) on the Flutter side; a separate Node.js/TypeScript Cloud Functions project (`functions/`) using `firebase-functions` v2 + `firebase-admin`, tested against the Firebase Local Emulator Suite.

## Execution Note (2026-07-30): Task 1 temporarily blocked

The human partner hit a payment snag activating Firebase's Blaze plan and is deferring Task 1. Only two things in this entire plan actually require `lib/firebase_options.dart` (Task 1's output) to exist:

1. Task 2, Step 7 (`import 'firebase_options.dart';` + `Firebase.initializeApp(...)` in `lib/main.dart`).
2. Task 8, Step 6 (adding the FCM-registration call right after that same line).

Every other step in Tasks 2-10 — including Task 7's `/join` route in `main.dart`, which does NOT touch Firebase initialization — compiles and passes `flutter test`/`flutter analyze` without a live Firebase project, because all tests use `fake_cloud_firestore`/`firebase_auth_mocks`, never the real `Firebase.instance`. **Proceed with Tasks 2-10 now, skipping only Task 2 Step 7-8 and Task 8 Step 6** (each says so explicitly, marked `[DEFERRED]`). Task 12 (new, inserted after Task 10) picks up exactly those deferred steps once Task 1 unblocks, followed by the renumbered Task 13 (old Task 11) full verification pass.

## Global Constraints

- Anonymous auth only — no login/signup UI, no email/password, no phone verification, for either the tracked person or their family.
- Invite codes: 6 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (uppercase, digits, excludes `0/O/1/I` to avoid ambiguity when read aloud/typed), expire 24 hours after creation, single-use.
- Firestore layout (exact): `users/{uid}` (`fcmToken`, `createdAt`), `users/{uid}/locations/{id}`, `users/{uid}/contacts/{id}` (`name`, `relationship`, `linkedUid` nullable, `inviteCode`), `invites/{code}` (`ownerUid`, `contactId`, `createdAt`, `expiresAt`, `used`), `arrivals/{id}` (`ownerUid`, `locationId`, `message`, `createdAt`).
- No real geofencing, no background location permissions, no account recovery, no independent invite revocation, no multi-device support — all explicitly out of scope for this leva (see spec's Non-Goals).
- No test may hit a live Firebase project: Flutter-side tests use `fake_cloud_firestore`/`firebase_auth_mocks`; Cloud Functions tests use the Firebase Local Emulator Suite.
- Spec reference: `docs/superpowers/specs/2026-07-30-family-invite-notifications-design.md`

---

### Task 1: [MANUAL — human partner only] Firebase project setup

**No subagent should be dispatched for this task.** It requires an interactive Google account login that cannot run headlessly. Perform these steps yourself, then check the box:

- [ ] Go to https://console.firebase.google.com, create a project (or reuse one) for ToAqui.
- [ ] In the project, upgrade to the **Blaze** (pay-as-you-go) plan — required for Cloud Functions. Expected cost at this app's scale: $0/month, but a billing card must be on file.
- [ ] In **Build → Authentication → Sign-in method**, enable **Anonymous**.
- [ ] In **Build → Firestore Database**, create a database (production mode, any region close to you).
- [ ] In **Build → Messaging**, no setup needed yet — it activates automatically once the app registers a token.
- [ ] Install the Firebase CLI if you don't have it: `npm install -g firebase-tools`, then `firebase login`.
- [ ] Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`.
- [ ] From the project root (`C:\Users\Bruno Mendonça\Desktop\ToAqui`), run `flutterfire configure` and select the Firebase project above, and at minimum the Android and iOS platforms. This generates `lib/firebase_options.dart` — every later task depends on this file existing.
- [ ] Run `firebase init functions` from the project root, choosing **TypeScript**, the same Firebase project, and **not** overwriting anything under `lib/`. This creates the `functions/` directory that Task 10 builds on. Decline the "install dependencies now" prompt if asked — Task 10 handles that.
- [ ] Commit the generated `lib/firebase_options.dart`, `firebase.json`, `.firebaserc`, and the scaffolded `functions/` directory (excluding `functions/node_modules/`, which Task 10's setup will `.gitignore`) once everything above is done, so later tasks (and any dispatched subagent) can build on top of them.

---

### Task 2: Anonymous auth bootstrap

**Files:**
- Create: `lib/services/auth_service.dart`
- Create: `lib/providers/auth_provider.dart`
- Modify: `lib/main.dart` (uncomment Firebase init, sign in anonymously before `runApp`)
- Test: `test/services/auth_service_test.dart`

**Interfaces:**
- Produces: `AuthService.signInAnonymously()` returning `Future<String>` (the uid); `currentUidProvider` (`Provider<String>`) — safe to read anywhere in the widget tree because `main()` awaits sign-in before `runApp`.

- [ ] **Step 1: Add test dependencies**

Run: `flutter pub add --dev firebase_auth_mocks`

- [ ] **Step 2: Write the failing test**

```dart
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/services/auth_service.dart';

void main() {
  test('signInAnonymously returns the signed-in uid', () async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final service = AuthService(mockAuth);

    final uid = await service.signInAnonymously();

    expect(uid, isNotEmpty);
    expect(mockAuth.currentUser, isNotNull);
    expect(mockAuth.currentUser!.uid, uid);
  });

  test('signInAnonymously is a no-op if already signed in', () async {
    final mockAuth = MockFirebaseAuth(signedIn: true);
    final service = AuthService(mockAuth);
    final existingUid = mockAuth.currentUser!.uid;

    final uid = await service.signInAnonymously();

    expect(uid, existingUid);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/services/auth_service_test.dart`
Expected: FAIL — `lib/services/auth_service.dart` doesn't exist yet.

- [ ] **Step 4: Implement `lib/services/auth_service.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<String> signInAnonymously() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/services/auth_service_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Implement `lib/providers/auth_provider.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Safe to read anywhere: `main()` awaits anonymous sign-in before `runApp`,
/// so `FirebaseAuth.instance.currentUser` is guaranteed non-null by the time
/// any widget builds.
final currentUidProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser!.uid;
});
```

- [ ] **Step 7: `[DEFERRED — do not do this yet, see "Execution Note" at the top of this plan]` Wire into `lib/main.dart`**

Skip this step entirely for now — do not edit `lib/main.dart` in this task. It requires `lib/firebase_options.dart`, which doesn't exist until Task 1 (currently blocked) is done. Task 12 performs this exact edit later. The code that step will apply, for reference:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
```

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService(FirebaseAuth.instance).signInAnonymously();
  runApp(const ProviderScope(child: ToAquiApp()));
}
```

- [ ] **Step 8: `[DEFERRED]` Manual check — confirm `lib/firebase_options.dart` exists**

Skipped along with Step 7. Task 12 does this check.

- [ ] **Step 9: Commit (auth service + provider only — no `main.dart` changes yet)**

```bash
git add lib/services/auth_service.dart lib/providers/auth_provider.dart test/services/auth_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add anonymous auth service and provider (not yet wired into main.dart)"
```

---

### Task 3: Firestore-backed locations (repository + provider + screens)

**Files:**
- Create: `lib/repositories/location_repository.dart`
- Modify: `lib/providers/location_provider.dart` (full replace)
- Modify: `lib/screens/locations_screen.dart` (full replace)
- Modify: `lib/screens/add_location_screen.dart` (only the save call, see Step 6)
- Test: `test/repositories/location_repository_test.dart`

**Interfaces:**
- Consumes: `currentUidProvider` (Task 2), `LocationModel` (unchanged: `id`, `name`, `latitude`, `longitude`, `radius`, `message`, `isActive`, `toMap`, `fromMap`).
- Produces: `LocationRepository(FirebaseFirestore, String uid)` with `watchLocations()` → `Stream<List<LocationModel>>`, `addLocation(LocationModel)` → `Future<void>`, `toggleLocation(String id, bool isActive)` → `Future<void>`, `deleteLocation(String id)` → `Future<void>`. `locationRepositoryProvider` (`Provider<LocationRepository>`) and `locationsStreamProvider` (`StreamProvider<List<LocationModel>>`) replace the old `locationProvider`/`locationsLoadingProvider` StateNotifier pair entirely — **`locationsLoadingProvider` is deleted**, loading now comes for free from `AsyncValue`.

- [ ] **Step 1: Add the test dependency**

Run: `flutter pub add --dev fake_cloud_firestore`

- [ ] **Step 2: Write the failing test**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/repositories/location_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LocationRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = LocationRepository(firestore, 'owner-uid');
  });

  test('watchLocations emits an empty list, then the added location', () async {
    expect(await repo.watchLocations().first, isEmpty);

    final location = LocationModel(
      name: 'Trabalho',
      latitude: -23.55,
      longitude: -46.63,
      radius: 100,
      message: 'Cheguei!',
    );
    await repo.addLocation(location);

    final result = await repo.watchLocations().first;
    expect(result, hasLength(1));
    expect(result.first.name, 'Trabalho');
  });

  test('toggleLocation flips isActive on the matching document', () async {
    final location = LocationModel(
      name: 'Casa',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'Cheguei em casa!',
      isActive: true,
    );
    await repo.addLocation(location);

    await repo.toggleLocation(location.id, false);

    final result = await repo.watchLocations().first;
    expect(result.single.isActive, isFalse);
  });

  test('deleteLocation removes the document', () async {
    final location = LocationModel(
      name: 'Casa',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'Cheguei em casa!',
    );
    await repo.addLocation(location);

    await repo.deleteLocation(location.id);

    expect(await repo.watchLocations().first, isEmpty);
  });

  test('scopes documents under users/{uid}/locations, not other users', () async {
    final otherRepo = LocationRepository(firestore, 'other-uid');
    await otherRepo.addLocation(LocationModel(
      name: 'Não deveria aparecer',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'x',
    ));

    expect(await repo.watchLocations().first, isEmpty);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/repositories/location_repository_test.dart`
Expected: FAIL — `lib/repositories/location_repository.dart` doesn't exist yet.

- [ ] **Step 4: Implement `lib/repositories/location_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class LocationRepository {
  LocationRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('locations');

  Stream<List<LocationModel>> watchLocations() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => LocationModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> addLocation(LocationModel location) {
    return _collection.doc(location.id).set(location.toMap());
  }

  Future<void> toggleLocation(String id, bool isActive) {
    return _collection.doc(id).update({'isActive': isActive});
  }

  Future<void> deleteLocation(String id) {
    return _collection.doc(id).delete();
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/repositories/location_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Replace `lib/providers/location_provider.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/location_repository.dart';
import 'auth_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(FirebaseFirestore.instance, ref.watch(currentUidProvider));
});

final locationsStreamProvider = StreamProvider((ref) {
  return ref.watch(locationRepositoryProvider).watchLocations();
});
```

- [ ] **Step 7: Replace `lib/screens/locations_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Locais')),
      body: locationsAsync.when(
        loading: () => ListView(
          children: const [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
        ),
        error: (error, stack) => Center(child: Text('Erro ao carregar locais: $error')),
        data: (locations) {
          if (locations.isEmpty) {
            return const EmptyState(
              emoji: '📍',
              title: 'Nenhum local cadastrado',
              subtitle: 'Adicione um local para começar a avisar sua família',
            );
          }
          return ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final loc = locations[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.place)),
                title: Text(loc.name),
                subtitle: Text('Raio: ${loc.radius.toInt()}m'),
                trailing: Switch(
                  value: loc.isActive,
                  onChanged: (val) {
                    ref.read(locationRepositoryProvider).toggleLocation(loc.id, val);
                    AppSnackbar.showConfirmation(
                      context,
                      '${loc.name} ${val ? 'ativado' : 'desativado'}',
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/add'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Novo Local'),
      ),
    );
  }
}
```

- [ ] **Step 8: Update the save call in `lib/screens/add_location_screen.dart`**

Find `_saveLocation` and replace this line:

```dart
    ref.read(locationProvider.notifier).addLocation(newLocation);
```

with:

```dart
    ref.read(locationRepositoryProvider).addLocation(newLocation);
```

And update the import at the top of the file — it already imports `../providers/location_provider.dart`, which now exports `locationRepositoryProvider` instead of `locationProvider`, so no import line changes, only the call site above.

- [ ] **Step 9: Delete the stale screen test that targeted the old provider shape**

`test/screens/locations_screen_test.dart` and `test/providers/location_provider_test.dart` both target the old `StateNotifier`/`locationsLoadingProvider` API and will no longer compile. Delete both files — this task's repository test (Step 2) is their replacement for repository-level coverage; screen-level coverage for the new `AsyncValue`-driven UI is intentionally not re-added here (would require wiring `fake_cloud_firestore` through `ProviderScope` overrides, arguably better done as a follow-up if the team wants it — flag this as a self-review note, not a blocker).

```bash
rm test/screens/locations_screen_test.dart test/providers/location_provider_test.dart
```

- [ ] **Step 10: Run the full suite**

Run: `flutter test`
Expected: PASS, with the location repository's 4 new tests included and no reference to the deleted files remaining.

- [ ] **Step 11: Commit**

```bash
git add lib/repositories/location_repository.dart lib/providers/location_provider.dart lib/screens/locations_screen.dart lib/screens/add_location_screen.dart test/repositories/location_repository_test.dart pubspec.yaml pubspec.lock
git add -u test/screens/locations_screen_test.dart test/providers/location_provider_test.dart
git commit -m "feat: back locations with Firestore instead of in-memory state"
```

---

### Task 4: Firestore-backed contacts (model + repository + provider)

**Files:**
- Modify: `lib/models/contact_model.dart` (add `linkedUid`, `inviteCode`, `toMap`/`fromMap`)
- Create: `lib/repositories/contact_repository.dart`
- Modify: `lib/providers/contact_provider.dart` (full replace)
- Test: `test/repositories/contact_repository_test.dart`

**Interfaces:**
- Produces: `ContactModel` gains `String? linkedUid` and `String? inviteCode` (both nullable, default null), plus `toMap()`/`fromMap()`. `ContactRepository(FirebaseFirestore, String uid)` with `watchContacts()` → `Stream<List<ContactModel>>`, `addContact(ContactModel)` → `Future<void>`, `deleteContact(String id)` → `Future<void>`, `linkContact(String contactId, String linkedUid)` → `Future<void>` (used by Task 5's invite redemption). `contactRepositoryProvider` and `contactsStreamProvider` replace `contactProvider`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/repositories/contact_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ContactRepository repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = ContactRepository(firestore, 'owner-uid');
  });

  test('addContact then watchContacts returns it with linkedUid null', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(contact);

    final result = await repo.watchContacts().first;
    expect(result.single.name, 'Mãe');
    expect(result.single.linkedUid, isNull);
  });

  test('linkContact sets linkedUid on the matching document', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await repo.addContact(contact);

    await repo.linkContact(contact.id, 'family-member-uid');

    final result = await repo.watchContacts().first;
    expect(result.single.linkedUid, 'family-member-uid');
  });

  test('deleteContact removes the document', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(contact);

    await repo.deleteContact(contact.id);

    expect(await repo.watchContacts().first, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/repositories/contact_repository_test.dart`
Expected: FAIL — `lib/repositories/contact_repository.dart` doesn't exist yet, and `ContactModel` has no `linkedUid`.

- [ ] **Step 3: Update `lib/models/contact_model.dart`**

```dart
import 'package:uuid/uuid.dart';

class ContactModel {
  final String id;
  final String name;
  final String relationship;
  final String? linkedUid;
  final String? inviteCode;

  ContactModel({
    String? id,
    required this.name,
    required this.relationship,
    this.linkedUid,
    this.inviteCode,
  }) : id = id ?? const Uuid().v4();

  ContactModel copyWith({
    String? name,
    String? relationship,
    String? linkedUid,
    String? inviteCode,
  }) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      linkedUid: linkedUid ?? this.linkedUid,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'linkedUid': linkedUid,
      'inviteCode': inviteCode,
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'],
      name: map['name'],
      relationship: map['relationship'],
      linkedUid: map['linkedUid'],
      inviteCode: map['inviteCode'],
    );
  }
}
```

- [ ] **Step 4: Implement `lib/repositories/contact_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactRepository {
  ContactRepository(this._firestore, this._uid);

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('contacts');

  Stream<List<ContactModel>> watchContacts() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ContactModel.fromMap({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  Future<void> addContact(ContactModel contact) {
    return _collection.doc(contact.id).set(contact.toMap());
  }

  Future<void> linkContact(String contactId, String linkedUid) {
    return _collection.doc(contactId).update({'linkedUid': linkedUid});
  }

  Future<void> deleteContact(String id) {
    return _collection.doc(id).delete();
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/repositories/contact_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Replace `lib/providers/contact_provider.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/contact_repository.dart';
import 'auth_provider.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(FirebaseFirestore.instance, ref.watch(currentUidProvider));
});

final contactsStreamProvider = StreamProvider((ref) {
  return ref.watch(contactRepositoryProvider).watchContacts();
});
```

- [ ] **Step 7: Delete the stale tests targeting the old provider/model shape**

`test/providers/contact_provider_test.dart` and `test/screens/contacts_screen_test.dart` reference the deleted `ContactNotifier`/`contactProvider` and will no longer compile as-is. Task 6 rewrites the screen and adds its own coverage; delete both for now:

```bash
rm test/providers/contact_provider_test.dart test/screens/contacts_screen_test.dart
```

- [ ] **Step 8: Run the full suite**

Run: `flutter test`
Expected: PASS. (`lib/screens/contacts_screen.dart` and `lib/widgets/add_contact_sheet.dart` still reference the deleted `contactProvider` at this point and will fail `flutter analyze` — that's expected and fixed in Task 6. Confirm with `flutter test` only, not `flutter analyze`, for this task.)

- [ ] **Step 9: Commit**

```bash
git add lib/models/contact_model.dart lib/repositories/contact_repository.dart lib/providers/contact_provider.dart test/repositories/contact_repository_test.dart
git add -u test/providers/contact_provider_test.dart test/screens/contacts_screen_test.dart
git commit -m "feat: back contacts with Firestore, add linkedUid/inviteCode fields"
```

---

### Task 5: Invite model + repository (create + redeem)

**Files:**
- Create: `lib/models/invite_model.dart`
- Create: `lib/repositories/invite_repository.dart`
- Test: `test/repositories/invite_repository_test.dart`

**Interfaces:**
- Consumes: `ContactRepository.linkContact` (Task 4).
- Produces: `InviteModel` (`code`, `ownerUid`, `contactId`, `createdAt`, `expiresAt`, `used`). `InviteRepository(FirebaseFirestore)` with `createInvite({required String ownerUid, required String contactId})` → `Future<String>` (returns the generated code) and `redeemInvite({required String code, required String redeemerUid})` → `Future<InviteRedeemResult>` where `InviteRedeemResult` is a sealed-ish result type (`InviteRedeemSuccess`/`InviteRedeemFailure`) so the UI can distinguish "not found", "expired", and "already used".

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/models/contact_model.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late InviteRepository invites;
  late ContactRepository contacts;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    invites = InviteRepository(firestore);
    contacts = ContactRepository(firestore, 'owner-uid');
  });

  test('createInvite generates a 6-character code from the safe alphabet', () async {
    final contact = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await contacts.addContact(contact);

    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);

    expect(code, hasLength(6));
    expect(code, matches(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$')));
  });

  test('redeemInvite links the contact and marks the invite used', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);

    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');

    expect(result, isA<InviteRedeemSuccess>());
    final linked = await contacts.watchContacts().first;
    expect(linked.single.linkedUid, 'family-uid');
  });

  test('redeemInvite fails for an unknown code', () async {
    final result = await invites.redeemInvite(code: 'ZZZZZZ', redeemerUid: 'family-uid');
    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.notFound);
  });

  test('redeemInvite fails if the code was already used', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(ownerUid: 'owner-uid', contactId: contact.id);
    await invites.redeemInvite(code: code, redeemerUid: 'first-redeemer');

    final result = await invites.redeemInvite(code: code, redeemerUid: 'second-redeemer');

    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.alreadyUsed);
  });

  test('redeemInvite fails if the code has expired', () async {
    final contact = ContactModel(name: 'Amor', relationship: 'Parceiro(a)');
    await contacts.addContact(contact);
    final code = await invites.createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
      now: DateTime.now().subtract(const Duration(hours: 25)),
    );

    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');

    expect(result, isA<InviteRedeemFailure>());
    expect((result as InviteRedeemFailure).reason, InviteFailureReason.expired);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/repositories/invite_repository_test.dart`
Expected: FAIL — `lib/repositories/invite_repository.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/models/invite_model.dart`**

```dart
class InviteModel {
  final String code;
  final String ownerUid;
  final String contactId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;

  InviteModel({
    required this.code,
    required this.ownerUid,
    required this.contactId,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'ownerUid': ownerUid,
      'contactId': contactId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'used': used,
    };
  }

  factory InviteModel.fromMap(String code, Map<String, dynamic> map) {
    return InviteModel(
      code: code,
      ownerUid: map['ownerUid'],
      contactId: map['contactId'],
      createdAt: DateTime.parse(map['createdAt']),
      expiresAt: DateTime.parse(map['expiresAt']),
      used: map['used'] ?? false,
    );
  }
}
```

- [ ] **Step 4: Implement `lib/repositories/invite_repository.dart`**

```dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invite_model.dart';

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

enum InviteFailureReason { notFound, expired, alreadyUsed }

sealed class InviteRedeemResult {}

class InviteRedeemSuccess extends InviteRedeemResult {
  InviteRedeemSuccess(this.contactId, this.ownerUid);
  final String contactId;
  final String ownerUid;
}

class InviteRedeemFailure extends InviteRedeemResult {
  InviteRedeemFailure(this.reason);
  final InviteFailureReason reason;
}

class InviteRepository {
  InviteRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('invites');

  String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => _codeAlphabet[random.nextInt(_codeAlphabet.length)]).join();
  }

  Future<String> createInvite({
    required String ownerUid,
    required String contactId,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final code = _generateCode();
    final invite = InviteModel(
      code: code,
      ownerUid: ownerUid,
      contactId: contactId,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 24)),
    );
    await _collection.doc(code).set(invite.toMap());
    return code;
  }

  Future<InviteRedeemResult> redeemInvite({
    required String code,
    required String redeemerUid,
  }) async {
    final doc = await _collection.doc(code).get();
    if (!doc.exists) {
      return InviteRedeemFailure(InviteFailureReason.notFound);
    }

    final invite = InviteModel.fromMap(code, doc.data()!);
    if (invite.used) {
      return InviteRedeemFailure(InviteFailureReason.alreadyUsed);
    }
    if (DateTime.now().isAfter(invite.expiresAt)) {
      return InviteRedeemFailure(InviteFailureReason.expired);
    }

    await _firestore
        .collection('users')
        .doc(invite.ownerUid)
        .collection('contacts')
        .doc(invite.contactId)
        .update({'linkedUid': redeemerUid});
    await _collection.doc(code).update({'used': true});

    return InviteRedeemSuccess(invite.contactId, invite.ownerUid);
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/repositories/invite_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS (Task 4's `contacts_screen`/`add_contact_sheet` compile failures are still expected until Task 6 — confirm no NEW failures beyond those already-known ones).

- [ ] **Step 7: Commit**

```bash
git add lib/models/invite_model.dart lib/repositories/invite_repository.dart test/repositories/invite_repository_test.dart
git commit -m "feat: add invite code generation and redemption logic"
```

---

### Task 6: Invite-code UI after adding a contact

**Files:**
- Modify: `lib/widgets/add_contact_sheet.dart` (full replace)
- Modify: `lib/screens/contacts_screen.dart` (full replace)
- Test: `test/widgets/add_contact_sheet_test.dart` (full replace)
- Test: `test/screens/contacts_screen_test.dart` (new version)

**Interfaces:**
- Consumes: `contactRepositoryProvider`, `contactsStreamProvider` (Task 4), `InviteRepository`/`InviteRedeemSuccess` (Task 5), `currentUidProvider` (Task 2).
- Produces: `showAddContactSheet(BuildContext)` now returns `Future<String?>` — the generated invite code, or `null` if the sheet was dismissed without saving.

- [ ] **Step 1: Write the failing test for `AddContactSheet`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/widgets/add_contact_sheet.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final code = await showAddContactSheet(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('code:${code ?? ''}')),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('saving a contact generates and returns an invite code', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(buildApp(firestore));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('code:'), findsOneWidget);
    final snackBarText = tester.widget<Text>(find.textContaining('code:')).data!;
    final code = snackBarText.substring('code:'.length);
    expect(code, hasLength(6));

    final invites = InviteRepository(firestore);
    final result = await invites.redeemInvite(code: code, redeemerUid: 'family-uid');
    expect(result, isA<InviteRedeemSuccess>());
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/add_contact_sheet_test.dart`
Expected: FAIL — `firestoreProvider` doesn't exist yet and `showAddContactSheet` still returns `void`.

- [ ] **Step 3: Add a `firestoreProvider` seam to `lib/providers/contact_provider.dart`**

Add this above `contactRepositoryProvider`, and change that provider to consume it (so tests can override the Firestore instance):

```dart
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider));
});
```

Also update `lib/providers/location_provider.dart`'s `locationRepositoryProvider` to consume `firestoreProvider` the same way, for consistency (`import '../providers/contact_provider.dart' show firestoreProvider;` or move `firestoreProvider` to its own tiny file `lib/providers/firestore_provider.dart` and import it from both — prefer the latter to avoid a provider file importing another provider file for an unrelated symbol):

Create `lib/providers/firestore_provider.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
```

Then in both `lib/providers/location_provider.dart` and `lib/providers/contact_provider.dart`, import it (`import 'firestore_provider.dart';`) and change `FirebaseFirestore.instance` to `ref.watch(firestoreProvider)` in `locationRepositoryProvider`/`contactRepositoryProvider`.

- [ ] **Step 4: Replace `lib/widgets/add_contact_sheet.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/invite_repository.dart';
import '../providers/firestore_provider.dart';

Future<String?> showAddContactSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const AddContactSheet(),
  );
}

class AddContactSheet extends ConsumerStatefulWidget {
  const AddContactSheet({super.key});

  @override
  ConsumerState<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends ConsumerState<AddContactSheet> {
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _canSave = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final relationship = _relationshipController.text.isNotEmpty
        ? _relationshipController.text
        : 'Familiar';
    final contact = ContactModel(name: _nameController.text, relationship: relationship);

    await ref.read(contactRepositoryProvider).addContact(contact);

    final invites = InviteRepository(ref.read(firestoreProvider));
    final code = await invites.createInvite(
      ownerUid: ref.read(currentUidProvider),
      contactId: contact.id,
    );

    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Convidar familiar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('contact-name-field'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _canSave = value.trim().isNotEmpty),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact-relationship-field'),
            controller: _relationshipController,
            decoration: const InputDecoration(
              labelText: 'Relação (ex: Mãe, Amigo)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('contact-save-button'),
            onPressed: (_canSave && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the `AddContactSheet` test to verify it passes**

Run: `flutter test test/widgets/add_contact_sheet_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Write the failing test for `ContactsScreen`'s invite-code dialog**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/screens/contacts_screen.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: ContactsScreen()),
    );
  }

  testWidgets('adding a contact shows a dialog with the invite code', (tester) async {
    await tester.pumpWidget(buildApp(FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Envie esse código'), findsOneWidget);
    expect(find.byKey(const Key('invite-code-text')), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run it to verify it fails**

Run: `flutter test test/screens/contacts_screen_test.dart`
Expected: FAIL — `ContactsScreen` doesn't show any dialog yet.

- [ ] **Step 8: Replace `lib/screens/contacts_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  Future<void> _addContact(BuildContext context) async {
    final code = await showAddContactSheet(context);
    if (code == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convite criado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Envie esse código pro seu familiar por WhatsApp, SMS ou como preferir:'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              key: const Key('invite-code-text'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Família e Contatos')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erro ao carregar contatos: $error')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return EmptyState(
              emoji: '👨‍👩‍👧‍👦',
              title: 'Sua família ainda não está por aqui',
              subtitle: 'Convide quem você ama pra saber que você chegou bem',
              ctaLabel: 'Convidar familiar',
              onCtaPressed: () => _addContact(context),
            );
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                ),
                title: Text(contact.name),
                subtitle: Text(
                  contact.linkedUid == null
                      ? '${contact.relationship} · convite pendente'
                      : contact.relationship,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(contactRepositoryProvider).deleteContact(contact.id),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }
}
```

- [ ] **Step 9: Run both tests to verify they pass**

Run: `flutter test test/widgets/add_contact_sheet_test.dart test/screens/contacts_screen_test.dart`
Expected: PASS (2 tests total).

- [ ] **Step 10: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add lib/widgets/add_contact_sheet.dart lib/screens/contacts_screen.dart lib/providers/firestore_provider.dart lib/providers/contact_provider.dart lib/providers/location_provider.dart test/widgets/add_contact_sheet_test.dart test/screens/contacts_screen_test.dart
git commit -m "feat: show invite code after adding a family member"
```

---

### Task 7: Join screen ("Tenho um convite")

**Files:**
- Create: `lib/screens/join_screen.dart`
- Modify: `lib/screens/main_layout.dart` (add an entry point button)
- Modify: `lib/main.dart` (add the route)
- Test: `test/screens/join_screen_test.dart`

**Interfaces:**
- Consumes: `InviteRepository`/`InviteRedeemResult` (Task 5), `currentUidProvider` (Task 2), `firestoreProvider` (Task 6).
- Produces: `JoinScreen` widget, route `/join`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
import 'package:to_aqui/repositories/invite_repository.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/screens/join_screen.dart';

void main() {
  testWidgets('redeeming a valid code shows a success message', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final contacts = ContactRepository(firestore, 'owner-uid');
    final contact = ContactModel(name: 'Vovó', relationship: 'Avó');
    await contacts.addContact(contact);
    final code = await InviteRepository(firestore).createInvite(
      ownerUid: 'owner-uid',
      contactId: contact.id,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), code);
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conectado'), findsOneWidget);
  });

  testWidgets('an invalid code shows an error', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('family-uid'),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: JoinScreen()),
    ));

    await tester.enterText(find.byKey(const Key('invite-code-field')), 'ZZZZZZ');
    await tester.tap(find.byKey(const Key('join-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/join_screen_test.dart`
Expected: FAIL — `lib/screens/join_screen.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/screens/join_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../repositories/invite_repository.dart';
import '../widgets/app_snackbar.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final invites = InviteRepository(ref.read(firestoreProvider));
    final result = await invites.redeemInvite(
      code: _codeController.text.trim().toUpperCase(),
      redeemerUid: ref.read(currentUidProvider),
    );

    if (!mounted) return;

    switch (result) {
      case InviteRedeemSuccess():
        setState(() => _successMessage = 'Conectado! Você vai receber os avisos de chegada.');
      case InviteRedeemFailure(reason: final reason):
        AppSnackbar.showError(context, switch (reason) {
          InviteFailureReason.notFound => 'Código não encontrado. Confira e tente de novo.',
          InviteFailureReason.expired => 'Esse código expirou. Peça um novo convite.',
          InviteFailureReason.alreadyUsed => 'Esse código já foi usado.',
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenho um convite')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Digite o código de 6 caracteres que você recebeu:'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('invite-code-field'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código do convite',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('join-submit-button'),
              onPressed: _submit,
              child: const Text('Conectar'),
            ),
            if (_successMessage != null) ...[
              const SizedBox(height: 20),
              Text(_successMessage!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/join_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Add the route in `lib/main.dart`**

Add the import:
```dart
import 'screens/join_screen.dart';
```

Add a new top-level route (sibling to the `/locations/add` route, inside the `routes:` list of the `GoRouter`):
```dart
      GoRoute(
        path: '/join',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JoinScreen(),
      ),
```

- [ ] **Step 6: Add an entry point button in `lib/screens/main_layout.dart`**

Read the current file first — add an `actions:` entry or a persistent button that calls `context.push('/join')`. The simplest option that doesn't disturb the existing `NavigationBar` layout: add a leading `IconButton` (e.g. `Icons.qr_code`) to whichever screen currently owns the top app bar, OR add a fourth, non-tab entry. Prefer the least invasive option: add an `actions: [IconButton(icon: Icon(Icons.link), tooltip: 'Tenho um convite', onPressed: () => context.push('/join'))]` to the `AppBar` in `lib/screens/home_screen.dart` (it already has an `AppBar`), rather than modifying `main_layout.dart` at all. Skip modifying `main_layout.dart` if this simpler placement covers it — note in your report which you chose.

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/join_screen.dart lib/main.dart lib/screens/home_screen.dart test/screens/join_screen_test.dart
git commit -m "feat: add join screen for redeeming a family invite code"
```

---

### Task 8: FCM token registration

**Files:**
- Create: `lib/services/fcm_service.dart`
- Modify: `lib/main.dart` (call the service after sign-in)
- Test: `test/services/fcm_service_test.dart`

**Interfaces:**
- Consumes: `currentUidProvider`'s underlying uid (passed as a parameter, not read via Riverpod, since this runs in `main()` before `ProviderScope` exists).
- Produces: `FcmService(FirebaseMessaging, FirebaseFirestore).registerToken(String uid)` → `Future<void>`, which requests notification permission, gets the current token, writes it to `users/{uid}.fcmToken`, and subscribes to `onTokenRefresh` to keep it updated.

- [ ] **Step 1: Add the test dependency**

Run: `flutter pub add --dev firebase_messaging` — wait, `firebase_messaging` is already a prod dependency; there's no separate mock package commonly used for it. Instead, wrap only the parts that touch Firestore in a testable method and accept a pre-obtained token string as a parameter for the unit test, isolating `FcmService` from needing a real `FirebaseMessaging` instance in this test:

- [ ] **Step 2: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/services/fcm_service.dart';

void main() {
  test('saveToken writes the token under users/{uid}', () async {
    final firestore = FakeFirebaseFirestore();
    final service = FcmService(firestore);

    await service.saveToken(uid: 'owner-uid', token: 'fake-token-123');

    final doc = await firestore.collection('users').doc('owner-uid').get();
    expect(doc.data()!['fcmToken'], 'fake-token-123');
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/services/fcm_service_test.dart`
Expected: FAIL — `lib/services/fcm_service.dart` doesn't exist yet.

- [ ] **Step 4: Implement `lib/services/fcm_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  FcmService(this._firestore, [FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<void> saveToken({required String uid, required String token}) {
    return _firestore.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  Future<void> registerToken(String uid) async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    if (token != null) {
      await saveToken(uid: uid, token: token);
    }

    _messaging.onTokenRefresh.listen((newToken) {
      saveToken(uid: uid, token: newToken);
    });
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/services/fcm_service_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: `[DEFERRED — see "Execution Note" at the top of this plan]` Wire into `lib/main.dart`**

Skip this step entirely for now — `lib/main.dart` doesn't have the anonymous sign-in line yet (that's also deferred, in Task 2 Step 7), so there's nothing to attach this to. Task 12 performs this edit right after redoing Task 2 Step 7. The code that step will apply, for reference:

```dart
  final uid = await AuthService(FirebaseAuth.instance).signInAnonymously();
  await FcmService(FirebaseFirestore.instance).registerToken(uid);
```

(This replaces the standalone `await AuthService(...).signInAnonymously();` line — capture its return value into `uid` instead of discarding it. Also needs `import 'package:cloud_firestore/cloud_firestore.dart';` and `import 'services/fcm_service.dart';` at the top of `main.dart`.)

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 8: Commit (service only — no `main.dart` changes yet)**

```bash
git add lib/services/fcm_service.dart test/services/fcm_service_test.dart
git commit -m "feat: add FCM token registration service (not yet wired into main.dart)"
```

---

### Task 9: Arrival repository + "Simular chegada" button

**Files:**
- Create: `lib/repositories/arrival_repository.dart`
- Modify: `lib/screens/locations_screen.dart` (add the button per location)
- Test: `test/repositories/arrival_repository_test.dart`

**Interfaces:**
- Produces: `ArrivalRepository(FirebaseFirestore)` with `recordArrival({required String ownerUid, required String locationId, required String message})` → `Future<void>`, writing a doc to top-level `arrivals/`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';

void main() {
  test('recordArrival writes a document under the top-level arrivals collection', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ArrivalRepository(firestore);

    await repo.recordArrival(
      ownerUid: 'owner-uid',
      locationId: 'location-1',
      message: 'Cheguei em segurança!',
    );

    final snapshot = await firestore.collection('arrivals').get();
    expect(snapshot.docs, hasLength(1));
    final data = snapshot.docs.single.data();
    expect(data['ownerUid'], 'owner-uid');
    expect(data['locationId'], 'location-1');
    expect(data['message'], 'Cheguei em segurança!');
    expect(data['createdAt'], isNotNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/repositories/arrival_repository_test.dart`
Expected: FAIL — `lib/repositories/arrival_repository.dart` doesn't exist yet.

- [ ] **Step 3: Implement `lib/repositories/arrival_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArrivalRepository {
  ArrivalRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> recordArrival({
    required String ownerUid,
    required String locationId,
    required String message,
  }) {
    return _firestore.collection('arrivals').add({
      'ownerUid': ownerUid,
      'locationId': locationId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/repositories/arrival_repository_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Add the button in `lib/screens/locations_screen.dart`**

Add the import:
```dart
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../repositories/arrival_repository.dart';
```

In the `ListTile` built for each location (inside the `data:` branch of `locationsAsync.when`), add a leading-icon-button-style trailing action alongside the existing `Switch` — wrap the current `trailing: Switch(...)` in a `Row(mainAxisSize: MainAxisSize.min, children: [...])` containing an `IconButton` (icon `Icons.notifications_active`, tooltip `'Simular chegada'`) followed by the existing `Switch`:

```dart
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_active),
                      tooltip: 'Simular chegada',
                      onPressed: () {
                        ArrivalRepository(ref.read(firestoreProvider)).recordArrival(
                          ownerUid: ref.read(currentUidProvider),
                          locationId: loc.id,
                          message: loc.message,
                        );
                        AppSnackbar.showConfirmation(context, 'Chegada simulada em ${loc.name}!');
                      },
                    ),
                    Switch(
                      value: loc.isActive,
                      onChanged: (val) {
                        ref.read(locationRepositoryProvider).toggleLocation(loc.id, val);
                        AppSnackbar.showConfirmation(
                          context,
                          '${loc.name} ${val ? 'ativado' : 'desativado'}',
                        );
                      },
                    ),
                  ],
                ),
```

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS. (No new widget test is added for the button itself here — it's a thin call into an already-tested repository; a manual check is listed in Task 11.)

- [ ] **Step 7: Commit**

```bash
git add lib/repositories/arrival_repository.dart lib/screens/locations_screen.dart test/repositories/arrival_repository_test.dart
git commit -m "feat: add manual arrival-simulation button per location"
```

---

### Task 10: Cloud Function — send push on arrival

**Files:**
- Create: `functions/src/resolveRecipientTokens.ts`
- Create: `functions/src/index.ts`
- Test: `functions/src/resolveRecipientTokens.test.ts`

This task assumes Task 1 already ran `firebase init functions` (TypeScript), so `functions/package.json`, `functions/tsconfig.json`, and `functions/.eslintrc.js` already exist. If `functions/` doesn't exist yet, stop and report BLOCKED — Task 1 must be completed first.

**Interfaces:**
- Produces: `resolveRecipientTokens(db: Firestore, ownerUid: string): Promise<string[]>` (pure Firestore read, no messaging) and the exported Cloud Function `onArrivalCreated`, a Firestore-triggered function on `arrivals/{arrivalId}` that calls it and sends via `getMessaging().sendEachForMulticast(...)`.

- [ ] **Step 1: Add test dependencies**

Run these from inside `functions/`:
```bash
npm install --save firebase-admin firebase-functions
npm install --save-dev firebase-functions-test jest ts-jest @types/jest
```

Add to `functions/package.json`'s `"scripts"` section:
```json
"test": "jest"
```

Create `functions/jest.config.js`:
```js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
};
```

- [ ] **Step 2: Write the failing test**

Create `functions/src/resolveRecipientTokens.test.ts`:

```typescript
import * as admin from "firebase-admin";
import { resolveRecipientTokens } from "./resolveRecipientTokens";

describe("resolveRecipientTokens", () => {
  let app: admin.app.App;

  beforeAll(() => {
    process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";
    app = admin.initializeApp({ projectId: "toaqui-test" });
  });

  afterAll(async () => {
    await app.delete();
  });

  it("returns tokens only for contacts that have a linkedUid and a saved fcmToken", async () => {
    const db = admin.firestore();

    await db.collection("users").doc("owner-uid").collection("contacts").doc("c1").set({
      name: "Mãe",
      relationship: "Mãe",
      linkedUid: "family-1",
    });
    await db.collection("users").doc("owner-uid").collection("contacts").doc("c2").set({
      name: "Amor",
      relationship: "Parceiro(a)",
      linkedUid: null,
    });
    await db.collection("users").doc("family-1").set({ fcmToken: "token-abc" });

    const tokens = await resolveRecipientTokens(db, "owner-uid");

    expect(tokens).toEqual(["token-abc"]);
  });

  it("returns an empty array when the owner has no contacts", async () => {
    const db = admin.firestore();
    const tokens = await resolveRecipientTokens(db, "nobody-uid");
    expect(tokens).toEqual([]);
  });
});
```

- [ ] **Step 3: Run it to verify it fails**

From `functions/`, run: `firebase emulators:exec --only firestore "npm test"`
Expected: FAIL — `./resolveRecipientTokens` doesn't exist yet.

- [ ] **Step 4: Implement `functions/src/resolveRecipientTokens.ts`**

```typescript
import { Firestore } from "firebase-admin/firestore";

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
```

- [ ] **Step 5: Run the test to verify it passes**

From `functions/`, run: `firebase emulators:exec --only firestore "npm test"`
Expected: PASS (2 tests).

- [ ] **Step 6: Implement `functions/src/index.ts`**

```typescript
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { resolveRecipientTokens } from "./resolveRecipientTokens";

initializeApp();

export const onArrivalCreated = onDocumentCreated("arrivals/{arrivalId}", async (event) => {
  const snap = event.data;
  if (!snap) return;

  const { ownerUid, message } = snap.data() as { ownerUid: string; message: string };
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
});
```

- [ ] **Step 7: Type-check and build**

From `functions/`, run: `npm run build` (the scaffolded `firebase init functions` project includes this script; it runs `tsc`). Expected: no type errors.

- [ ] **Step 8: Commit**

```bash
git add functions/src/resolveRecipientTokens.ts functions/src/resolveRecipientTokens.test.ts functions/src/index.ts functions/package.json functions/jest.config.js functions/package-lock.json
git commit -m "feat: send FCM push to linked contacts when an arrival is recorded"
```

---

### Task 12: Wire deferred Firebase bootstrap into `main.dart` (only after Task 1 is complete)

**Do not dispatch this task until the human partner confirms Task 1 is done** (`lib/firebase_options.dart` exists, Anonymous auth + Firestore are enabled, Blaze plan is active). This task performs the two edits that Tasks 2 and 8 deferred.

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AuthService` (Task 2), `FcmService` (Task 8) — both already implemented and tested; this task only wires them into the app's entry point.

- [ ] **Step 1: Confirm the prerequisite file exists**

Run: `ls lib/firebase_options.dart`
Expected: file exists. If it doesn't, STOP and report BLOCKED — Task 1 isn't actually done yet.

- [ ] **Step 2: Apply Task 2's originally-deferred `main.dart` edit**

Add these imports (alongside the existing ones, replacing the commented-out `// import 'package:firebase_core/firebase_core.dart';` / `// import 'firebase_options.dart';` lines):

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
```

Replace the `void main() async { ... }` function body with:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final uid = await AuthService(FirebaseAuth.instance).signInAnonymously();
  await FcmService(FirebaseFirestore.instance).registerToken(uid);
  runApp(const ProviderScope(child: ToAquiApp()));
}
```

This combines Task 2 Step 7 and Task 8 Step 6 into one edit, since Task 8's line depends on the `uid` this same edit introduces.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: PASS — including `test/widget_test.dart`, which imports `main.dart` and will now exercise the real (not deferred) bootstrap path for the first time.

- [ ] **Step 4: Manual check — run the app for real**

Run: `flutter run -d chrome` (or a device). Confirm the app launches without a Firebase-related crash, and that opening DevTools/the Firestore console shows a new `users/{uid}` document appear shortly after launch (proof anonymous sign-in and FCM token registration both worked).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire anonymous auth and FCM registration into app startup"
```

---

### Task 13: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass (Tasks 2-9 each contributed tests).

- [ ] **Step 2: Static analysis**

Run: `flutter analyze`
Expected: no errors. Review any warnings; fix trivial ones (unused imports left over from the provider rewrites in Tasks 3/4/6), leave anything pre-existing and out of scope (the already-known `geofence_service_handler.dart` errors) untouched.

- [ ] **Step 3: Run the Cloud Functions test suite once more from a clean install**

From `functions/`, run: `npm install && npm run build && firebase emulators:exec --only firestore "npm test"`
Expected: PASS.

- [ ] **Step 4: [MANUAL — human partner] Deploy and do one real end-to-end check**

This step needs a live Firebase project and cannot be done by a subagent:
- [ ] `firebase deploy --only functions` from the project root.
- [ ] Run the app on two devices/emulators (or one device + your own phone). On device A, add a contact and note the invite code. On device B, open "Tenho um convite," redeem the code.
- [ ] On device A's Locations screen, tap "Simular chegada" for a location.
- [ ] Confirm device B receives a real push notification with that location's message within a few seconds.
- [ ] If it doesn't arrive: check the Cloud Function's logs (`firebase functions:log`) for errors, and confirm device B actually has a `fcmToken` saved under `users/{its-uid}` in the Firestore console.

- [ ] **Step 5: Final commit (only if Step 2 produced fixes)**

```bash
git add -A
git commit -m "chore: address flutter analyze findings from family invite/notifications pass"
```
