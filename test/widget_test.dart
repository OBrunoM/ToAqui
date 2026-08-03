import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:to_aqui/main.dart';
import 'package:to_aqui/providers/auth_provider.dart';
import 'package:to_aqui/providers/firestore_provider.dart';

void main() {
  testWidgets('ToAquiApp renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUidProvider.overrideWithValue('owner-uid'),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const ToAquiApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ToAqui'), findsWidgets);
    expect(find.text('Você está protegido'), findsOneWidget);
  });

  testWidgets('StartupErrorApp shows a retry button instead of a blank screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const StartupErrorApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível conectar'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Tentar novamente'), findsOneWidget);
  });
}
