# Visual Redesign v2 (Home / Locais / Contatos) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle Home, Locais, and Contatos to match the human partner's reference mockups, backing every number/list the mockups show with real data.

**Architecture:** Add a few small theme tokens (card radius, hero gradient) to the existing `AppTheme`; add one new Firestore read path (`ArrivalRepository.watchArrivals`) plus three small derived Riverpod providers for the stat counts; add an `icon` (emoji) field to `LocationModel`; then restyle the three screens on top of that data, converting `LocationsScreen`/`ContactsScreen` to tabbed layouts and `EmergencyButton`'s visuals to a full-width banner.

**Tech Stack:** Flutter, Riverpod, `cloud_firestore`, `fake_cloud_firestore` (tests), `go_router`.

## Global Constraints

- Palette stays Teal `#2A9D8F` / Coral `#F4A261` (`lib/theme/app_theme.dart`) — this is a restyle, not a new palette.
- No deep linking / shareable URL for invites — the invite mechanism stays the existing 6-character code.
- No contact photo upload — avatars stay an initial in a colored circle.
- No contact phone number field.
- No reverse geocoding — location cards show coordinates/radius, not a street address.
- No real background monitoring — the "Monitoramento ativo" pill and "Tudo funcionando normalmente." line are fixed, optimistic visual copy.
- The Home AppBar's bell and 3-dot icons are visual only — `onPressed: () {}`, no destination, in this pass.
- The Home "Ver todas" link next to "Últimas chegadas" is visual only in this pass — no destination screen.
- The Home invite card is a shortcut into the existing Contatos add-contact flow (`ContactsScreen(autoOpenAdd: true)` via `/contacts?openAdd=true`), never a new invite mechanism.
- No test may hit a live Firebase project — use `fake_cloud_firestore`/`firebase_auth_mocks`, matching every other test on this branch.
- Spec reference: `docs/superpowers/specs/2026-08-01-visual-redesign-v2-design.md`

---

### Task 1: Theme tokens for the redesign

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Test: `test/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppRadius.card` (`double`, `20.0`), `AppShadows.soft` (`List<BoxShadow>`), `AppTheme.heroGradient` (`LinearGradient`, 2 teal-family colors) — all consumed by Task 8's Home hero card.

- [ ] **Step 1: Write the failing test**

Add to `test/theme/app_theme_test.dart`, inside the existing `main()`:

```dart
  test('exposes a card radius token and a two-color teal hero gradient', () {
    expect(AppRadius.card, 20.0);
    expect(AppShadows.soft, isNotEmpty);
    expect(AppTheme.heroGradient.colors, hasLength(2));
    expect(AppTheme.heroGradient.colors.last, AppColors.teal);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: FAIL — `AppRadius`, `AppShadows`, and `AppTheme.heroGradient` don't exist yet.

- [ ] **Step 3: Implement the tokens**

In `lib/theme/app_theme.dart`, add a new class after `AppColors` and a static field inside `AppTheme`:

```dart
class AppRadius {
  static const card = 20.0;
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
```

Inside the `AppTheme` class, add:

```dart
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F7A6E), AppColors.teal],
  );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart test/theme/app_theme_test.dart
