import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../family/data/family_repository.dart';
import '../../data/receipt_upload_helper.dart';

class ReceiptUpload extends ConsumerStatefulWidget {
  final VoidCallback? onUploaded;

  const ReceiptUpload({super.key, this.onUploaded});

  @override
  ConsumerState<ReceiptUpload> createState() => _ReceiptUploadState();
}

class _ReceiptUploadState extends ConsumerState<ReceiptUpload> {
  bool _isUploading = false;
  bool _shareWithFamily = false;
  String? _familyId;
  bool _familyChecked = false;

  @override
  void initState() {
    super.initState();
    _resolveFamilyMembership();
  }

  /// Look up which family the user belongs to so the 'Udostępnij
  /// rodzinie' checkbox + the family_id we need to write are ready.
  /// Skipped for users who can't share anyway (Free without family).
  Future<void> _resolveFamilyMembership() async {
    try {
      final repo = FamilyRepository.instance;
      final m = await repo.currentMembership();
      if (!mounted) return;
      setState(() {
        _familyId = m?['family_id'] as String?;
        _familyChecked = true;
      });
    } catch (_) {
      if (mounted) setState(() => _familyChecked = true);
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    await pickAndUploadReceipt(
      ref: ref,
      context: context,
      source: source,
      shareWithFamily: _shareWithFamily,
      familyId: _familyId,
      onUploaded: widget.onUploaded,
      onUploadingChanged: (v) {
        if (mounted) setState(() => _isUploading = v);
      },
    );
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
        else ...[
          if (_familyChecked && _familyId != null)
            _ShareWithFamilyToggle(
              value: _shareWithFamily,
              onChanged: (v) {
                Haptics.selection();
                setState(() => _shareWithFamily = v);
              },
            ),
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
      ],
    );
  }
}

class _ShareWithFamilyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ShareWithFamilyToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: value
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.family_restroom_rounded,
            size: 18,
            color: value
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Udostępnij rodzinie',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Paragon trafi do wspólnych statystyk i rankingu.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
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
      clipBehavior: Clip.antiAlias,
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
