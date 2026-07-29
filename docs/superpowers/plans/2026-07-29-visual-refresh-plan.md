# ToAqui Visual Refresh & Local UI Interactions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recolor ToAqui to the approved Teal & Coral "caloroso e familiar" identity, add consistent loading/empty/error UI states across the app, make the Família (Contacts) screen locally interactive, fix the cramped Add Location layout, and generate a placeholder app icon — all without touching Firebase, persistence, permissions, or real geofencing.

**Architecture:** Small, focused additions under `lib/theme/` and `lib/widgets/` provide the shared visual building blocks (colors, empty state, skeleton loaders, snackbar helper) that every screen task then consumes. Screens are modified in dependency order: theme first, then shared widgets, then the Contacts data layer, then each screen that uses these pieces.

**Tech Stack:** Flutter (Material 3), flutter_riverpod (StateNotifier/Provider), go_router, google_maps_flutter, uuid, flutter_launcher_icons (new dev dependency), Python + Pillow (one-off icon placeholder script, not part of the app).

## Global Constraints

- Palette (exact values): primary Teal `#2A9D8F`, accent Coral `#F4A261`, background cream `#F7F3ED`. Apply via `ColorScheme.fromSeed` overrides — no hardcoded competing colors in widgets.
- Out of scope for this plan (belongs to a future "technical foundation" spec): Firebase, cross-restart persistence, Android/iOS location permissions, Google Maps API key setup, real geofencing wiring, push notifications.
- Contacts ("Família") interactivity is local in-memory state only — no backend calls.
- Shared UI states (loading/empty/confirmation/error) must reuse one set of components (`SkeletonBox`/`SkeletonListTile`, `EmptyState`, `AppSnackbar`) rather than one-off implementations per screen.
- Automated tests are required for the Contacts provider (explicit spec requirement) and for every new reusable widget/provider this plan introduces. The Add Location screen's map/bottom-sheet interaction is verified manually only — `GoogleMap` requires a platform view that isn't available in the widget test environment.
- Spec reference: `docs/superpowers/specs/2026-07-29-visual-refresh-design.md`

---

### Task 1: Fix the stale default widget test

The existing `test/widget_test.dart` still references a nonexistent `MyApp` counter widget from the Flutter starter template — `flutter test` currently fails to even compile. This must be fixed before any new tests can run.

**Files:**
- Modify: `test/widget_test.dart` (full replace)

**Interfaces:**
- Consumes: `ToAquiApp` from `lib/main.dart` (already exists)

- [ ] **Step 1: Confirm the current test is broken**

Run: `flutter test`
Expected: FAIL — compile error, "Undefined name 'MyApp'" (or similar) referencing `test/widget_test.dart`.

- [ ] **Step 2: Replace the test with one that matches the real app**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:to_aqui/main.dart';

void main() {
  testWidgets('ToAquiApp renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ToAquiApp()));
    await tester.pumpAndSettle();

    expect(find.text('ToAqui'), findsWidgets);
    expect(find.text('Rastreamento Ativo'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS (1 test).

- [ ] **Step 4: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: fix stale default widget test to target ToAquiApp"
```

---

### Task 2: App theme (Teal & Coral palette)

**Files:**
- Create: `lib/theme/app_theme.dart`
- Modify: `lib/main.dart` (import + `theme:`/`darkTheme:` in `ToAquiApp.build`)
- Test: `test/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppColors.teal`, `AppColors.coral`, `AppColors.cream` (Color constants); `AppTheme.light()` and `AppTheme.dark()` returning `ThemeData`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/theme/app_theme.dart';

void main() {
  test('light theme uses the teal primary, coral secondary and cream background', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, AppColors.teal);
    expect(theme.colorScheme.secondary, AppColors.coral);
    expect(theme.scaffoldBackgroundColor, AppColors.cream);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('dark theme uses the teal primary and coral secondary', () {
    final theme = AppTheme.dark();

    expect(theme.colorScheme.primary, AppColors.teal);
    expect(theme.colorScheme.secondary, AppColors.coral);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: FAIL — "Error: Couldn't resolve the package 'to_aqui' in 'package:to_aqui/theme/app_theme.dart'" (file doesn't exist yet).

- [ ] **Step 3: Implement `lib/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const teal = Color(0xFF2A9D8F);
  static const coral = Color(0xFFF4A261);
  static const cream = Color(0xFFF7F3ED);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.light,
        primary: AppColors.teal,
        secondary: AppColors.coral,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        brightness: Brightness.dark,
        primary: AppColors.teal,
        secondary: AppColors.coral,
      ),
    );
  }
}
```

- [ ] **Step 4: Wire it into `lib/main.dart`**

Add the import after the existing `go_router` import (around line 3):

```dart
import 'theme/app_theme.dart';
```

Replace the `theme:`/`darkTheme:` block inside `ToAquiApp.build` (currently the `ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B4D8), ...` block):

```dart
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Manual check — bottom navigation recolors automatically**