git commit -m "feat: add card radius and hero gradient theme tokens"
```

---

### Task 2: Real arrival history read path

**Files:**
- Create: `lib/models/arrival_record.dart`
- Modify: `lib/repositories/arrival_repository.dart`
- Modify: `firestore.indexes.json`
- Test: `test/repositories/arrival_repository_test.dart`

**Interfaces:**
- Consumes: `arrivals` top-level collection, documents shaped `{ownerUid, locationId, message, createdAt}` (unchanged, from the existing `recordArrival`).
- Produces: `ArrivalRecord` (`id`, `locationId`, `message`, `createdAt` — all required) and `ArrivalRepository.watchArrivals(String ownerUid) → Stream<List<ArrivalRecord>>`, both consumed by Task 3's `arrivalsThisMonthCountProvider` and Task 8's Home screen.

- [ ] **Step 1: Write the failing test**

Add to `test/repositories/arrival_repository_test.dart`, inside the existing `main()`:

```dart
  test('watchArrivals only returns arrivals for the given owner', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ArrivalRepository(firestore);

    await repo.recordArrival(ownerUid: 'owner-uid', locationId: 'loc-1', message: 'Cheguei em casa!');
    await repo.recordArrival(ownerUid: 'owner-uid', locationId: 'loc-2', message: 'Cheguei no trabalho!');
    await repo.recordArrival(ownerUid: 'other-uid', locationId: 'loc-3', message: 'Não deveria aparecer');

    final result = await repo.watchArrivals('owner-uid').first;

    expect(result, hasLength(2));
    expect(result.map((a) => a.locationId), containsAll(['loc-1', 'loc-2']));
    expect(result.every((a) => a.locationId != 'loc-3'), isTrue);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/arrival_repository_test.dart`
Expected: FAIL — `watchArrivals` doesn't exist yet.

- [ ] **Step 3: Create the `ArrivalRecord` model**

Create `lib/models/arrival_record.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArrivalRecord {
  final String id;
  final String locationId;
  final String message;
  final DateTime createdAt;

  ArrivalRecord({
    required this.id,
    required this.locationId,
    required this.message,
    required this.createdAt,
  });

  factory ArrivalRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return ArrivalRecord(
      id: id,
      locationId: map['locationId'] as String,
      message: map['message'] as String,
      // A just-written doc can be read back before the server timestamp
      // resolves (optimistic local snapshot); fall back to now() rather
      // than crash on a null cast.
      createdAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Implement `watchArrivals`**

In `lib/repositories/arrival_repository.dart`, add the import and method:

```dart
import '../models/arrival_record.dart';
```

```dart
  Stream<List<ArrivalRecord>> watchArrivals(String ownerUid) {
    return _firestore
        .collection('arrivals')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ArrivalRecord.fromMap(doc.id, doc.data())).toList());
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/repositories/arrival_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Add the required Firestore composite index**

`where('ownerUid', ...).orderBy('createdAt', ...)` on two different fields requires a composite index in real Firestore (not enforced by `fake_cloud_firestore`, so this won't show up in tests — it fails silently until deployed). Replace the contents of `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "arrivals",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Note for the controller (not the implementer subagent):** after this task is reviewed, run `firebase deploy --only firestore:indexes --project=toaqui-familia-app` to actually publish the index — it's free (no Blaze needed) but requires the authenticated Firebase CLI session already set up on this machine.

- [ ] **Step 7: Commit**

```bash
git add lib/models/arrival_record.dart lib/repositories/arrival_repository.dart firestore.indexes.json test/repositories/arrival_repository_test.dart
git commit -m "feat: add ArrivalRepository.watchArrivals for real arrival history"
```

---

### Task 3: Derived stat-count providers

**Files:**
- Create: `lib/providers/arrival_provider.dart`
- Create: `lib/providers/stats_provider.dart`
- Test: `test/providers/stats_provider_test.dart`

**Interfaces:**
- Consumes: `ArrivalRepository.watchArrivals` (Task 2), `locationsStreamProvider` (existing), `contactsStreamProvider` (existing).
- Produces: `arrivalRepositoryProvider`, `arrivalsStreamProvider` (`StreamProvider<List<ArrivalRecord>>`), `activeLocationsCountProvider`, `linkedContactsCountProvider`, `arrivalsThisMonthCountProvider` (all `Provider<int>`) — all consumed by Task 8's Home screen.

- [ ] **Step 1: Write the failing test**

Create `test/providers/stats_provider_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/arrival_provider.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/providers/location_provider.dart';
import 'package:to_aqui/providers/stats_provider.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';

void main() {
  ProviderContainer buildContainer(FakeFirebaseFirestore firestore) {
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(firestore),
      currentUidProvider.overrideWithValue('owner-uid'),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('activeLocationsCountProvider counts only active locations', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    await container.read(locationRepositoryProvider).addLocation(
          LocationModel(name: 'Casa', latitude: 0, longitude: 0, radius: 50, message: 'x'),
        );
    await container.read(locationRepositoryProvider).addLocation(
          LocationModel(
            name: 'Inativo',
            latitude: 0,
            longitude: 0,
            radius: 50,
            message: 'x',
            isActive: false,
          ),
        );
    await container.read(locationsStreamProvider.future);

    expect(container.read(activeLocationsCountProvider), 1);
  });

  test('linkedContactsCountProvider counts only linked contacts', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    final repo = container.read(contactRepositoryProvider);
    final linked = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(linked);
    await repo.linkContact(linked.id, 'family-uid');
    await repo.addContact(ContactModel(name: 'Pendente', relationship: 'Amigo'));
    await container.read(contactsStreamProvider.future);

    expect(container.read(linkedContactsCountProvider), 1);
  });

  test('arrivalsThisMonthCountProvider counts arrivals from the current month', () async {
    final firestore = FakeFirebaseFirestore();
    final container = buildContainer(firestore);

    await ArrivalRepository(firestore).recordArrival(
      ownerUid: 'owner-uid',
      locationId: 'loc-1',
      message: 'x',
    );
    await container.read(arrivalsStreamProvider.future);

    expect(container.read(arrivalsThisMonthCountProvider), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/stats_provider_test.dart`
Expected: FAIL — none of the new provider files exist yet.

- [ ] **Step 3: Create `lib/providers/arrival_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/arrival_repository.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';

final arrivalRepositoryProvider = Provider<ArrivalRepository>((ref) {
  return ArrivalRepository(ref.watch(firestoreProvider));
});

final arrivalsStreamProvider = StreamProvider((ref) {
  return ref.watch(arrivalRepositoryProvider).watchArrivals(ref.watch(currentUidProvider));
});
```

- [ ] **Step 4: Create `lib/providers/stats_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'arrival_provider.dart';
import 'contact_provider.dart';
import 'location_provider.dart';

final activeLocationsCountProvider = Provider<int>((ref) {
  final locations = ref.watch(locationsStreamProvider).value ?? [];
  return locations.where((location) => location.isActive).length;
});

final linkedContactsCountProvider = Provider<int>((ref) {
  final contacts = ref.watch(contactsStreamProvider).value ?? [];
  return contacts.where((contact) => contact.linkedUid != null).length;
});

final arrivalsThisMonthCountProvider = Provider<int>((ref) {
  final arrivals = ref.watch(arrivalsStreamProvider).value ?? [];
  final now = DateTime.now();
  return arrivals
      .where((arrival) =>
          arrival.createdAt.year == now.year && arrival.createdAt.month == now.month)
      .length;
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/providers/stats_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/providers/arrival_provider.dart lib/providers/stats_provider.dart test/providers/stats_provider_test.dart
git commit -m "feat: add derived stat-count providers for locations/contacts/arrivals"
```

---

### Task 4: Location icon field

**Files:**
- Modify: `lib/models/location_model.dart`
- Modify: `lib/screens/add_location_screen.dart`
- Test: `test/repositories/location_repository_test.dart`

**Interfaces:**
- Produces: `LocationModel.icon` (`String`, defaults to `'📍'` in the constructor and in `fromMap` for documents saved before this field existed) — consumed by Task 5 (Locais cards) and Task 8 (Home arrivals list).

- [ ] **Step 1: Write the failing test**

Add to `test/repositories/location_repository_test.dart`, inside the existing `main()`:

```dart
  test('addLocation persists a custom icon', () async {
    await repo.addLocation(LocationModel(
      name: 'Escritório',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'x',
      icon: '🏢',
    ));

    final result = await repo.watchLocations().first;
    expect(result.single.icon, '🏢');
  });

  test('fromMap defaults icon to a pin for documents saved before the field existed', () {
    final location = LocationModel.fromMap({
      'id': 'loc-1',
      'name': 'Antigo',
      'latitude': 0.0,
      'longitude': 0.0,
      'radius': 50.0,
      'message': 'x',
      'isActive': true,
    });

    expect(location.icon, '📍');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/location_repository_test.dart`
Expected: FAIL — `LocationModel` has no `icon` parameter/field yet.

- [ ] **Step 3: Add the field to `LocationModel`**

In `lib/models/location_model.dart`, add `final String icon;` next to the other fields, `this.icon = '📍'` in the constructor, `String? icon` in `copyWith` (with `icon: icon ?? this.icon`), `'icon': icon` in `toMap`, and `icon: map['icon'] ?? '📍'` in `fromMap`. The full file:

```dart
import 'package:uuid/uuid.dart';

class LocationModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // em metros
  final String message;
  final bool isActive;
  final String icon;

  LocationModel({
    String? id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.message,
    this.isActive = true,
    this.icon = '📍',
  }) : id = id ?? const Uuid().v4();

  LocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    String? message,
    bool? isActive,
    String? icon,
  }) {
    return LocationModel(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      message: message ?? this.message,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'message': message,
      'isActive': isActive,
      'icon': icon,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      radius: map['radius'],
      message: map['message'],
      isActive: map['isActive'],
      icon: map['icon'] ?? '📍',
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/location_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Add an icon picker to `AddLocationScreen`**

In `lib/screens/add_location_screen.dart`, add a state field alongside `_radius`:

```dart
  String _selectedIcon = '📍';
  static const _iconChoices = ['📍', '🏠', '🏢', '🎓', '🏥', '🛒'];
```

In `_saveLocation`, add `icon: _selectedIcon` to the `LocationModel(...)` constructor call (alongside the existing `message:` argument).

In `build`, inside the `ListView` of the `DraggableScrollableSheet` builder, insert this after the `Text('Raio de detecção: ...')`/`Slider` block and before the message `TextField`:

```dart
                    const SizedBox(height: 8),
                    const Text('Ícone'),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: _iconChoices.map((icon) {
                        final selected = icon == _selectedIcon;
                        return ChoiceChip(
                          label: Text(icon, style: const TextStyle(fontSize: 20)),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedIcon = icon),
                        );
                      }).toList(),
                    ),
```

- [ ] **Step 6: Run the full suite to confirm no regression**

Run: `flutter test`
Expected: PASS (no existing test targets `AddLocationScreen`'s widget tree directly, per current test coverage — this step is a safety check, not expected to reveal new failures).

- [ ] **Step 7: Commit**

```bash
git add lib/models/location_model.dart lib/screens/add_location_screen.dart test/repositories/location_repository_test.dart
git commit -m "feat: add an emoji icon field to locations, with a picker on creation"
```

---

### Task 5: Locais screen redesign

**Files:**
- Modify: `lib/screens/locations_screen.dart`
- Create: `test/screens/locations_screen_test.dart`

**Interfaces:**
- Consumes: `locationsStreamProvider`, `locationRepositoryProvider` (existing), `LocationModel.icon` (Task 4).

- [ ] **Step 1: Write the failing test**

Create `test/screens/locations_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/location_repository.dart';
import 'package:to_aqui/screens/locations_screen.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: LocationsScreen()),
    );
  }

  testWidgets('Ativos tab shows only active locations, Inativos only inactive ones', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = LocationRepository(firestore, 'owner-uid');
    await repo.addLocation(
      LocationModel(name: 'Trabalho', latitude: 0, longitude: 0, radius: 50, message: 'x'),
    );
    await repo.addLocation(LocationModel(
      name: 'Faculdade',
      latitude: 0,
      longitude: 0,
      radius: 50,
      message: 'x',
      isActive: false,
    ));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Faculdade'), findsNothing);

    await tester.tap(find.text('Inativos'));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsNothing);
    expect(find.text('Faculdade'), findsOneWidget);
  });

  testWidgets('Simular chegada from the overflow menu records an arrival', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = LocationRepository(firestore, 'owner-uid');
    await repo.addLocation(
      LocationModel(name: 'Casa', latitude: 0, longitude: 0, radius: 50, message: 'Cheguei em casa!'),
    );

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simular chegada'));
    await tester.pumpAndSettle();

    final docs = (await firestore.collection('arrivals').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['message'], 'Cheguei em casa!');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/locations_screen_test.dart`
Expected: FAIL — no tabs exist yet, so "Inativos" isn't found; the overflow `PopupMenuButton` doesn't exist yet either.

- [ ] **Step 3: Rewrite `lib/screens/locations_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/location_provider.dart';
import '../repositories/arrival_repository.dart';
import '../models/location_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_snackbar.dart';

class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meus Locais'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Ativos'), Tab(text: 'Inativos')],
          ),
        ),
        body: locationsAsync.when(
          loading: () => ListView(
            children: const [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()],
          ),
          error: (error, stack) => Center(child: Text('Erro ao carregar locais: $error')),
          data: (locations) {
            final active = locations.where((l) => l.isActive).toList();
            final inactive = locations.where((l) => !l.isActive).toList();
            return TabBarView(
              children: [
                _LocationList(locations: active, emptyTitle: 'Nenhum local ativo'),
                _LocationList(locations: inactive, emptyTitle: 'Nenhum local inativo'),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/locations/add'),
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Novo Local'),
        ),
      ),
    );
  }
}

