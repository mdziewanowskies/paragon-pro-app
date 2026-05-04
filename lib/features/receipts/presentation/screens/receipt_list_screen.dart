import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../../core/services/haptics.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../../core/services/receipt_image_cache.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/models/receipt_model.dart';
import '../../data/receipt_repository.dart';
import '../widgets/advanced_filters.dart';
import '../widgets/receipt_card.dart';
import '../widgets/receipt_edit_dialog.dart';
import '../widgets/ksef_invoice_preview.dart';
import '../../../warranties/presentation/widgets/warranty_dialog.dart';
import '../../../complaints/presentation/widgets/complaint_letter_dialog.dart';

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
  static const _pageSize = 15;
  int _lastRefreshSignal = 0;

  // Multi-select
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  // Sub-tab filter
  ReceiptFilterType _filterType = ReceiptFilterType.all;
  Map<ReceiptFilterType, int> _counts = {
    ReceiptFilterType.all: 0,
    ReceiptFilterType.receiptsOnly: 0,
    ReceiptFilterType.ksefOnly: 0,
  };

  // Family filter
  bool _showFamilyReceipts = false;

  // Sorting
  String _orderBy = 'uploaded_at';
  bool _ascending = false;
  String _sortLabel = 'Data ↓';

  // Filters
  String? _category;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  double? _amountMin;
  double? _amountMax;

  String? _familyId;

  @override
  void initState() {
    super.initState();
    _loadFamilyId();
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

  Future<void> _loadFamilyId() async {
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final membership = await SupabaseService.client
          .from('family_members')
          .select('family_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted && membership != null) {
        setState(() => _familyId = membership['family_id'] as String?);
      }
    } catch (_) {}
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
      final counts = await ref.read(receiptRepositoryProvider).getCounts(
            userId,
            familyId: _showFamilyReceipts ? _familyId : null,
          );
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
            familyId: _showFamilyReceipts ? _familyId : null,
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
            familyId: _showFamilyReceipts ? _familyId : null,
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

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Usuń $count ${count == 1 ? 'paragon' : count <= 4 ? 'paragony' : 'paragonów'}'),
        message: const Text('Tej operacji nie można cofnąć.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Usuń $count'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Anuluj'),
        ),
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      for (final id in _selectedIds) {
        await ref.read(receiptRepositoryProvider).deleteReceipt(id);
      }
      setState(() {
        _selectMode = false;
        _selectedIds.clear();
      });
      _loadReceipts();
      _loadCounts();
    }
  }

  Future<bool> _confirmDelete(ReceiptModel receipt) async {
    final result = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
          'Usuń ${receipt.isKsefInvoice ? 'fakturę' : 'paragon'}'
          '${receipt.merchantName != null ? ' z ${receipt.merchantName}' : ''}',
        ),
        message: const Text('Tej operacji nie można cofnąć.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Anuluj'),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteReceipt(ReceiptModel receipt) async {
    final confirm = await _confirmDelete(receipt);
    if (confirm) {
      HapticFeedback.mediumImpact();
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
        Haptics.medium();
        await _loadReceipts();
        await _loadCounts();
        Haptics.success();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Select mode bar
          if (_selectMode)
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Zaznaczono: ${_selectedIds.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length == _receipts.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds.addAll(_receipts.map((r) => r.id));
                          }
                        });
                      },
                      child: Text(_selectedIds.length == _receipts.length
                          ? 'Odznacz wszystkie'
                          : 'Zaznacz wszystkie'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => _deleteSelected(),
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: const Text('Usuń'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _selectMode = false;
                        _selectedIds.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ),
          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Szukaj po nazwie sklepu lub produkcie...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
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

          // Sub-tabs + Sorting — two separate rows
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  // Row 1: Sub-tabs
                  SingleChildScrollView(
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
                  // Row 2: Family toggle + Sorting + Grid view
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Family toggle
                        if (_familyId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _showFamilyReceipts =
                                    !_showFamilyReceipts);
                                _loadReceipts();
                                _loadCounts();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _showFamilyReceipts
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: _showFamilyReceipts
                                      ? null
                                      : Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.3),
                                        ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.family_restroom_rounded,
                                      size: 14,
                                      color: _showFamilyReceipts
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Rodzinne',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _showFamilyReceipts
                                            ? Colors.white
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        PopupMenuButton<String>(
                          tooltip: 'Sortowanie',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface,
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
                                Icon(Icons.sort_rounded, size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  _sortLabel,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'date_desc':
                                _setSort('Data ↓', 'uploaded_at', false);
                              case 'date_asc':
                                _setSort('Data ↑', 'uploaded_at', true);
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.go('/receipts'),
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
                                Icon(Icons.grid_view_rounded, size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                const Text('Grid',
                                    style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectMode = !_selectMode;
                            if (!_selectMode) _selectedIds.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _selectMode
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: _selectMode
                                  ? null
                                  : Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.checklist_rounded, size: 14,
                                    color: _selectMode
                                        ? Colors.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text('Zaznacz',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectMode
                                          ? Colors.white
                                          : null,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
              hasScrollBody: true,
              child: ReceiptListSkeleton(),
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
                hint: _filterType == ReceiptFilterType.ksefOnly
                    ? 'Przejdź do zakładki KSeF i kliknij "Pobierz faktury"'
                    : 'Wróć na Home i kliknij "Zrób zdjęcie"',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // "Load more" footer
                    if (index == _receipts.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              'Wyświetlono ${_receipts.length} z ${_counts[_filterType] ?? '?'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _isLoadingMore
                                ? const SizedBox(
                                    height: 32,
                                    width: 32,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : OutlinedButton(
                                    onPressed: _loadMore,
                                    child: const Text('Załaduj więcej'),
                                  ),
                          ],
                        ),
                      );
                    }
                    final receipt = _receipts[index];
                    final isSelected = _selectedIds.contains(receipt.id);

                    if (_selectMode) {
                      return Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(receipt.id);
                                } else {
                                  _selectedIds.add(receipt.id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(receipt.id);
                                } else {
                                  _selectedIds.add(receipt.id);
                                }
                              }),
                              child: Opacity(
                                opacity: isSelected ? 1.0 : 0.7,
                                child: ReceiptCard(
                                  receipt: receipt,
                                  currentUserId:
                                      SupabaseService.auth.currentUser?.id,
                                  onTap: () => setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(receipt.id);
                                    } else {
                                      _selectedIds.add(receipt.id);
                                    }
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Dismissible(
                      key: ValueKey(receipt.id),
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
                      confirmDismiss: (_) => _confirmDelete(receipt),
                      onDismissed: (_) {
                        Haptics.medium();
                        ref
                            .read(receiptRepositoryProvider)
                            .deleteReceipt(receipt.id);
                        setState(() => _receipts.removeAt(index));
                        _loadCounts();
                      },
                      child: ReceiptCard(
                        receipt: receipt,
                        currentUserId:
                            SupabaseService.auth.currentUser?.id,
                        onTap: () => _showImagePreview(receipt),
                        onEdit: () => _showEditDialog(receipt),
                        onDelete: () => _deleteReceipt(receipt),
                        onAddWarranty: () =>
                            _showWarrantyDialog(receipt),
                        onComplaint: () =>
                            _showComplaintDialog(receipt),
                      ),
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

  void _showWarrantyDialog(ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => WarrantyDialog(
        receipt: receipt,
        onSaved: () => _loadReceipts(),
      ),
    );
  }

  void _showComplaintDialog(ReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (context) => ComplaintLetterDialog(receipt: receipt),
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
    // No valid image → show rich data preview
    if (!receipt.hasValidImageUrl) {
      showDialog(
        context: context,
        builder: (context) => KsefInvoicePreviewDialog(receipt: receipt),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ReceiptPreviewDialog(receipt: receipt),
    );
  }
}

class _ReceiptPreviewDialog extends StatefulWidget {
  final ReceiptModel receipt;
  const _ReceiptPreviewDialog({required this.receipt});

  @override
  State<_ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<_ReceiptPreviewDialog> {
  String? _localPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path =
        await ReceiptImageCache.getOrFetch(widget.receipt.imageUrl);
    if (mounted) {
      if (path == null) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) =>
              KsefInvoicePreviewDialog(receipt: widget.receipt),
        );
      } else {
        setState(() {
          _localPath = path;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;

    if (_loading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Dialog(
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
                child: Image.file(
                  File(_localPath!),
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
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
