import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:to_aqui/widgets/skeleton.dart';

void main() {
  testWidgets('SkeletonBox renders at the given size', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: SkeletonBox(width: 100, height: 20),
      ),
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