Run: `flutter run -d chrome`
Expected: The bottom `NavigationBar` (Início/Locais/Família) picks up the new teal/coral tones automatically — it reads colors from `ColorScheme`, so no code change is needed there. Just confirm visually; if it still looks cyan, check that `MaterialApp.router`'s `theme`/`darkTheme` were actually replaced in Step 4.

- [ ] **Step 7: Commit**

```bash
git add lib/theme/app_theme.dart lib/main.dart test/theme/app_theme_test.dart
git commit -m "feat: replace cyan theme with Teal & Coral palette"
```

---

### Task 3: `EmptyState` shared widget

**Files:**
- Create: `lib/widgets/empty_state.dart`
- Test: `test/widgets/empty_state_test.dart`

**Interfaces:**
- Produces: `EmptyState({required String emoji, required String title, required String subtitle, String? ctaLabel, VoidCallback? onCtaPressed})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/widgets/empty_state.dart';

void main() {
  testWidgets('shows emoji, title, subtitle and calls onCtaPressed when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: EmptyState(
        emoji: '👨‍👩‍👧‍👦',
        title: 'Sua família ainda não está por aqui',
        subtitle: 'Convide quem você ama',
        ctaLabel: 'Convidar familiar',
        onCtaPressed: () => tapped = true,
      ),
    ));

    expect(find.text('👨‍👩‍👧‍👦'), findsOneWidget);
    expect(find.text('Sua família ainda não está por aqui'), findsOneWidget);
    expect(find.text('Convide quem você ama'), findsOneWidget);

    await tester.tap(find.text('Convidar familiar'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('hides the CTA button when ctaLabel is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EmptyState(emoji: '📭', title: 'Vazio', subtitle: 'Nada aqui'),
    ));

    expect(find.byType(FilledButton), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/empty_state_test.dart`
Expected: FAIL — `lib/widgets/empty_state.dart` doesn't exist yet.

- [ ] **Step 3: Implement the widget**

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onCtaPressed,
                style: FilledButton.styleFrom(backgroundColor: colorScheme.secondary),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/empty_state_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/empty_state.dart test/widgets/empty_state_test.dart
git commit -m "feat: add reusable EmptyState widget"
```

---

### Task 4: Skeleton loading widgets

**Files:**
- Create: `lib/widgets/skeleton.dart`
- Test: `test/widgets/skeleton_test.dart`

**Interfaces:**
- Produces: `SkeletonBox({required double width, required double height, BorderRadius borderRadius})`, `SkeletonListTile()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/widgets/skeleton.dart';