class _LocationList extends ConsumerWidget {
  final List<LocationModel> locations;
  final String emptyTitle;

  const _LocationList({required this.locations, required this.emptyTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (locations.isEmpty) {
      return EmptyState(
        emoji: '📍',
        title: emptyTitle,
        subtitle: 'Adicione um local para começar a avisar sua família',
      );
    }
    return ListView.builder(
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(loc.icon, style: const TextStyle(fontSize: 20))),
            title: Text(loc.name),
            subtitle: Text('Raio: ${loc.radius.toInt()}m'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(loc.isActive ? 'Ativo' : 'Inativo'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: loc.isActive
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'simulate') {
                      ArrivalRepository(ref.read(firestoreProvider)).recordArrival(
                        ownerUid: ref.read(currentUidProvider),
                        locationId: loc.id,
                        message: loc.message,
                      );
                      AppSnackbar.showConfirmation(context, 'Chegada simulada em ${loc.name}!');
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'simulate', child: Text('Simular chegada')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/locations_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/locations_screen.dart test/screens/locations_screen_test.dart
git commit -m "feat: redesign Locais screen with Ativos/Inativos tabs"
```

---

### Task 6: Contatos screen redesign + Home invite shortcut wiring

**Files:**
- Modify: `lib/screens/contacts_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/screens/contacts_screen_test.dart`

**Interfaces:**
- Consumes: `contactsStreamProvider`, `contactRepositoryProvider`, `showAddContactSheet` (all existing).
- Produces: `ContactsScreen({bool autoOpenAdd = false})` — consumed by Task 8's Home invite card via the `/contacts?openAdd=true` route.

- [ ] **Step 1: Write the failing tests**

Add to `test/screens/contacts_screen_test.dart` (existing file — add these imports alongside the current ones, and these two tests inside the existing `main()`, after the existing test):

```dart
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/repositories/contact_repository.dart';
```

```dart
  testWidgets('Pendentes tab shows only contacts without a linked uid', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = ContactRepository(firestore, 'owner-uid');
    final linked = ContactModel(name: 'Mãe', relationship: 'Mãe');
    await repo.addContact(linked);
    await repo.linkContact(linked.id, 'family-uid');
    await repo.addContact(ContactModel(name: 'Convidado', relationship: 'Amigo'));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsOneWidget);
    expect(find.text('Convidado'), findsOneWidget);

    await tester.tap(find.text('Pendentes'));
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsNothing);
    expect(find.text('Convidado'), findsOneWidget);
  });

  testWidgets('autoOpenAdd opens the add-contact sheet on first frame', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: ContactsScreen(autoOpenAdd: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contact-name-field')), findsOneWidget);
  });

  testWidgets('shows an invite footer card below the contact list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repo = ContactRepository(firestore, 'owner-uid');
    await repo.addContact(ContactModel(name: 'Mãe', relationship: 'Mãe'));

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Convide novos contatos'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/contacts_screen_test.dart`
Expected: FAIL — no "Pendentes" tab exists yet, `ContactsScreen` has no `autoOpenAdd` parameter, and there's no invite footer card.

- [ ] **Step 3: Rewrite `lib/screens/contacts_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  final bool autoOpenAdd;

  const ContactsScreen({super.key, this.autoOpenAdd = false});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addContact(context);
      });
    }
  }

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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsStreamProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Família e Contatos'),
          bottom: const TabBar(tabs: [Tab(text: 'Todos'), Tab(text: 'Pendentes')]),
        ),
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
            final pending = contacts.where((c) => c.linkedUid == null).toList();
            return Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      _ContactList(contacts: contacts, onDelete: _deleteContact),
                      _ContactList(contacts: pending, onDelete: _deleteContact),
                    ],
                  ),
                ),
                _InviteFooterCard(onInvite: () => _addContact(context)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addContact(context),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Adicionar'),
        ),
      ),
    );
  }

  void _deleteContact(String id) {
    ref.read(contactRepositoryProvider).deleteContact(id);
  }
}

class _InviteFooterCard extends StatelessWidget {
  final VoidCallback onInvite;

  const _InviteFooterCard({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Convide novos contatos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Compartilhe o convite para que possam acompanhar suas chegadas.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onInvite, child: const Text('Convidar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  final List<ContactModel> contacts;
  final void Function(String id) onDelete;

  const _ContactList({required this.contacts, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Nenhum contato aqui',
        subtitle: 'Contatos pendentes aparecem aqui até aceitarem o convite',
      );
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Text(contact.name.isNotEmpty ? contact.name[0] : '?')),
            title: Text(contact.name),
            subtitle: Text(
              contact.linkedUid == null ? 'Convite pendente' : 'Recebe todas as notificações',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(label: Text(contact.relationship), visualDensity: VisualDensity.compact),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') onDelete(contact.id);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Remover')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Wire the `openAdd` query parameter in `lib/main.dart`**

In `lib/main.dart`, find the `/contacts` route:

```dart
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
```

Replace it with:

```dart
          GoRoute(
            path: '/contacts',
            builder: (context, state) => ContactsScreen(
              autoOpenAdd: state.uri.queryParameters['openAdd'] == 'true',
            ),
          ),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/screens/contacts_screen_test.dart`
Expected: PASS — including the pre-existing "adding a contact shows a dialog with the invite code" test, unchanged.

- [ ] **Step 6: Run the full suite to confirm no regression**

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/screens/contacts_screen.dart lib/main.dart test/screens/contacts_screen_test.dart
git commit -m "feat: redesign Contatos screen with Todos/Pendentes tabs and autoOpenAdd"
```

---

### Task 7: SOS banner restyle

**Files:**
- Modify: `lib/widgets/emergency_button.dart`

**Interfaces:**
- Consumes/Produces: unchanged (`EmergencyButton({fetchLocation, holdDuration})`) — only `build()`'s widget tree changes, hold-to-confirm logic (`_startHold`/`_cancelHold`/`_trigger`) is untouched.

- [ ] **Step 1: Replace `build()`**

In `lib/widgets/emergency_button.dart`, replace the existing `build()` method with:

```dart
  @override
  Widget build(BuildContext context) {
    final coral = Theme.of(context).colorScheme.secondary;

    // Watching here (rather than only `ref.read`-ing inside `_trigger`) subscribes
    // to the contacts stream as soon as the button is built, so the linked-contacts
    // list is already loaded by the time the user completes a hold.
    ref.watch(contactsStreamProvider);

    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: coral),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _holdController.value,
                      heightFactor: 1,
                      child: Container(color: Colors.white.withOpacity(0.25)),
                    ),
                  ),
                  Center(
                    child: _sending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.sos, color: Colors.white, size: 20),
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Pressione por 3 segundos',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
```

- [ ] **Step 2: Run the existing tests to confirm no regression**

Run: `flutter test test/widgets/emergency_button_test.dart`
Expected: PASS, unchanged — all four existing tests locate the widget via `find.byType(EmergencyButton)` and gesture at its center, which still works against the new banner layout; none assert on the old circular shape.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/emergency_button.dart
git commit -m "feat: restyle EmergencyButton as a full-width SOS banner"
```

---

### Task 8: Home screen redesign

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Test: `test/screens/home_screen_test.dart`

**Interfaces:**
- Consumes: `arrivalsStreamProvider`, `activeLocationsCountProvider`, `linkedContactsCountProvider`, `arrivalsThisMonthCountProvider` (Task 3), `locationsStreamProvider` (existing), `AppRadius.card`/`AppShadows.soft`/`AppTheme.heroGradient` (Task 1), `EmergencyButton` (Task 7, usage unchanged), `ContactsScreen(autoOpenAdd: true)` via `/contacts?openAdd=true` (Task 6).
- Produces: `HomeScreen` with no constructor parameters (the old `arrivals`/`ArrivalEntry` injection seam is removed — this screen now always reads real data).

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/screens/home_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/location_model.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';
import 'package:to_aqui/repositories/arrival_repository.dart';
import 'package:to_aqui/repositories/location_repository.dart';
import 'package:to_aqui/screens/home_screen.dart';

void main() {
  Widget buildApp(FakeFirebaseFirestore firestore) {
    return ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(firestore),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('shows the empty state when there are no arrivals', (tester) async {
    await tester.pumpWidget(buildApp(FakeFirebaseFirestore()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma chegada registrada ainda'), findsWidgets);
  });

  testWidgets('shows the most recent arrival and real stat counts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final locationRepo = LocationRepository(firestore, 'owner-uid');
    await locationRepo.addLocation(
      LocationModel(name: 'Trabalho', latitude: 0, longitude: 0, radius: 100, message: 'x', icon: '🏢'),
    );
    final location = (await locationRepo.watchLocations().first).single;
    await ArrivalRepository(firestore).recordArrival(
      ownerUid: 'owner-uid',
      locationId: location.id,
      message: 'Cheguei!',
    );

    await tester.pumpWidget(buildApp(firestore));
    await tester.pumpAndSettle();

    expect(find.text('Trabalho'), findsWidgets);
    expect(find.text('Locais ativos'), findsOneWidget);
    expect(find.text('Chegadas este mês'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: FAIL — `HomeScreen` still expects an `arrivals` parameter and doesn't render stat labels yet.

- [ ] **Step 3: Rewrite `lib/screens/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/arrival_record.dart';
import '../models/location_model.dart';
import '../providers/arrival_provider.dart';
import '../providers/location_provider.dart';
import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/emergency_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrivalsAsync = ref.watch(arrivalsStreamProvider);
    final locationsAsync = ref.watch(locationsStreamProvider);
    final activeLocations = ref.watch(activeLocationsCountProvider);
    final linkedContacts = ref.watch(linkedContactsCountProvider);
    final arrivalsThisMonth = ref.watch(arrivalsThisMonthCountProvider);

    LocationModel? locationFor(String id) {
      final locations = locationsAsync.value ?? [];
      for (final loc in locations) {
        if (loc.id == id) return loc;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', height: 28),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ToAqui', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Sempre avisando quem importa.', style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(arrivalsAsync: arrivalsAsync, locationFor: locationFor),
              const SizedBox(height: 16),
              _StatsRow(
                activeLocations: activeLocations,
                linkedContacts: linkedContacts,
                arrivalsThisMonth: arrivalsThisMonth,
              ),
              const SizedBox(height: 16),
              const EmergencyButton(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Últimas chegadas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Text('Ver todas', style: TextStyle(color: AppColors.teal)),
                ],
              ),
              const SizedBox(height: 12),
              _ArrivalsList(
                arrivalsAsync: arrivalsAsync,
                locationFor: locationFor,
                linkedContacts: linkedContacts,
              ),
              const SizedBox(height: 24),
              _InviteCard(onInvite: () => context.go('/contacts?openAdd=true')),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AsyncValue<List<ArrivalRecord>> arrivalsAsync;
  final LocationModel? Function(String id) locationFor;

  const _HeroCard({required this.arrivalsAsync, required this.locationFor});

  @override
  Widget build(BuildContext context) {
    final arrivals = arrivalsAsync.value ?? [];
    final latest = arrivals.isEmpty ? null : arrivals.first;
    final latestLocation = latest == null ? null : locationFor(latest.locationId);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.shield, color: Colors.white),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Você está protegido',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Monitoramento ativo', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(height: 16),
          if (latest != null)
            Row(
              children: [
                const Icon(Icons.place, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${latestLocation?.name ?? 'Local'} • ${TimeOfDay.fromDateTime(latest.createdAt).format(context)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            )
          else
            const Text('Nenhuma chegada registrada ainda', style: TextStyle(color: Colors.white)),
          const Divider(color: Colors.white30, height: 24),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Tudo funcionando normalmente.', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int activeLocations;
  final int linkedContacts;
  final int arrivalsThisMonth;

  const _StatsRow({
    required this.activeLocations,
    required this.linkedContacts,
    required this.arrivalsThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String value, String label) {
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('$activeLocations', 'Locais ativos'),
        const SizedBox(width: 8),
        tile('$linkedContacts', 'Contatos avisados'),
        const SizedBox(width: 8),
        tile('$arrivalsThisMonth', 'Chegadas este mês'),
      ],
    );
  }
}

class _ArrivalsList extends StatelessWidget {
  final AsyncValue<List<ArrivalRecord>> arrivalsAsync;
  final LocationModel? Function(String id) locationFor;
  final int linkedContacts;

  const _ArrivalsList({
    required this.arrivalsAsync,
    required this.locationFor,
    required this.linkedContacts,
  });

  @override
  Widget build(BuildContext context) {
    return arrivalsAsync.when(
      loading: () => const Column(children: [SkeletonListTile(), SkeletonListTile()]),
      error: (error, stack) => Text('Erro ao carregar chegadas: $error'),
      data: (arrivals) {
        if (arrivals.isEmpty) {
          return const SizedBox(
            height: 280,
            child: EmptyState(
              emoji: '📭',
              title: 'Nenhuma chegada registrada ainda',
              subtitle: 'Quando você chegar a um local salvo, ele aparece aqui',
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: arrivals.length,
          itemBuilder: (context, index) {
            final arrival = arrivals[index];
            final location = locationFor(arrival.locationId);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text(location?.icon ?? '📍')),
                title: Text(location?.name ?? 'Local removido'),
                subtitle: const Text('Chegada registrada com sucesso'),
                trailing: Text('$linkedContacts contatos avisados', style: const TextStyle(fontSize: 11)),
              ),
            );
          },
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  final VoidCallback onInvite;

  const _InviteCard({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Convide seus contatos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Eles recebem um código de convite para acompanhar suas chegadas.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onInvite, child: const Text('Convidar')),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "feat: redesign Home screen with real hero card, stats, and arrivals list"
```

---

### Task 9: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full Flutter test suite**

Run: `flutter test`
Expected: all tests pass (Tasks 1-8 each contributed or updated tests; no test should reference the removed `ArrivalEntry`/`arrivals` parameter anymore).

- [ ] **Step 2: Static analysis**

Run: `dart analyze lib test` (per this branch's established caveat, plain `flutter analyze` has crashed intermittently in this sandbox — `dart analyze` is the fallback that has worked when it does).
Expected: no new errors. Pre-existing, out-of-scope issues (e.g. `geofence_service_handler.dart`) stay untouched.

- [ ] **Step 3: Manual check — run the app for real**

Run: `flutter run -d chrome`. Confirm: Home shows the hero card, three stat tiles, the SOS banner, and the invite card; Locais shows the Ativos/Inativos tabs; Contatos shows the Todos/Pendentes tabs; tapping the Home invite card navigates to Contatos and opens the add-contact sheet automatically.

- [ ] **Step 4: Report**

No commit for this task — it's a verification pass. If Step 1 or 2 finds a regression, fix it as part of the task that introduced it (resume that task's fix loop) rather than patching ad hoc here.
