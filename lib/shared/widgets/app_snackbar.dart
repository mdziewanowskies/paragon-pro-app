import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/services/haptics.dart';

enum SnackKind { info, success, warning, error }

/// Drop-in replacement for raw ScaffoldMessenger.showSnackBar calls.
/// Produces a floating, rounded, color-coded snackbar with matching
/// haptic feedback. Use this everywhere instead of bespoke SnackBar
/// constructors so the visual + tactile vocabulary stays consistent.
class AppSnack {
  AppSnack._();

  static void show(
    BuildContext context,
    String message, {
    SnackKind kind = SnackKind.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    switch (kind) {
      case SnackKind.success:
        Haptics.success();
        break;
      case SnackKind.warning:
        Haptics.warning();
        break;
      case SnackKind.error:
        Haptics.error();
        break;
      case SnackKind.info:
        Haptics.tap();
        break;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: _bg(kind),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(12),
          content: Row(
            children: [
              Icon(_icon(kind), color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          action: action,
        ),
      );
  }

  static Color _bg(SnackKind kind) {
    switch (kind) {
      case SnackKind.success:
        return Colors.green.shade700;
      case SnackKind.warning:
        return Colors.orange.shade700;
      case SnackKind.error:
        return AppColors.lightDestructive;
      case SnackKind.info:
        return Colors.blueGrey.shade800;
    }
  }

  static IconData _icon(SnackKind kind) {
    switch (kind) {
      case SnackKind.success:
        return Icons.check_circle_rounded;
      case SnackKind.warning:
        return Icons.warning_amber_rounded;
      case SnackKind.error:
        return Icons.error_rounded;
      case SnackKind.info:
        return Icons.info_rounded;
    }
  }
}