void main() {
  testWidgets('SkeletonBox renders at the given size', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SkeletonBox(width: 100, height: 20),
    ));

    final size = tester.getSize(find.byType(SkeletonBox));
    expect(size, const Size(100, 20));
  });

  testWidgets('SkeletonListTile renders an avatar box and two line boxes', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SkeletonListTile()),
    ));

    expect(find.byType(SkeletonBox), findsNWidgets(3));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/skeleton_test.dart`
Expected: FAIL — `lib/widgets/skeleton.dart` doesn't exist yet.

- [ ] **Step 3: Implement the widgets**

```dart
import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: widget.borderRadius,
          ),
        ),
      ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const SkeletonBox(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/skeleton_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/skeleton.dart test/widgets/skeleton_test.dart
git commit -m "feat: add SkeletonBox and SkeletonListTile loading widgets"
```

---

### Task 5: `AppSnackbar` helper (confirmation + error)

**Files:**
- Create: `lib/widgets/app_snackbar.dart`
- Test: `test/widgets/app_snackbar_test.dart`

**Interfaces:**
- Consumes: `AppColors` from `lib/theme/app_theme.dart` (Task 2).
- Produces: `AppSnackbar.showConfirmation(BuildContext, String message)`, `AppSnackbar.showError(BuildContext, String message)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/theme/app_theme.dart';
import 'package:to_aqui/widgets/app_snackbar.dart';

void main() {
  testWidgets('showConfirmation displays the message with the teal accent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AppSnackbar.showConfirmation(context, 'Casa desativado'),
          child: const Text('trigger'),
        ),
      ),
    ));

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('Casa desativado'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppColors.teal);
  });

  testWidgets('showError displays the message with the coral accent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AppSnackbar.showError(context, 'Algo deu errado'),
          child: const Text('trigger'),
        ),
      ),
    ));

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('Algo deu errado'), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppColors.coral);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/app_snackbar_test.dart`
Expected: FAIL — `lib/widgets/app_snackbar.dart` doesn't exist yet.

- [ ] **Step 3: Implement the helper**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSnackbar {
  static void showConfirmation(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.coral,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/app_snackbar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/app_snackbar.dart test/widgets/app_snackbar_test.dart
git commit -m "feat: add AppSnackbar confirmation/error helper"
```

---

### Task 6: `ContactModel` + `ContactNotifier` provider

**Files:**
- Create: `lib/models/contact_model.dart`
- Create: `lib/providers/contact_provider.dart`
- Test: `test/providers/contact_provider_test.dart`

**Interfaces:**
- Produces: `ContactModel({String? id, required String name, required String relationship})` with `copyWith`; `contactProvider` (`StateNotifierProvider<ContactNotifier, List<ContactModel>>`); `ContactNotifier.addContact(ContactModel)`, `ContactNotifier.deleteContact(String id)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/models/contact_model.dart';
import 'package:to_aqui/providers/contact_provider.dart';

void main() {
  test('starts with the mock contacts (Mãe and Amor)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final contacts = container.read(contactProvider);

    expect(contacts.length, 2);
    expect(contacts.map((c) => c.name), containsAll(['Mãe', 'Amor']));
  });

  test('addContact appends a new contact', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(contactProvider.notifier).addContact(
          ContactModel(name: 'Vovó', relationship: 'Avó'),
        );

    final contacts = container.read(contactProvider);
    expect(contacts.length, 3);
    expect(contacts.last.name, 'Vovó');
    expect(contacts.last.relationship, 'Avó');
  });

  test('deleteContact removes only the contact with the matching id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final firstId = container.read(contactProvider).first.id;
    container.read(contactProvider.notifier).deleteContact(firstId);

    final contacts = container.read(contactProvider);
    expect(contacts.length, 1);
    expect(contacts.any((c) => c.id == firstId), isFalse);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/providers/contact_provider_test.dart`
Expected: FAIL — `lib/models/contact_model.dart` / `lib/providers/contact_provider.dart` don't exist yet.

- [ ] **Step 3: Implement `lib/models/contact_model.dart`**

```dart
import 'package:uuid/uuid.dart';

class ContactModel {
  final String id;
  final String name;
  final String relationship;

  ContactModel({
    String? id,
    required this.name,
    required this.relationship,
  }) : id = id ?? const Uuid().v4();

  ContactModel copyWith({String? name, String? relationship}) {
    return ContactModel(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
    );
  }
}
```

