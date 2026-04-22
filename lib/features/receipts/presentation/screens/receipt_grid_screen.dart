import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../widgets/ksef_invoice_preview.dart';
import '../widgets/receipt_grid_card.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../data/models/receipt_model.dart';
import '../../data/receipt_repository.dart';
import '../widgets/advanced_filters.dart';

class ReceiptGridScreen extends ConsumerStatefulWidget {
  const ReceiptGridScreen({super.key});

  @override
  ConsumerState<ReceiptGridScreen> createState() => _ReceiptGridScreenState();
}

class _ReceiptGridScreenState extends ConsumerState<ReceiptGridScreen> {
  final _searchController = TextEditingController();
  List<ReceiptModel> _receipts = [];
  bool _isLoading = true;

  ReceiptFilterType _filterType = ReceiptFilterType.all;
  String _orderBy = 'uploaded_at';
  bool _ascending = false;
  String _sortLabel = 'Data ↓';

  String? _category;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double? _amountMin;
  double? _amountMax;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final data = await ref.read(receiptRepositoryProvider).getReceipts(
            userId: userId,
            limit: 500,
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900
        ? 4
        : screenWidth > 600
            ? 3
            : 2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Wszystkie paragony'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sortowanie',
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              switch (value) {
                case 'date_desc':
                  setState(() { _sortLabel = 'Data ↓'; _orderBy = 'uploaded_at'; _ascending = false; });
                case 'date_asc':
                  setState(() { _sortLabel = 'Data ↑'; _orderBy = 'uploaded_at'; _ascending = true; });
                case 'amount_desc':
                  setState(() { _sortLabel = 'Kwota ↓'; _orderBy = 'amount'; _ascending = false; });
                case 'amount_asc':
                  setState(() { _sortLabel = 'Kwota ↑'; _orderBy = 'amount'; _ascending = true; });
                case 'merchant_asc':
                  setState(() { _sortLabel = 'A-Z'; _orderBy = 'merchant_name'; _ascending = true; });
              }
              _loadReceipts();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'date_desc', child: Text('Data ↓')),
              const PopupMenuItem(value: 'date_asc', child: Text('Data ↑')),
              const PopupMenuItem(value: 'amount_desc', child: Text('Kwota ↓')),
              const PopupMenuItem(value: 'amount_asc', child: Text('Kwota ↑')),
              const PopupMenuItem(value: 'merchant_asc', child: Text('Sklep A-Z')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadReceipts(),
        child: CustomScrollView(
          slivers: [
            // Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Szukaj...',
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
            // Sub-tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip('Wszystko', ReceiptFilterType.all),
                      const SizedBox(width: 8),
                      _chip('Paragony', ReceiptFilterType.receiptsOnly),
                      const SizedBox(width: 8),
                      _chip('Faktury KSeF', ReceiptFilterType.ksefOnly),
                    ],
                  ),
                ),
              ),
            ),
            // Filters
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AdvancedFilters(
                  selectedCategory: _category,
                  dateFrom: _dateFrom,
                  dateTo: _dateTo,
                  amountMin: _amountMin,
                  amountMax: _amountMax,
                  onCategoryChanged: (v) { setState(() => _category = v); _loadReceipts(); },
                  onDateFromChanged: (v) { setState(() => _dateFrom = v); _loadReceipts(); },
                  onDateToChanged: (v) { setState(() => _dateTo = v); _loadReceipts(); },
                  onAmountMinChanged: (v) => setState(() => _amountMin = v),
                  onAmountMaxChanged: (v) => setState(() => _amountMax = v),
                  onReset: () {
                    setState(() { _category = null; _dateFrom = null; _dateTo = null; _amountMin = null; _amountMax = null; });
                    _loadReceipts();
                  },
                ),
              ),
            ),
            // Count
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${_receipts.length} wyników • $_sortLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            // Grid
            if (_isLoading)
              const SliverFillRemaining(child: LoadingSpinner())
            else if (_receipts.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'Brak wyników',
                  subtitle: 'Zmień filtry lub dodaj nowy paragon',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = _receipts[index];
                      return ReceiptGridCard(
                        receipt: r,
                        onTap: () => _showPreview(r),
                      );
                    },
                    childCount: _receipts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, ReceiptFilterType type) {
    final selected = _filterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filterType = type);
        _loadReceipts();
      },
    );
  }

  void _showPreview(ReceiptModel receipt) {
    if (!receipt.hasValidImageUrl) {
      showDialog(
        context: context,
        builder: (context) => KsefInvoicePreviewDialog(receipt: receipt),
      );
    } else {
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
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: receipt.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
