import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../data/models/receipt_model.dart';
import '../../data/receipt_repository.dart';
import '../widgets/advanced_filters.dart';
import '../widgets/receipt_card.dart';
import '../widgets/receipt_edit_dialog.dart';

class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<ReceiptModel> _receipts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 20;

  // Filters
  String? _category;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double? _amountMin;
  double? _amountMax;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _receipts = [];
      _hasMore = true;
    });

    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final data = await ref.read(receiptRepositoryProvider).getReceipts(
            userId: userId,
            limit: _pageSize,
            offset: 0,
            category: _category,
            search: _searchController.text.isEmpty
                ? null
                : _searchController.text,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            amountMin: _amountMin,
            amountMax: _amountMax,
          );

      setState(() {
        _receipts = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final data = await ref.read(receiptRepositoryProvider).getReceipts(
            userId: userId,
            limit: _pageSize,
            offset: _offset,
            category: _category,
            search: _searchController.text.isEmpty
                ? null
                : _searchController.text,
            dateFrom: _dateFrom,
            dateTo: _dateTo,
            amountMin: _amountMin,
            amountMax: _amountMax,
          );

      setState(() {
        _receipts.addAll(data);
        _offset += data.length;
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteReceipt(ReceiptModel receipt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń paragon'),
        content: const Text('Czy na pewno chcesz usunąć ten paragon?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(receiptRepositoryProvider).deleteReceipt(receipt.id);
      _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _loadReceipts(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Szukaj po nazwie sklepu lub produkcie...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadReceipts();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _loadReceipts(),
              ),
            ),
          ),
          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AdvancedFilters(
                selectedCategory: _category,
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                amountMin: _amountMin,
                amountMax: _amountMax,
                onCategoryChanged: (v) {
                  setState(() => _category = v);
                  _loadReceipts();
                },
                onDateFromChanged: (v) {
                  setState(() => _dateFrom = v);
                  _loadReceipts();
                },
                onDateToChanged: (v) {
                  setState(() => _dateTo = v);
                  _loadReceipts();
                },
                onAmountMinChanged: (v) => setState(() => _amountMin = v),
                onAmountMaxChanged: (v) => setState(() => _amountMax = v),
                onReset: () {
                  setState(() {
                    _category = null;
                    _dateFrom = null;
                    _dateTo = null;
                    _amountMin = null;
                    _amountMax = null;
                  });
                  _loadReceipts();
                },
              ),
            ),
          ),
          // List
          if (_isLoading)
            const SliverFillRemaining(
              child: LoadingSpinner(message: 'Ładowanie paragonów...'),
            )
          else if (_receipts.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Brak paragonów',
                subtitle:
                    'Zrób zdjęcie pierwszego paragonu, aby rozpocząć!',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _receipts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      );
                    }
                    final receipt = _receipts[index];
                    return ReceiptCard(
                      receipt: receipt,
                      onEdit: () => _showEditDialog(receipt),
                      onDelete: () => _deleteReceipt(receipt),
                      onAddWarranty: () {
                        // TODO: Navigate to add warranty
                      },
                    );
                  },
                  childCount: _receipts.length + (_hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditDialog(ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => ReceiptEditDialog(
        receipt: receipt,
        onSaved: () => _loadReceipts(),
      ),
    );
  }
}
