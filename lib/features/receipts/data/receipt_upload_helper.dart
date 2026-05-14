import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/services/receipt_image_cache.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/merchant_normalizer.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../onboarding/coachmark/coachmark_controller.dart';
import '../../onboarding/first_receipt/first_receipt_celebration.dart';
import '../presentation/screens/receipt_list_screen.dart' show receiptListRefreshProvider;
import 'receipt_repository.dart';

/// V3 — wspólna ścieżka picker → upload → AI → save → snackbar/fanfara
/// dla `ReceiptUpload` (sekcja w Home) i FAB-a w `ReceiptListScreen`.
/// Zwraca true jeśli paragon został zapisany (cancel, błąd → false).
Future<bool> pickAndUploadReceipt({
  required WidgetRef ref,
  required BuildContext context,
  required ImageSource source,
  bool shareWithFamily = false,
  String? familyId,
  VoidCallback? onUploaded,
  ValueChanged<bool>? onUploadingChanged,
}) async {
  // Subscription limit check
  final rcStatus = ref.read(revenueCatStatusProvider).value;
  final isPro = rcStatus?.isPremium ?? false;
  final sub = ref.read(subscriptionProvider).value;
  if (!isPro && sub != null && !sub.canUpload) {
    if (context.mounted) {
      AppSnack.show(
        context,
        sub.isFamilyLite
            ? 'Limit Family Lite (${sub.maxReceiptsPerMonth}/mies) wykorzystany. Pełne Premium = brak limitu.'
            : 'Osiągnięto limit paragonów w tym miesiącu. Ulepsz plan!',
        kind: SnackKind.warning,
      );
    }
    return false;
  }
  Haptics.medium();

  final picker = ImagePicker();
  final XFile? image;
  if (source == ImageSource.camera) {
    image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
  } else {
    image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
  }
  if (image == null) return false;

  onUploadingChanged?.call(true);
  try {
    final bytes = await image.readAsBytes();
    final userId = SupabaseService.auth.currentUser!.id;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      await OfflineSyncService.queueReceipt({
        'fileName': image.name,
        'bytes': bytes.toList(),
        'userId': userId,
      });
      if (context.mounted) {
        AppSnack.show(
          context,
          'Paragon zapisany offline. Zostanie przesłany po połączeniu.',
          kind: SnackKind.info,
        );
      }
      return false;
    }

    final publicUrl = await StorageService.uploadReceipt(
      userId: userId,
      fileBytes: bytes,
    );
    await ReceiptImageCache.saveLocal(publicUrl, bytes);

    Map<String, dynamic> receiptData = {
      'user_id': userId,
      'image_url': publicUrl,
      if (shareWithFamily && familyId != null) ...{
        'family_id': familyId,
        'shared_with_family': true,
      },
    };

    try {
      final aiResponse = await SupabaseService.invokeFunction(
        'analyze-receipt',
        body: {'imageUrl': publicUrl, 'userId': userId},
      );
      if (aiResponse.data != null) {
        final raw = aiResponse.data;
        Map<String, dynamic>? aiData;
        if (raw is Map<String, dynamic>) {
          if (raw.containsKey('data') && raw['data'] is Map) {
            aiData = Map<String, dynamic>.from(raw['data'] as Map);
          } else {
            aiData = raw;
          }
        } else if (raw is Map) {
          aiData = Map<String, dynamic>.from(raw);
        }
        if (aiData != null) {
          final amount = aiData['amount'];
          receiptData.addAll({
            'merchant_name': MerchantNameNormalizer.normalize(
              (aiData['merchantName'] ?? aiData['merchant_name'] ?? '')
                  as String,
            ),
            'merchant_address':
                aiData['merchantAddress'] ?? aiData['merchant_address'],
            'amount': amount != null
                ? (amount is String
                    ? double.tryParse(amount)
                    : (amount is num ? amount.toDouble() : null))
                : null,
            'purchase_date':
                aiData['purchaseDate'] ?? aiData['purchase_date'],
            'category': aiData['category'],
            'categories': aiData['categories'],
            'items': aiData['items'],
            'receipt_number':
                aiData['receiptNumber'] ?? aiData['receipt_number'],
            'ai_processed': true,
            'ai_confidence': aiData['confidence'] ?? aiData['ai_confidence'],
          });
        }
      }
    } catch (aiError) {
      debugPrint('AI analyze failed (non-blocking): $aiError');
    }

    await ref.read(receiptRepositoryProvider).createReceipt(receiptData);

    try {
      await SupabaseService.invokeFunction(
        'process-gamification',
        body: {'userId': userId},
      );
    } catch (e) {
      debugPrint('Gamification processing failed: $e');
    }

    if (context.mounted) {
      Haptics.heavy();
      AnalyticsService.receiptAdded(
        aiProcessed: receiptData['ai_processed'] == true,
      );
      AppSnack.show(
        context,
        receiptData['ai_processed'] == true
            ? 'Paragon dodany! AI rozpoznało dane.'
            : 'Paragon dodany pomyślnie!',
        kind: SnackKind.success,
      );
      onUploaded?.call();
      ref.read(receiptListRefreshProvider.notifier).state++;
      NotificationService.requestPermission();
      NotificationService.scheduleDailyStreakReminder(hour: 9, minute: 0);

      final inTutorial = ref.read(tutorialActiveProvider);
      if (!inTutorial && context.mounted) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (context.mounted) {
            FirstReceiptCelebrationDialog.maybeShow(context);
          }
        });
      }
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      AppSnack.show(
        context,
        'Błąd przesyłania: $e',
        kind: SnackKind.error,
      );
    }
    return false;
  } finally {
    onUploadingChanged?.call(false);
  }
}
