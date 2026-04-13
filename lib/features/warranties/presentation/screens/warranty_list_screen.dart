import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
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
      loading: () => const LoadingSpinner(message: 'Ładowanie gwarancji...'),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.shield_rounded,
            title: 'Brak gwarancji',
            subtitle: 'Dodaj gwarancję do paragonu, aby śledzić jej status.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(warrantyListProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final warranty = list[index];
              return WarrantyCard(
                warranty: warranty,
                onDelete: () async {
                  await SupabaseService.client
                      .from('warranties')
                      .delete()
                      .eq('id', warranty.id);
                  ref.invalidate(warrantyListProvider);
                },
                onTestEmail: () async {
                  try {
                    await SupabaseService.invokeFunction(
                      'send-warranty-notification',
                      body: {'warrantyId': warranty.id},
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Testowy email wysłany pomyślnie!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Błąd wysyłania: $e')),
                      );
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}
