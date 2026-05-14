import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/haptics.dart';
import '../../../family/data/family_repository.dart';
import '../../data/receipt_upload_helper.dart';

/// V3 — Floating Action Button "Dodaj paragon" w panelu Paragony.
/// Tap → bottom sheet z opcjami: aparat / galeria → wspólny pipeline
/// `pickAndUploadReceipt` (ten sam co w `ReceiptUpload` na Home).
class AddReceiptFab extends ConsumerStatefulWidget {
  const AddReceiptFab({super.key});

  @override
  ConsumerState<AddReceiptFab> createState() => _AddReceiptFabState();
}

class _AddReceiptFabState extends ConsumerState<AddReceiptFab> {
  bool _uploading = false;

  Future<void> _showPicker() async {
    Haptics.medium();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetCtx) => const _PickerSheet(),
    );
    if (source == null || !mounted) return;
    // Family id resolved on-the-fly — FAB nie ma osobnego "shareWithFamily"
    // toggle'a (zostawiamy to do edycji paragonu po add).
    String? familyId;
    try {
      final m = await FamilyRepository.instance.currentMembership();
      familyId = m?['family_id'] as String?;
    } catch (_) {}
    if (!mounted) return;
    await pickAndUploadReceipt(
      ref: ref,
      context: context,
      source: source,
      shareWithFamily: false,
      familyId: familyId,
      onUploadingChanged: (v) {
        if (mounted) setState(() => _uploading = v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton.extended(
          onPressed: _uploading ? null : _showPicker,
          heroTag: 'add-receipt-fab',
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.add_a_photo_rounded),
          label: Text(_uploading ? 'Przetwarzanie...' : 'Dodaj paragon'),
          elevation: 8,
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: c.surface1,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.textTertiary.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              'Dodaj nowy paragon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'AI automatycznie rozpozna sklep, datę i kwotę',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PickerOption(
              icon: Icons.camera_alt_rounded,
              label: 'Zrób zdjęcie',
              subtitle: 'Sfotografuj paragon aparatem',
              accent: AppColors.primary500,
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PickerOption(
              icon: Icons.photo_library_rounded,
              label: 'Prześlij z galerii',
              subtitle: 'Wybierz istniejące zdjęcie',
              accent: AppColors.accentAqua,
              onTap: () =>
                  Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: accent.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: c.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
