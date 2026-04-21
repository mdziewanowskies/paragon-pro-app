import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../data/models/receipt_model.dart';
import '../../data/receipt_repository.dart';
import '../widgets/advanced_filters.dart';
import '../widgets/receipt_card.dart';
import '../widgets/receipt_edit_dialog.dart';

final receiptListRefreshProvider = StateProvider<int>((ref) => 0);

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
  int _lastRefreshSignal = 0;

  // Sub-tab filter
  ReceiptFilterType _filterType = ReceiptFilterType.all;
  Map<ReceiptFilterType, int> _counts = {
    ReceiptFilterType.all: 0,
    ReceiptFilterType.receiptsOnly: 0,
    ReceiptFilterType.ksefOnly: 0,
  };

  // Sorting
  String _orderBy = 'uploaded_at';
  bool _ascending = false;
  String _sortLabel = 'Data dodania ↓';

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
    _loadCounts();
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

  Future<void> _loadCounts() async {
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final counts =
          await ref.read(receiptRepositoryProvider).getCounts(userId);
      if (mounted) setState(() => _counts = counts);
    } catch (_) {}
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
            orderBy: _orderBy,
            ascending: _ascending,
            filterType: _filterType,
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
            orderBy: _orderBy,
            ascending: _ascending,
            filterType: _filterType,
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
        content: Text(
          'Czy na pewno chcesz usunąć ${receipt.isKsefInvoice ? 'fakturę' : 'paragon'}'
          '${receipt.merchantName != null ? ' z ${receipt.merchantName}' : ''}?'
          '\n\nTej operacji nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(receiptRepositoryProvider).deleteReceipt(receipt.id);
      _loadReceipts();
      _loadCounts();
    }
  }

  void _setSort(String label, String orderBy, bool ascending) {
    setState(() {
      _sortLabel = label;
      _orderBy = orderBy;
      _ascending = ascending;
    });
    _loadReceipts();
  }

  @override
  Widget build(BuildContext context) {
    final refreshSignal = ref.watch(receiptListRefreshProvider);
    if (refreshSignal != _lastRefreshSignal) {
      _lastRefreshSignal = refreshSignal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadReceipts();
        _loadCounts();
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadReceipts();
        await _loadCounts();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

          // Sub-tabs: Wszystko / Paragony / Faktury KSeF
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _SubTab(
                            icon: Icons.receipt_long_rounded,
                            label: 'Wszystko',
                            count: _counts[ReceiptFilterType.all] ?? 0,
                            isSelected:
                                _filterType == ReceiptFilterType.all,
                            onTap: () {
                              setState(() =>
                                  _filterType = ReceiptFilterType.all);
                              _loadReceipts();
                            },
                          ),
                          const SizedBox(width: 8),
                          _SubTab(
                            icon: Icons.receipt_rounded,
                            label: 'Paragony',
                            count: _counts[
                                    ReceiptFilterType.receiptsOnly] ??
                                0,
                            isSelected: _filterType ==
                                ReceiptFilterType.receiptsOnly,
                            onTap: () {
                              setState(() => _filterType =
                                  ReceiptFilterType.receiptsOnly);
                              _loadReceipts();
                            },
                          ),
                          const SizedBox(width: 8),
                          _SubTab(
                            icon: Icons.description_rounded,
                            label: 'Faktury KSeF',
                            count:
                                _counts[ReceiptFilterType.ksefOnly] ?? 0,
                            isSelected: _filterType ==
                                ReceiptFilterType.ksefOnly,
                            onTap: () {
                              setState(() => _filterType =
                                  ReceiptFilterType.ksefOnly);
                              _loadReceipts();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sorting dropdown
                  PopupMenuButton<String>(
                    tooltip: 'Sortowanie',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortLabel,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.unfold_more, size: 16),
                        ],
                      ),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'date_desc':
                          _setSort('Data dodania ↓', 'uploaded_at', false);
                        case 'date_asc':
                          _setSort('Data dodania ↑', 'uploaded_at', true);
                        case 'amount_desc':
                          _setSort('Kwota ↓', 'amount', false);
                        case 'amount_asc':
                          _setSort('Kwota ↑', 'amount', true);
                        case 'merchant_asc':
                          _setSort('Sklep A-Z', 'merchant_name', true);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'date_desc',
                          child: Text('Data dodania ↓')),
                      const PopupMenuItem(
                          value: 'date_asc',
                          child: Text('Data dodania ↑')),
                      const PopupMenuItem(
                          value: 'amount_desc',
                          child: Text('Kwota ↓')),
                      const PopupMenuItem(
                          value: 'amount_asc',
                          child: Text('Kwota ↑')),
                      const PopupMenuItem(
                          value: 'merchant_asc',
                          child: Text('Sklep A-Z')),
                    ],
                  ),
                ],
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
            SliverFillRemaining(
              child: EmptyState(
                icon: _filterType == ReceiptFilterType.ksefOnly
                    ? Icons.description_outlined
                    : Icons.receipt_long_rounded,
                title: _filterType == ReceiptFilterType.ksefOnly
                    ? 'Brak faktur KSeF'
                    : 'Brak paragonów',
                subtitle: _filterType == ReceiptFilterType.ksefOnly
                    ? 'Zsynchronizuj faktury w zakładce KSeF'
                    : 'Zrób zdjęcie pierwszego paragonu, aby rozpocząć!',
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
                      currentUserId:
                          SupabaseService.auth.currentUser?.id,
                      onTap: () => _showImagePreview(receipt),
                      onEdit: () => _showEditDialog(receipt),
                      onDelete: () => _deleteReceipt(receipt),
                      onAddWarranty: () {},
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
        onSaved: () {
          _loadReceipts();
          _loadCounts();
        },
      ),
    );
  }

  void _showImagePreview(ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: receipt.imageUrl.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_rounded,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(height: 16),
                            const Text(
                              'Faktura KSeF',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700),
                            ),
                            if (receipt.ksefNumber != null) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                receipt.ksefNumber!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (receipt.merchantName != null)
                              Text(receipt.merchantName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            if (receipt.grossAmount != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${receipt.grossAmount!.toStringAsFixed(2)} zł brutto',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ],
                            if (receipt.netAmount != null &&
                                receipt.vatAmount != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Netto: ${receipt.netAmount!.toStringAsFixed(2)} zł  |  VAT: ${receipt.vatAmount!.toStringAsFixed(2)} zł',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: CachedNetworkImage(
                          imageUrl: receipt.imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(Icons.broken_image,
                                  size: 64, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
            if (receipt.merchantName != null || receipt.amount != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (receipt.merchantName != null)
                        Text(
                          receipt.merchantName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (receipt.amount != null)
                        Text(
                          '${receipt.amount!.toStringAsFixed(2)} zł',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubTab({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? null
              : Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