- [ ] **Step 4: Implement `lib/providers/contact_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';

class ContactNotifier extends StateNotifier<List<ContactModel>> {
  ContactNotifier() : super([]) {
    _loadMockData();
  }

  void _loadMockData() {
    state = [
      ContactModel(name: 'Mãe', relationship: 'Mãe'),
      ContactModel(name: 'Amor', relationship: 'Parceiro(a)'),
    ];
  }

  void addContact(ContactModel contact) {
    state = [...state, contact];
  }

  void deleteContact(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final contactProvider = StateNotifierProvider<ContactNotifier, List<ContactModel>>((ref) {
  return ContactNotifier();
});
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/providers/contact_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/models/contact_model.dart lib/providers/contact_provider.dart test/providers/contact_provider_test.dart
git commit -m "feat: add ContactModel and ContactNotifier provider"
```

---

### Task 7: `AddContactSheet` (modal form)

**Files:**
- Create: `lib/widgets/add_contact_sheet.dart`
- Test: `test/widgets/add_contact_sheet_test.dart`

**Interfaces:**
- Consumes: `contactProvider`, `ContactModel` (Task 6).
- Produces: `showAddContactSheet(BuildContext context)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/widgets/add_contact_sheet.dart';

void main() {
  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAddContactSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('save is disabled until a name is entered, then adds the contact', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(find.byKey(const Key('contact-save-button')));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Vovó');
    await tester.enterText(find.byKey(const Key('contact-relationship-field')), 'Avó');
    await tester.pump();

    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    final contacts = ProviderScope.containerOf(context).read(contactProvider);
    expect(contacts.any((c) => c.name == 'Vovó' && c.relationship == 'Avó'), isTrue);
  });

  testWidgets('defaults relationship to "Familiar" when left blank', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('contact-name-field')), 'Tio Zé');
    await tester.pump();
    await tester.tap(find.byKey(const Key('contact-save-button')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ElevatedButton));
    final contacts = ProviderScope.containerOf(context).read(contactProvider);
    expect(contacts.any((c) => c.name == 'Tio Zé' && c.relationship == 'Familiar'), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/widgets/add_contact_sheet_test.dart`
Expected: FAIL — `lib/widgets/add_contact_sheet.dart` doesn't exist yet.

- [ ] **Step 3: Implement the sheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';

