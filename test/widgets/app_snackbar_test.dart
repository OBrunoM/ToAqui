import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/theme/app_theme.dart';
import 'package:to_aqui/widgets/app_snackbar.dart';

void main() {
  testWidgets('showConfirmation displays the message with the teal accent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackbar.showConfirmation(context, 'Casa desativado'),
            child: const Text('trigger'),
          ),
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
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackbar.showError(context, 'Algo deu errado'),
            child: const Text('trigger'),
          ),
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
