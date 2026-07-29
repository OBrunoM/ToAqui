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
