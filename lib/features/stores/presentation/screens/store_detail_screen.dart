import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/polish_plurals.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../receipts/data/models/receipt_model.dart';
import '../../../receipts/presentation/widgets/receipt_grid_card.dart';
import '../../../receipts/presentation/widgets/receipt_edit_dialog.dart';
import '../../../receipts/presentation/widgets/ksef_invoice_preview.dart';
import '../../../warranties/presentation/widgets/warranty_dialog.dart';
import '../../../complaints/presentation/widgets/complaint_letter_dialog.dart';
import '../../data/store_logo_service.dart';

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String storeId;
  final String storeName;

  const StoreDetailScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  ConsumerState<StoreDetailScreen> createState() =>
      _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  List<ReceiptModel> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final data = await SupabaseService.client
          .from('receipts')
          .select()
          .eq('store_id', widget.storeId)
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false);

      setState(() {
        _receipts =
            (data as List).map((e) => ReceiptModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _totalSpent =>
      _receipts.fold(0, (sum, r) => sum + (r.amount ?? 0));

  @override
  Widget build(BuildContext context) {
    final faviconUrl = StoreLogoService.getFaviconUrl(widget.storeName);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900
        ? 4
        : screenWidth > 600
            ? 3
            : 2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (faviconUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: faviconUrl,
                    width: 24,
                    height: 24,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: Text(widget.storeName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadReceipts(),
        child: _isLoading
            ? const LoadingSpinner()
            : _receipts.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Brak paragonów',
                    subtitle: 'Brak paragonów z tego sklepu',
                  )
                : CustomScrollView(
                    slivers: [
                      // Summary
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                PolishPlurals.receipts(_receipts.length),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Łącznie: ${Formatters.formatCurrency(_totalSpent)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Grid
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.7,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final receipt = _receipts[index];
                              return ReceiptGridCard(
                                receipt: receipt,
                                onTap: () => _showPreview(receipt),
                                onLongPress: () =>
                                    _showActions(receipt),
                              );
                            },
                            childCount: _receipts.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 24)),
                    ],
                  ),
      ),
    );
  }

  void _showPreview(ReceiptModel receipt) {
    if (!receipt.hasValidImageUrl) {
      showDialog(
        context: context,
        builder: (_) => KsefInvoicePreviewDialog(receipt: receipt),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(imageUrl: receipt.imageUrl),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: Colors.white, size: 28),
                  style:
                      IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showActions(ReceiptModel receipt) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Podgląd'),
              onTap: () {
                Navigator.pop(context);
                _showPreview(receipt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edytuj'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => ReceiptEditDialog(
                    receipt: receipt,
                    onSaved: _loadReceipts,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Dodaj gwarancję'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => WarrantyDialog(
                    receipt: receipt,
                    onSaved: _loadReceipts,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Reklamacja'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) =>
                      ComplaintLetterDialog(receipt: receipt),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Usuń',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Usuń paragon'),
                    content: const Text(
                        'Czy na pewno chcesz usunąć ten paragon?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Usuń'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await SupabaseService.client
                      .from('receipts')
                      .delete()
                      .eq('id', receipt.id);
                  _loadReceipts();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
