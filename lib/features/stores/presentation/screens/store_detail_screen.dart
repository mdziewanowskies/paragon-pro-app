import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../receipts/data/models/receipt_model.dart';
import '../../../receipts/presentation/widgets/receipt_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final faviconUrl = StoreLogoService.getFaviconUrl(widget.storeName);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (faviconUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    faviconUrl,
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: Text(
                widget.storeName,
                overflow: TextOverflow.ellipsis,
              ),
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
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = _receipts[index];
                      return ReceiptCard(
                        receipt: receipt,
                        currentUserId:
                            SupabaseService.auth.currentUser?.id,
                        onTap: () => _showPreview(receipt),
                        onEdit: () {
                          showDialog(
                            context: context,
                            builder: (_) => ReceiptEditDialog(
                              receipt: receipt,
                              onSaved: _loadReceipts,
                            ),
                          );
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Usuń paragon'),
                              content: const Text(
                                  'Czy na pewno chcesz usunąć ten paragon?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Anuluj'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
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
                        onAddWarranty: () {
                          showDialog(
                            context: context,
                            builder: (_) => WarrantyDialog(
                              receipt: receipt,
                              onSaved: _loadReceipts,
                            ),
                          );
                        },
                        onComplaint: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                ComplaintLetterDialog(receipt: receipt),
                          );
                        },
                      );
                    },
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
                  child: Image.network(receipt.imageUrl),
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
}