void showAddContactSheet(BuildContext context) {
  showModalBottomSheet(
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

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _save() {
    final relationship = _relationshipController.text.isNotEmpty
        ? _relationshipController.text
        : 'Familiar';

    ref.read(contactProvider.notifier).addContact(
          ContactModel(name: _nameController.text, relationship: relationship),
        );
    Navigator.of(context).pop();
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
            onPressed: _canSave ? _save : null,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widgets/add_contact_sheet_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/add_contact_sheet.dart test/widgets/add_contact_sheet_test.dart
git commit -m "feat: add AddContactSheet form for inviting family members"
```

---

### Task 8: Rewire Contacts screen

**Files:**
- Modify: `lib/screens/contacts_screen.dart` (full replace)
- Test: `test/screens/contacts_screen_test.dart`

**Interfaces:**
- Consumes: `contactProvider` (Task 6), `EmptyState` (Task 3), `showAddContactSheet` (Task 7).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/contact_provider.dart';
import 'package:to_aqui/screens/contacts_screen.dart';

void main() {
  Widget buildApp() {
    return const ProviderScope(
      child: MaterialApp(home: ContactsScreen()),
    );
  }

  testWidgets('lists mock contacts and deletes one on tap', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsOneWidget);
    expect(find.text('Amor'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Mãe'), findsNothing);
    expect(find.text('Amor'), findsOneWidget);
  });

  testWidgets('shows the empty state after deleting every contact', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ContactsScreen));
    final container = ProviderScope.containerOf(context);
    final notifier = container.read(contactProvider.notifier);
    for (final contact in List.of(container.read(contactProvider))) {
      notifier.deleteContact(contact.id);
    }
    await tester.pumpAndSettle();

    expect(find.text('Sua família ainda não está por aqui'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/contacts_screen_test.dart`
Expected: FAIL — the current `ContactsScreen` is fully static, so the delete button does nothing and there's no empty state text.

- [ ] **Step 3: Replace `lib/screens/contacts_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/contact_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/add_contact_sheet.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(contactProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Família e Contatos')),
      body: contacts.isEmpty
          ? EmptyState(
              emoji: '👨‍👩‍👧‍👦',
              title: 'Sua família ainda não está por aqui',
              subtitle: 'Convide quem você ama pra saber que você chegou bem',
              ctaLabel: 'Convidar familiar',
              onCtaPressed: () => showAddContactSheet(context),
            )
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.relationship),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(contactProvider.notifier).deleteContact(contact.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddContactSheet(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar'),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/contacts_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/contacts_screen.dart test/screens/contacts_screen_test.dart
git commit -m "feat: make Contacts screen interactive with local state"
```

---

### Task 9: Locations loading state

**Files:**
- Modify: `lib/providers/location_provider.dart` (full replace)
- Test: `test/providers/location_provider_test.dart`

**Interfaces:**
- Produces: `locationsLoadingProvider` (`StateProvider<bool>`, starts `true`, flips to `false` once mock data finishes loading).
- Modifies: `LocationNotifier` now takes a `Ref` (passed automatically by its provider) so it can flip `locationsLoadingProvider` when done.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/providers/location_provider.dart';

void main() {
  test('starts loading and flips to loaded with mock locations after the delay', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(locationsLoadingProvider), isTrue);
    expect(container.read(locationProvider), isEmpty);

    await Future.delayed(const Duration(milliseconds: 500));

    expect(container.read(locationsLoadingProvider), isFalse);
    expect(
      container.read(locationProvider).map((l) => l.name),
      containsAll(['Trabalho', 'Casa']),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/providers/location_provider_test.dart`
Expected: FAIL — `locationsLoadingProvider` doesn't exist yet; `locationProvider` currently populates synchronously instead of starting empty.

- [ ] **Step 3: Replace `lib/providers/location_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_model.dart';

final locationsLoadingProvider = StateProvider<bool>((ref) => true);

class LocationNotifier extends StateNotifier<List<LocationModel>> {
  LocationNotifier(this._ref) : super([]) {
    _loadMockData();
  }

  final Ref _ref;

  Future<void> _loadMockData() async {
    await Future.delayed(const Duration(milliseconds: 400));
    state = [
      LocationModel(
        name: 'Trabalho',
        latitude: -23.550520,
        longitude: -46.633308,
        radius: 100,
        message: 'Cheguei no trabalho em segurança! 💼',
      ),
      LocationModel(
        name: 'Casa',
        latitude: -23.561684,
        longitude: -46.625378,
        radius: 50,
        message: 'Já estou em casa. 🏠',
        isActive: false,
      ),
    ];
    _ref.read(locationsLoadingProvider.notifier).state = false;
  }

  void addLocation(LocationModel location) {
    state = [...state, location];
  }

  void toggleLocation(String id) {
    state = state.map((loc) {
      if (loc.id == id) {
        return loc.copyWith(isActive: !loc.isActive);
      }
      return loc;
    }).toList();
  }

  void deleteLocation(String id) {
    state = state.where((loc) => loc.id != id).toList();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, List<LocationModel>>((ref) {
  return LocationNotifier(ref);
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/providers/location_provider_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/location_provider.dart test/providers/location_provider_test.dart
git commit -m "feat: add locationsLoadingProvider for the loading UI state"
```

---

### Task 10: Rewire Locations screen (skeleton, empty state, snackbar)

**Files:**
- Modify: `lib/screens/locations_screen.dart` (full replace)
- Test: `test/screens/locations_screen_test.dart`

**Interfaces:**
- Consumes: `locationProvider`, `locationsLoadingProvider` (Task 9), `SkeletonListTile` (Task 4), `EmptyState` (Task 3), `AppSnackbar` (Task 5).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/screens/locations_screen.dart';
import 'package:to_aqui/widgets/skeleton.dart';

void main() {
  testWidgets('shows skeletons while loading, then the location list', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LocationsScreen())));

    expect(find.byType(SkeletonListTile), findsWidgets);
    expect(find.text('Trabalho'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(SkeletonListTile), findsNothing);
    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets('toggling a location shows a confirmation snackbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LocationsScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/locations_screen_test.dart`
Expected: FAIL — no `SkeletonListTile` is rendered yet and toggling doesn't show a `SnackBar`.

- [ ] **Step 3: Replace `lib/screens/locations_screen.dart`**

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
    final isLoading = ref.watch(locationsLoadingProvider);
    final locations = ref.watch(locationProvider);

    Widget body;
    if (isLoading) {
      body = ListView(
        children: const [
          SkeletonListTile(),
          SkeletonListTile(),
          SkeletonListTile(),
        ],
      );
    } else if (locations.isEmpty) {
      body = const EmptyState(
        emoji: '📍',
        title: 'Nenhum local cadastrado',
        subtitle: 'Adicione um local para começar a avisar sua família',
      );
    } else {
      body = ListView.builder(
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
                ref.read(locationProvider.notifier).toggleLocation(loc.id);
                AppSnackbar.showConfirmation(
                  context,
                  '${loc.name} ${val ? 'ativado' : 'desativado'}',
                );
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Locais')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/add'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Novo Local'),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/locations_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/locations_screen.dart test/screens/locations_screen_test.dart
git commit -m "feat: add loading/empty states and toggle feedback to Locations screen"
```

---

### Task 11: Recolor Home screen + skeleton/empty states

**Files:**
- Modify: `lib/screens/home_screen.dart` (full replace)
- Test: `test/screens/home_screen_test.dart`

**Interfaces:**
- Produces: `ArrivalEntry({required String title, required String subtitle})`; `HomeScreen({List<ArrivalEntry>? arrivals})` — passing `arrivals` overrides the simulated load, which is what makes this screen testable without waiting on real timers/network.
- Consumes: `EmptyState` (Task 3), `SkeletonListTile` (Task 4).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/screens/home_screen.dart';
import 'package:to_aqui/widgets/skeleton.dart';

void main() {
  testWidgets('shows skeletons, then the injected arrivals', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: HomeScreen(
          arrivals: const [ArrivalEntry(title: 'Trabalho', subtitle: 'Chegou hoje às 08:45')],
        ),
      ),
    ));

    expect(find.byType(SkeletonListTile), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.byType(SkeletonListTile), findsNothing);
    expect(find.text('Trabalho'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no arrivals', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: HomeScreen(arrivals: [])),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Nenhuma chegada registrada ainda'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: FAIL — `HomeScreen` doesn't accept an `arrivals` parameter yet and has no loading/empty states.

- [ ] **Step 3: Replace `lib/screens/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

class ArrivalEntry {
  final String title;
  final String subtitle;

  const ArrivalEntry({required this.title, required this.subtitle});
}

const _defaultArrivals = [
  ArrivalEntry(title: 'Trabalho', subtitle: 'Chegou hoje às 08:45'),
  ArrivalEntry(title: 'Casa', subtitle: 'Chegou ontem às 18:30'),
];

class HomeScreen extends ConsumerStatefulWidget {
  final List<ArrivalEntry>? arrivals;

  const HomeScreen({super.key, this.arrivals});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  List<ArrivalEntry> _arrivals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = widget.arrivals ?? await _fetchArrivals();
    if (!mounted) return;
    setState(() {
      _arrivals = result;
      _isLoading = false;
    });
  }

  Future<List<ArrivalEntry>> _fetchArrivals() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _defaultArrivals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToAqui', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text('🏡', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 16),
                      Text(
                        'Rastreamento Ativo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Avisaremos sua família automaticamente quando você chegar aos seus destinos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Últimos Envios',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView(
        children: const [SkeletonListTile(), SkeletonListTile()],
      );
    }
    if (_arrivals.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Nenhuma chegada registrada ainda',
        subtitle: 'Quando você chegar a um local salvo, ele aparece aqui',
      );
    }
    return ListView(
      children: _arrivals
          .map((entry) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(Icons.check, color: Theme.of(context).colorScheme.secondary),
                ),
                title: Text(entry.title),
                subtitle: Text(entry.subtitle),
              ))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/home_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "feat: recolor Home screen and add loading/empty states"
```

---

### Task 12: Add Location screen — full-map + draggable bottom sheet layout

This task has no automated test: `GoogleMap` requires a platform view that Flutter's widget test environment doesn't provide. Per the spec, this interaction is verified manually.

**Files:**
- Modify: `lib/screens/add_location_screen.dart` (full replace)

**Interfaces:**
- Consumes: `locationProvider` (Task 9, unchanged interface: `addLocation(LocationModel)`).
- No new public interfaces — the AppBar's checkmark save action is removed since it duplicated the bottom sheet's "Salvar Local" button, which remains the single save entry point.

- [ ] **Step 1: Replace `lib/screens/add_location_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../providers/location_provider.dart';
import '../models/location_model.dart';

class AddLocationScreen extends ConsumerStatefulWidget {
  const AddLocationScreen({super.key});

  @override
  ConsumerState<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends ConsumerState<AddLocationScreen> {
  LatLng? _selectedLocation;
  double _radius = 100;
  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(-23.550520, -46.633308),
    zoom: 14.0,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _saveLocation() {
    if (_selectedLocation == null || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um local no mapa e dê um nome.')),
      );
      return;
    }

    final newLocation = LocationModel(
      name: _nameController.text,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radius: _radius,
      message: _messageController.text.isNotEmpty
          ? _messageController.text
          : 'Cheguei em ${_nameController.text} em segurança!',
    );

    ref.read(locationProvider.notifier).addLocation(newLocation);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            onTap: (latLng) => setState(() => _selectedLocation = latLng),
            markers: _selectedLocation == null
                ? {}
                : {Marker(markerId: const MarkerId('selected'), position: _selectedLocation!)},
            circles: _selectedLocation == null
                ? {}
                : {
                    Circle(
                      circleId: const CircleId('radius'),
                      center: _selectedLocation!,
                      radius: _radius,
                      fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      strokeColor: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2,
                    )
                  },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedLocation == null)
                  const Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text('Toque no mapa para selecionar o local'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Local (ex: Trabalho)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Raio de detecção: ${_radius.toInt()} metros'),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      label: '${_radius.toInt()}m',
                      onChanged: (val) => setState(() => _radius = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem personalizada (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saveLocation,
                      child: const Text('Salvar Local'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Manual verification**

Run: `flutter run -d chrome` (or a connected device/emulator)

Walk through and confirm each of the following:
1. Navigate to Locais → "Novo Local" — the map fills the whole screen, with a floating back button top-left and the "Toque no mapa..." hint next to it.
2. Tap the map — a marker and radius circle appear, and the hint disappears.
3. Drag the bottom sheet up — it reveals the full form (name, radius slider, message, "Salvar Local").
4. Drag it back down — it collapses without losing any text you typed.
5. Tap "Salvar Local" without tapping the map first — the validation SnackBar ("Selecione um local no mapa e dê um nome.") appears.
6. Tap the map, fill in a name, tap "Salvar Local" — it navigates back to "Meus Locais" and the new location shows up in the list (after the brief skeleton load from Task 10).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/add_location_screen.dart
git commit -m "feat: rework Add Location layout as full map with draggable sheet"
```

---

### Task 13: App icon placeholder via flutter_launcher_icons

**Files:**
- Create: `tool/generate_icon_placeholder.py`
- Create (generated by the script, not hand-written): `assets/icon/icon.png`
- Modify: `pubspec.yaml` (new dev dependency + `flutter_launcher_icons` config block)

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add --dev flutter_launcher_icons`
Expected: `pubspec.yaml`'s `dev_dependencies:` gains a `flutter_launcher_icons: ^<resolved version>` line.

- [ ] **Step 2: Add the launcher icon config to `pubspec.yaml`**

Add this as a new top-level key (sibling to `dependencies:`/`dev_dependencies:`/`flutter:`), anywhere after `dev_dependencies:`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
```

- [ ] **Step 3: Write the placeholder icon generator**

```python
# tool/generate_icon_placeholder.py
# One-off script: generates a placeholder app icon in the approved palette
# (coral background, white house glyph) until final artwork is supplied.
from PIL import Image, ImageDraw

SIZE = 1024
BG = (244, 162, 97)  # #F4A261 coral
FG = (255, 255, 255)

img = Image.new("RGB", (SIZE, SIZE), BG)
draw = ImageDraw.Draw(img)

body_w, body_h = 420, 320
body_left = (SIZE - body_w) // 2
body_top = SIZE // 2 - 20
draw.rectangle(
    [body_left, body_top, body_left + body_w, body_top + body_h],
    fill=FG,
)

roof_height = 260
roof_overhang = 40
roof_points = [
    (body_left - roof_overhang, body_top),
    (body_left + body_w + roof_overhang, body_top),
    (body_left + body_w / 2, body_top - roof_height),
]
draw.polygon(roof_points, fill=FG)

door_w, door_h = 100, 160
door_left = body_left + (body_w - door_w) // 2
door_top = body_top + body_h - door_h
draw.rectangle(
    [door_left, door_top, door_left + door_w, door_top + door_h],
    fill=BG,
)

img.save("assets/icon/icon.png")
print("Saved assets/icon/icon.png", img.size)
```

- [ ] **Step 4: Generate the placeholder image**

Run: `python -m pip install --upgrade pillow`
Run: `python tool/generate_icon_placeholder.py`
Expected output: `Saved assets/icon/icon.png (1024, 1024)`

- [ ] **Step 5: Verify the image**

Run: `python -c "from PIL import Image; im = Image.open('assets/icon/icon.png'); print(im.size, im.mode)"`
Expected: `(1024, 1024) RGB`

- [ ] **Step 6: Generate platform launcher icons**

Run: `flutter pub get`
Run: `dart run flutter_launcher_icons`
Expected: Output ending in something like "✓ Successfully generated launcher icons".

- [ ] **Step 7: Verify the generated assets**

Run: `ls -la android/app/src/main/res/mipmap-xxxhdpi/`
Expected: `ic_launcher.png` present with a modification timestamp from this step.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock tool/generate_icon_placeholder.py assets/icon/icon.png android/app/src/main/res
git commit -m "feat: generate placeholder cozy-house app icon"
```

---

### Task 14: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full automated test suite**

Run: `flutter test`
Expected: All tests pass (Tasks 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 each contributed tests — none should fail or be skipped).

- [ ] **Step 2: Static analysis**

Run: `flutter analyze`
Expected: No errors. Warnings are acceptable but should be reviewed — fix any that are trivial (e.g., unused imports left over from a refactor).

- [ ] **Step 3: Manual walkthrough**

Run: `flutter run -d chrome`

Confirm, across Início / Locais / Família / Adicionar Local:
- The Teal & Coral palette is visible consistently (status card, buttons, bottom nav, snackbars).
- Início and Locais briefly show the skeleton loaders before their content appears.
- Deleting all contacts in Família shows the illustrated empty state; "Adicionar"/"Convidar familiar" opens the form and a new contact appears in the list.
- Toggling a location in Locais shows the confirmation snackbar.
- Adicionar Local shows the full-screen map with the draggable sheet (re-run the Task 12 manual checklist if anything looks off).

- [ ] **Step 4: Dark mode spot-check**

Temporarily force dark mode by changing `themeMode: ThemeMode.system` to `themeMode: ThemeMode.dark` in `lib/main.dart`, hot-reload, confirm the palette still reads correctly (teal/coral against dark surfaces, no illegible text), then revert the change (`themeMode: ThemeMode.system`).

- [ ] **Step 5: Final commit (only if Step 2 produced fixes)**

```bash
git add -A
git commit -m "chore: address flutter analyze findings from visual refresh pass"
```
