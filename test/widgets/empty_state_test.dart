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
