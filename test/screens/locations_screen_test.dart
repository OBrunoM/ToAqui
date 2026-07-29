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
