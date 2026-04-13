import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
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
    // Check subscription limit
    final sub = ref.read(subscriptionProvider).value;
    if (sub != null && !sub.canUpload) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Osiągnięto limit paragonów w tym miesiącu. Ulepsz plan!'),
            backgroundColor: AppColors.lightDestructive,
          ),
        );
      }
      return;
    }

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Paragon zapisany offline. Zostanie przesłany po połączeniu.'),
            ),
          );
        }
        return;
      }

      // Upload to storage
      final publicUrl = await StorageService.uploadReceipt(
        userId: userId,
        fileBytes: bytes,
      );

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
          final aiData = raw is Map<String, dynamic>
              ? raw
              : (raw is Map ? Map<String, dynamic>.from(raw) : null);

          if (aiData != null) {
            // Try both camelCase and snake_case keys from Edge Function
            receiptData.addAll({
              'merchant_name': aiData['merchantName'] ?? aiData['merchant_name'],
              'merchant_address': aiData['merchantAddress'] ?? aiData['merchant_address'],
              'amount': aiData['amount'] != null
                  ? (aiData['amount'] is String
                      ? double.tryParse(aiData['amount'])
                      : (aiData['amount'] as num?)?.toDouble())
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (receiptData['ai_processed'] == true)
                  const Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                const Text('Paragon dodany pomyślnie!'),
              ],
            ),
            backgroundColor: AppColors.lightPrimary,
          ),
        );
        widget.onUploaded?.call();
        // Signal receipt list to refresh
        ref.read(receiptListRefreshProvider.notifier).state++;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd przesyłania: $e'),
            backgroundColor: AppColors.lightDestructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider).value;
    final usedCount = sub?.currentMonthReceipts ?? 0;
    final maxCount = sub?.maxReceiptsPerMonth ?? 10;

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$usedCount / $maxCount w tym miesiącu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
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
              const SizedBox(width: 10),
              Expanded(
                child: _UploadButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Z galerii',
                  onTap: () => _pickAndUpload(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _UploadButton(
                  icon: Icons.computer_rounded,
                  label: 'Z komputera',
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
