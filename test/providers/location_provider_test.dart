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
