import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/receipt_image_cache.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../core/utils/merchant_normalizer.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../data/receipt_repository.dart';
import '../screens/receipt_list_screen.dart';

class ReceiptUpload extends ConsumerStatefulWidget {
  final VoidCallback? onUploaded;

  const ReceiptUpload({super.key, this.onUploaded});

  @override
  ConsumerState<ReceiptUpload> createState() => _ReceiptUploadState();
}

class _ReceiptUploadState extends ConsumerState<ReceiptUpload> {
  bool _isUploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    // Check subscription limit (skip if premium via RC or Supabase).
    // canUpload already accounts for tier — Free=5, Family Lite=15,
    // Premium=∞ — so we just surface a tier-specific message.
    final rcStatus = ref.read(revenueCatStatusProvider).value;
    final isPro = rcStatus?.isPremium ?? false;
    final sub = ref.read(subscriptionProvider).value;
    if (!isPro && sub != null && !sub.canUpload) {
      if (mounted) {
        AppSnack.show(
          context,
          sub.isFamilyLite
              ? 'Limit Family Lite (${sub.maxReceiptsPerMonth}/mies) wykorzystany. Pełne Premium = brak limitu.'
              : 'Osiągnięto limit paragonów w tym miesiącu. Ulepsz plan!',
          kind: SnackKind.warning,
        );
      }
      return;
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

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final userId = SupabaseService.auth.currentUser!.id;

      // Check if online
      final isOnline = ref.read(isOnlineProvider);
      if (!isOnline) {
        await OfflineSyncService.queueReceipt({
          'fileName': image.name,
          'bytes': bytes.toList(),
          'userId': userId,
        });
        if (mounted) {
          AppSnack.show(
            context,
            'Paragon zapisany offline. Zostanie przesłany po połączeniu.',
            kind: SnackKind.info,
          );
        }
        return;
      }

      // Upload to storage
      final publicUrl = await StorageService.uploadReceipt(
        userId: userId,
        fileBytes: bytes,
      );

      // Cache locally so we don't re-download
      await ReceiptImageCache.saveLocal(publicUrl, bytes);

      // Analyze with AI
      Map<String, dynamic> receiptData = {
        'user_id': userId,
        'image_url': publicUrl,
      };

      try {
        final aiResponse = await SupabaseService.invokeFunction(
          'analyze-receipt',
          body: {'imageUrl': publicUrl, 'userId': userId},
        );

        debugPrint('=== AI RESPONSE ===');
        debugPrint('Status: ${aiResponse.status}');
        debugPrint('Data type: ${aiResponse.data?.runtimeType}');
        debugPrint('Data: ${aiResponse.data}');

        if (aiResponse.data != null) {
          final raw = aiResponse.data;
          Map<String, dynamic>? aiData;

          // Edge Function returns {success: true, data: {...actual fields...}}
          if (raw is Map<String, dynamic>) {
            if (raw.containsKey('data') && raw['data'] is Map) {
              aiData = Map<String, dynamic>.from(raw['data'] as Map);
            } else {
              aiData = raw;
            }
          } else if (raw is Map) {
            aiData = Map<String, dynamic>.from(raw);
          }

          debugPrint('=== Parsed AI Data ===');
          debugPrint('aiData: $aiData');

          if (aiData != null) {
            // Try both camelCase and snake_case keys from Edge Function
            final amount = aiData['amount'];
            receiptData.addAll({
              'merchant_name': MerchantNameNormalizer.normalize(
                  (aiData['merchantName'] ?? aiData['merchant_name'] ?? '') as String),
              'merchant_address': aiData['merchantAddress'] ?? aiData['merchant_address'],
              'amount': amount != null
                  ? (amount is String
                      ? double.tryParse(amount)
                      : (amount is num ? amount.toDouble() : null))
                  : null,
              'purchase_date': aiData['purchaseDate'] ?? aiData['purchase_date'],
              'category': aiData['category'],
              'categories': aiData['categories'],
              'items': aiData['items'],
              'receipt_number': aiData['receiptNumber'] ?? aiData['receipt_number'],
              'ai_processed': true,
              'ai_confidence': aiData['confidence'] ?? aiData['ai_confidence'],
            });
          }
        }
      } catch (aiError) {
        debugPrint('AI analyze failed (non-blocking): $aiError');
        // Non-blocking — still save the receipt without AI data
      }

      // Insert receipt
      await ref.read(receiptRepositoryProvider).createReceipt(receiptData);

      // Process gamification (non-blocking)
      try {
        await SupabaseService.invokeFunction(
          'process-gamification',
          body: {'userId': userId},
        );
      } catch (e) {
        debugPrint('Gamification processing failed: $e');
      }

      if (mounted) {
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
        widget.onUploaded?.call();
        ref.read(receiptListRefreshProvider.notifier).state++;

        // Request notification permission after first scan
        NotificationService.requestPermission();
        // Schedule daily streak reminder at 20:00
        NotificationService.scheduleDailyStreakReminder(
            hour: 9, minute: 0);
      }
    } catch (e) {
      if (mounted) {
        AppSnack.show(
          context,
          'Błąd przesyłania: $e',
          kind: SnackKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider).value;
    final rcStatus = ref.watch(revenueCatStatusProvider).value;
    final isPro = rcStatus?.isPremium ?? false;
    final usedCount = sub?.currentMonthReceipts ?? 0;
    final maxCount = sub?.maxReceiptsPerMonth ?? 5;
    final isUnlimited = isPro || (sub?.isUnlimited ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Dodaj paragon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Builder(builder: (context) {
              final usageRatio = isUnlimited
                  ? 0.0
                  : (maxCount > 0 ? usedCount / maxCount : 0.0);
              final counterColor = isUnlimited
                  ? Theme.of(context).colorScheme.primary
                  : usageRatio >= 1.2
                      ? Colors.red
                      : usageRatio >= 0.8
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: counterColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isUnlimited
                      ? '$usedCount w tym miesiącu (∞)'
                      : '$usedCount / $maxCount w tym miesiącu',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: counterColor,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        if (_isUploading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Przesyłanie i analiza paragonu...'),
                ],
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _UploadButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Zrób zdjęcie',
                  onTap: () => _pickAndUpload(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _UploadButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Prześlij zdjęcie',
                  onTap: () => _pickAndUpload(ImageSource.gallery),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UploadButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
