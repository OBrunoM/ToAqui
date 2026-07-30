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
