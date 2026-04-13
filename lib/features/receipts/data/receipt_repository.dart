import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import 'models/receipt_model.dart';

final receiptRepositoryProvider =
    Provider<ReceiptRepository>((ref) => ReceiptRepository());

class ReceiptRepository {
  static const _table = 'receipts';

  Future<List<ReceiptModel>> getReceipts({
    required String userId,
    int limit = 20,
    int offset = 0,
    String? category,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? amountMin,
    double? amountMax,
    String orderBy = 'uploaded_at',
    bool ascending = false,
  }) async {
    var query = SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', userId);

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or(
          'merchant_name.ilike.%$search%,receipt_number.ilike.%$search%');
    }
    if (dateFrom != null) {
      query = query.gte(
          'purchase_date', dateFrom.toIso8601String().split('T').first);
    }
    if (dateTo != null) {
      query = query.lte(
          'purchase_date', dateTo.toIso8601String().split('T').first);
    }
    if (amountMin != null) {
      query = query.gte('amount', amountMin);
    }
    if (amountMax != null) {
      query = query.lte('amount', amountMax);
    }

    final data = await query
        .order(orderBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => ReceiptModel.fromJson(e)).toList();
  }

  Future<ReceiptModel> getReceipt(String id) async {
    final data = await SupabaseService.client
        .from(_table)
        .select()
        .eq('id', id)
        .single();
    return ReceiptModel.fromJson(data);
  }

  Future<ReceiptModel> createReceipt(Map<String, dynamic> receipt) async {
    final data = await SupabaseService.client
        .from(_table)
        .insert(receipt)
        .select()
        .single();
    return ReceiptModel.fromJson(data);
  }

  Future<ReceiptModel> updateReceipt(
      String id, Map<String, dynamic> updates) async {
    final data = await SupabaseService.client
        .from(_table)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return ReceiptModel.fromJson(data);
  }

  Future<void> deleteReceipt(String id) async {
    await SupabaseService.client.from(_table).delete().eq('id', id);
  }

  Future<int> countThisMonth(String userId) async {
    final result = await SupabaseService.rpc(
      'count_user_receipts_this_month',
      params: {'_user_id': userId},
    );
    return result as int? ?? 0;
  }

  Future<List<ReceiptModel>> getKsefInvoices({
    required String userId,
    String? ksefNumber,
    String? sellerNip,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? vatRate,
  }) async {
    var query = SupabaseService.client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('is_ksef_invoice', true);

    if (ksefNumber != null && ksefNumber.isNotEmpty) {
      query = query.ilike('ksef_number', '%$ksefNumber%');
    }
    if (sellerNip != null && sellerNip.isNotEmpty) {
      query = query.eq('seller_nip', sellerNip);
    }
    if (dateFrom != null) {
      query = query.gte(
          'purchase_date', dateFrom.toIso8601String().split('T').first);
    }
    if (dateTo != null) {
      query = query.lte(
          'purchase_date', dateTo.toIso8601String().split('T').first);
    }
    if (vatRate != null && vatRate.isNotEmpty) {
      query = query.eq('vat_rate', vatRate);
    }

    final data = await query.order('uploaded_at', ascending: false);
    return (data as List).map((e) => ReceiptModel.fromJson(e)).toList();
  }

  Future<Map<String, double>> getExpensesByCategory(String userId) async {
    final data = await SupabaseService.client
        .from(_table)
        .select('category, amount')
        .eq('user_id', userId)
        .not('amount', 'is', null);

    final Map<String, double> result = {};
    for (final row in data as List) {
      final cat = (row['category'] as String?) ?? 'Inne';
      final amt = (row['amount'] as num?)?.toDouble() ?? 0;
      result[cat] = (result[cat] ?? 0) + amt;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getMonthlyExpenses(
      String userId) async {
    final data = await SupabaseService.client
        .from(_table)
        .select('purchase_date, amount')
        .eq('user_id', userId)
        .not('amount', 'is', null)
        .order('purchase_date');

    final Map<String, double> monthly = {};
    for (final row in data as List) {
      if (row['purchase_date'] != null) {
        final date = DateTime.parse(row['purchase_date'] as String);
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amt = (row['amount'] as num?)?.toDouble() ?? 0;
        monthly[key] = (monthly[key] ?? 0) + amt;
      }
    }

    return monthly.entries
        .map((e) => {'month': e.key, 'amount': e.value})
        .toList();
  }
}
