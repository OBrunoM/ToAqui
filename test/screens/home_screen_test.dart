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
