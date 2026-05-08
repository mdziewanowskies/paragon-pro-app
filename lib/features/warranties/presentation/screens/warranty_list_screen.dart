import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../widgets/warranty_card.dart';

class WarrantyModel {
  final String id;
  final String? receiptId;
  final String userId;
  final int warrantyMonths;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? notes;
  final bool notified;
  final String? merchantName;
  final double? amount;

  WarrantyModel({
    required this.id,
    this.receiptId,
    required this.userId,
    required this.warrantyMonths,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.notes,
    this.notified = false,
    this.merchantName,
    this.amount,
  });

  factory WarrantyModel.fromJson(Map<String, dynamic> json) {
    return WarrantyModel(
      id: json['id'] as String,
      receiptId: json['receipt_id'] as String?,
      userId: json['user_id'] as String,
      warrantyMonths: json['warranty_months'] as int? ?? 12,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      notified: json['notified'] as bool? ?? false,
      merchantName: json['receipts']?['merchant_name'] as String?,
      amount: (json['receipts']?['amount'] as num?)?.toDouble(),
    );
  }

  bool get isActive => endDate.isAfter(DateTime.now());
  bool get isExpiringSoon =>
      isActive && endDate.difference(DateTime.now()).inDays <= 30;
}

final warrantyListProvider =
    FutureProvider.autoDispose<List<WarrantyModel>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return [];

  final data = await SupabaseService.client
      .from('warranties')
      .select('*, receipts(merchant_name, amount)')
      .eq('user_id', userId)
      .order('end_date', ascending: true);

  return (data as List).map((e) => WarrantyModel.fromJson(e)).toList();
});

class WarrantyListScreen extends ConsumerWidget {
  const WarrantyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warranties = ref.watch(warrantyListProvider);

    return warranties.when(
      loading: () => const GenericListSkeleton(),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.shield_rounded,
            title: 'Brak gwarancji',
            subtitle: 'Dodaj gwarancję do paragonu, aby śledzić jej status.',
            hint:
                'Otwórz dowolny paragon na liście Paragony i wybierz '
                '"Dodaj gwarancję".',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
          Haptics.medium();
          ref.invalidate(warrantyListProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
          Haptics.success();
        },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final warranty = list[index];
              return Dismissible(
                key: ValueKey(warranty.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.white, size: 28),
                ),
                confirmDismiss: (_) async {
                  final result =
                      await showCupertinoModalPopup<bool>(
                    context: context,
                    builder: (ctx) => CupertinoActionSheet(
                      title: Text(
                          'Usuń gwarancję${warranty.merchantName != null ? ' — ${warranty.merchantName}' : ''}'),
                      message: const Text(
                          'Tej operacji nie można cofnąć.'),
                      actions: [
                        CupertinoActionSheetAction(
                          isDestructiveAction: true,
                          onPressed: () =>
                              Navigator.pop(ctx, true),
                          child: const Text('Usuń'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text('Anuluj'),
                      ),
                    ),
                  );
                  return result ?? false;
                },
                onDismissed: (_) async {
                  await SupabaseService.client
                      .from('warranties')
                      .delete()
                      .eq('id', warranty.id);
                  ref.invalidate(warrantyListProvider);
                },
                child: WarrantyCard(
                warranty: warranty,
                onDelete: () async {
                  final confirm =
                      await showCupertinoModalPopup<bool>(
                    context: context,
                    builder: (ctx) => CupertinoActionSheet(
                      title: const Text('Usuń gwarancję'),
                      message: const Text(
                          'Tej operacji nie można cofnąć.'),
                      actions: [
                        CupertinoActionSheetAction(
                          isDestructiveAction: true,
                          onPressed: () =>
                              Navigator.pop(ctx, true),
                          child: const Text('Usuń'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text('Anuluj'),
                      ),
                    ),
                  );
                  if (confirm == true) {
                    await SupabaseService.client
                        .from('warranties')
                        .delete()
                        .eq('id', warranty.id);
                    ref.invalidate(warrantyListProvider);
                  }
                },
              ),
              );
            },
          ),
        );
      },
    );
  }
}
