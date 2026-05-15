import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'core/services/analytics_service.dart';
import 'core/services/messaging_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/offline_sync_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/purchase_service.dart'; // RevenueCatService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Polish locale
  await initializeDateFormatting('pl_PL', null);

  // System UI overlay style — transparent status bar; ikona/tekst
  // statusbara dobierane automatycznie przez M3 AppBar w zależności
  // od jasności jego background'u (light bg → ciemne ikony).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // Preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (Analytics + Crashlytics first; messaging is
  // wired AFTER Supabase so the token uploader sees a restored
  // session on cold start).
  try {
    await Firebase.initializeApp();
    await AnalyticsService.initialize();
    // Pipe Flutter framework errors and zone errors to Crashlytics
    // so production crashes get a stack trace.
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase init failed (non-blocking): $e');
  }

  // Initialize Supabase BEFORE MessagingService so the FCM token
  // uploader sees a restored session immediately and writes to
  // device_push_tokens on cold start.
  await SupabaseService.initialize();

  // Now wire FCM — by this point auth.currentUser is populated when
  // the user has a persisted session, so the initial _uploadToken
  // actually lands.
  try {
    await MessagingService.initialize();
  } catch (e) {
    debugPrint('MessagingService init failed (non-blocking): $e');
  }

  // Initialize offline storage
  await OfflineSyncService.initialize();

  // Initialize notifications + retention schedules (F3-T1)
  await NotificationService.initialize();
  // Idempotent — replaces any existing schedule. Always-on monthly
  // ping; trial reminders are scheduled per purchase in the paywall.
  unawaited(NotificationService.scheduleMonthlySummary());

  // Initialize in-app purchases (RevenueCat) — non-blocking
  try {
    await RevenueCatService.initialize();
  } catch (e) {
    debugPrint('RevenueCat init failed (non-blocking): $e');
  }

  runApp(
    const ProviderScope(
      child: ParagonProApp(),
    ),
  );
}
