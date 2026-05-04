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

  // System UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (FCM + Analytics + Crashlytics)
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
    await MessagingService.initialize();
  } catch (e) {
    debugPrint('Firebase init failed (non-blocking): $e');
  }

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize offline storage
  await OfflineSyncService.initialize();

  // Initialize notifications
  await NotificationService.initialize();

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
