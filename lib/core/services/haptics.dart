import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized, semantic haptic feedback. Use these instead of calling
/// HapticFeedback.* directly so the vocabulary stays consistent.
///
/// Quiet on web/desktop (no-op).
class Haptics {
  Haptics._();

  static bool get _supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Tab change, picker, selecting an item from a list. Tiniest tick.
  static void selection() {
    if (!_supported) return;
    HapticFeedback.selectionClick();
  }

  /// Default button tap. Most ubiquitous; use it everywhere a primary
  /// action is committed.
  static void tap() {
    if (!_supported) return;
    HapticFeedback.lightImpact();
  }

  /// Stronger confirmation: opening a sheet, switching modes, swiping
  /// to dismiss something benign.
  static void medium() {
    if (!_supported) return;
    HapticFeedback.mediumImpact();
  }

  /// Reserved for important moments: purchase complete, receipt added,
  /// premium unlocked, bigwin in gamification.
  static void heavy() {
    if (!_supported) return;
    HapticFeedback.heavyImpact();
  }

  /// iOS-only success notification pattern. On Android falls back to a
  /// medium tick.
  static void success() {
    if (!_supported) return;
    if (Platform.isIOS) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Warning. Slightly heavier than success.
  static void warning() {
    if (!_supported) return;
    HapticFeedback.heavyImpact();
  }

  /// Destructive / error. Use sparingly — reserved for failures the
  /// user should physically notice (login error, payment failed,
  /// delete confirmation).
  static void error() {
    if (!_supported) return;
    HapticFeedback.heavyImpact();
  }
}
