import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/paragon_refresh_indicator.dart';
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

enum _WarrantyTab { active, expiring, archive }

class WarrantyListScreen extends ConsumerStatefulWidget {
  const WarrantyListScreen({super.key});

  @override
  ConsumerState<WarrantyListScreen> createState() =>
      _WarrantyListScreenState();
}

class _WarrantyListScreenState extends ConsumerState<WarrantyListScreen> {
  _WarrantyTab _tab = _WarrantyTab.active;

  @override
  Widget build(BuildContext context) {
    final warranties = ref.watch(warrantyListProvider);

    return warranties.when(
      loading: () => const GenericListSkeleton(),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (list) {
        final active = list.where((w) => w.isActive && !w.isExpiringSoon).toList();
        final expiring = list.where((w) => w.isExpiringSoon).toList();
        final archived = list.where((w) => !w.isActive).toList();

        final filtered = switch (_tab) {
          _WarrantyTab.active => active,
          _WarrantyTab.expiring => expiring,
          _WarrantyTab.archive => archived,
        };

        return ParagonRefreshIndicator(
          onRefresh: () async {
            ref.invalidate(warrantyListProvider);
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: _WarrantyHero(
                    activeCount: active.length + expiring.length,
                    expiringCount: expiring.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _SegmentedControl(
                    selected: _tab,
                    counts: {
                      _WarrantyTab.active: active.length,
                      _WarrantyTab.expiring: expiring.length,
                      _WarrantyTab.archive: archived.length,
                    },
                    onChanged: (t) {
                      Haptics.selection();
                      setState(() => _tab = t);
                    },
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: _emptyIcon(),
                    title: _emptyTitle(),
                    subtitle: _emptySubtitle(),
                    accentColor: _tab == _WarrantyTab.expiring
                        ? AppColors.warning500
                        : _tab == _WarrantyTab.archive
                            ? AppColors.textTertiary
                            : AppColors.primary400,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final w = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Slidable(
                            key: ValueKey(w.id),
                            groupTag: 'warranties',
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              extentRatio: 0.55,
                              children: [
                                SlidableAction(
                                  onPressed: (_) async {
                                    final ok = await _confirmDelete(context, w);
                                    if (ok == true) await _deleteWarranty(w);
                                  },
                                  backgroundColor: AppColors.dangerBg,
                                  foregroundColor: AppColors.danger500,
                                  icon: Icons.delete_rounded,
                                  label: 'Usuń',
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ],
                            ),
                            child: WarrantyCard(warranty: w),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _emptyIcon() {
    return switch (_tab) {
      _WarrantyTab.active => Icons.shield_rounded,
      _WarrantyTab.expiring => Icons.timer_outlined,
      _WarrantyTab.archive => Icons.inventory_2_outlined,
    };
  }

  String _emptyTitle() {
    return switch (_tab) {
      _WarrantyTab.active => 'Brak aktywnych gwarancji',
      _WarrantyTab.expiring => 'Nic nie wygasa wkrótce',
      _WarrantyTab.archive => 'Pusta szafa archiwum',
    };
  }

  String _emptySubtitle() {
    return switch (_tab) {
      _WarrantyTab.active =>
        'Tu pojawią się Twoje gwarancje — żadnej nie zapomnisz.',
      _WarrantyTab.expiring =>
        'Świetnie — wszystkie gwarancje mają więcej niż 30 dni do końca.',
      _WarrantyTab.archive =>
        'Gwarancje, które wygasną, wylądują tutaj jako historia.',
    };
  }

  Future<bool?> _confirmDelete(BuildContext context, WarrantyModel w) {
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(
            'Usuń gwarancję${w.merchantName != null ? ' — ${w.merchantName}' : ''}'),
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
  }

  Future<void> _deleteWarranty(WarrantyModel w) async {
    await SupabaseService.client
        .from('warranties')
        .delete()
        .eq('id', w.id);
    ref.invalidate(warrantyListProvider);
  }
}

/// Hero header dla zakładki Gwarancje. Audyt: "XL '5 aktywnych
/// gwarancji', mini '1 wygasa za 4 dni' jako pomarańczowa pill".
class _WarrantyHero extends StatelessWidget {
  final int activeCount;
  final int expiringCount;
  const _WarrantyHero({
    required this.activeCount,
    required this.expiringCount,
  });

  @override
  Widget build(BuildContext context) {
    final title = activeCount == 0
        ? '0'
        : activeCount.toString();
    final caption = activeCount == 1
        ? 'aktywna gwarancja'
        : (activeCount % 10 >= 2 &&
                activeCount % 10 <= 4 &&
                (activeCount % 100 < 12 || activeCount % 100 > 14))
            ? 'aktywne gwarancje'
            : 'aktywnych gwarancji';

    return HeroHeader(
      overline: 'Twoje gwarancje',
      title: title,
      caption: caption,
      minHeight: 180,
      pills: expiringCount > 0
          ? [
              HeroPill(
                icon: Icons.warning_amber_rounded,
                label: _expiringLabel(expiringCount),
                background:
                    AppColors.warning500.withValues(alpha: 0.92),
                foreground: AppColors.primary900,
              ),
            ]
          : null,
    );
  }

  String _expiringLabel(int n) {
    if (n == 1) return '1 wygasa wkrótce';
    return '$n wygasają wkrótce';
  }
}

class _SegmentedControl extends StatelessWidget {
  final _WarrantyTab selected;
  final Map<_WarrantyTab, int> counts;
  final ValueChanged<_WarrantyTab> onChanged;

  const _SegmentedControl({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final tab in _WarrantyTab.values)
            Expanded(
              child: _SegmentButton(
                label: _labelFor(tab),
                count: counts[tab] ?? 0,
                selected: tab == selected,
                onTap: () => onChanged(tab),
              ),
            ),
        ],
      ),
    );
  }

  String _labelFor(_WarrantyTab tab) => switch (tab) {
        _WarrantyTab.active => 'Aktywne',
        _WarrantyTab.expiring => 'Wygasające',
        _WarrantyTab.archive => 'Archiwum',
      };
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.quickCurve,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary500 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
