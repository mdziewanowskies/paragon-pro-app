import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/family_data_provider.dart';
import '../../data/family_repository.dart';

/// 'Strefa zagrożenia' (3.10): leave-the-family for members,
/// delete-the-family for admins. Both flows confirm and refresh the
/// caller's subscription tier afterwards.
class FamilyDangerZone extends ConsumerWidget {
  final String familyId;
  final String memberRowId;
  final bool isAdmin;
  final VoidCallback onLeft;

  const FamilyDangerZone({
    super.key,
    required this.familyId,
    required this.memberRowId,
    required this.isAdmin,
    required this.onLeft,
  });

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    Haptics.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opuścić rodzinę?'),
        content: const Text(
          'Stracisz dostęp do wspólnych paragonów, statystyk rodziny '
          'i pakietu Family Lite. Zawsze możesz dołączyć ponownie '
          'po zaproszeniu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Opuść'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FamilyRepository.instance.removeMember(memberRowId);
      // Realtime on family_members fires, but we also nudge here for
      // immediate UX feedback.
      try {
        await ref.read(subscriptionProvider.notifier).refresh();
      } catch (_) {}
      ref.invalidate(familyMembersProvider(familyId));
      onLeft();
      Haptics.success();
      if (context.mounted) {
        AppSnack.show(
          context,
          'Opuściłeś rodzinę.',
          kind: SnackKind.info,
        );
      }
    } catch (_) {
      Haptics.error();
      if (context.mounted) {
        AppSnack.show(
          context,
          'Nie udało się opuścić rodziny',
          kind: SnackKind.error,
        );
      }
    }
  }

  Future<void> _deleteFamily(BuildContext context, WidgetRef ref) async {
    Haptics.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć rodzinę?'),
        content: const Text(
          'Wszyscy członkowie zostaną automatycznie usunięci. '
          'Stracą dostęp do pakietu Family Lite. Tej operacji '
          'nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Usuń rodzinę'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FamilyRepository.instance.deleteFamily(familyId);
      try {
        await ref.read(subscriptionProvider.notifier).refresh();
      } catch (_) {}
      onLeft();
      Haptics.success();
      if (context.mounted) {
        AppSnack.show(
          context,
          'Rodzina usunięta.',
          kind: SnackKind.info,
        );
      }
    } catch (_) {
      Haptics.error();
      if (context.mounted) {
        AppSnack.show(
          context,
          'Nie udało się usunąć rodziny',
          kind: SnackKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Strefa zagrożenia',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _deleteFamily(context, ref),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Usuń rodzinę'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _leave(context, ref),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Opuść rodzinę'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
