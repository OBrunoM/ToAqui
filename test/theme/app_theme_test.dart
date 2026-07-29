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
