import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../gamification/data/best_achievement_provider.dart';
import '../../../onboarding/coachmark/coachmark_controller.dart';
import '../../../onboarding/coachmark/coachmark_overlay.dart';
import '../../../onboarding/coachmark/coachmark_target.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/gamification_progress.dart';
import '../../../receipts/presentation/screens/receipt_list_screen.dart';
import '../../../receipts/presentation/widgets/receipt_upload.dart';
import '../../../receipts/data/receipt_repository.dart';
import '../../../warranties/presentation/screens/warranty_list_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../gamification/presentation/screens/gamification_screen.dart';
import '../../../family/presentation/screens/family_screen.dart';
import '../../../ksef/presentation/screens/ksef_panel_screen.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../stores/presentation/screens/stores_screen.dart';

// Dashboard data providers
final dashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};

  final repo = ref.read(receiptRepositoryProvider);

  final receipts = await repo.getReceipts(
    userId: userId,
    limit: 10000,
    filterType: ReceiptFilterType.receiptsOnly,
  );

  double total = 0;
  Map<String, double> catExpenses = {};
  Map<String, int> merchantCounts = {};

  for (final r in receipts) {
    total += r.amount ?? 0;
    final cat = r.category ?? 'Inne';
    catExpenses[cat] = (catExpenses[cat] ?? 0) + (r.amount ?? 0);
    final merchant = r.merchantName ?? 'Nieznany';
    merchantCounts[merchant] = (merchantCounts[merchant] ?? 0) + 1;
  }

  final avg = receipts.isNotEmpty ? total / receipts.length : 0.0;

  String topCategory = '-';
  final receiptCategories = Map.of(catExpenses)
    ..remove('Faktury')
    ..remove('Faktura KSeF');
  if (receiptCategories.isNotEmpty) {
    topCategory = receiptCategories.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  String topMerchant = '-';
  if (merchantCounts.isNotEmpty) {
    topMerchant = merchantCounts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  // Liczbowo: udział top kategorii w wydatkach oraz jej suma w PLN
  // — używane przez StatCard "Top kategoria" (caption "56%" + delta).
  double topCategoryShare = 0;
  double topCategoryAmount = 0;
  final receiptCategoriesTotal = receiptCategories.values
      .fold<double>(0, (sum, v) => sum + v);
  if (topCategory != '-' && receiptCategoriesTotal > 0) {
    topCategoryAmount = receiptCategories[topCategory] ?? 0;
    topCategoryShare = topCategoryAmount / receiptCategoriesTotal * 100;
  }

  // Paragony dodane w ostatnich 7 dniach — mini-delta do karty paragonów.
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  final receiptsThisWeek =
      receipts.where((r) => r.uploadedAt.isAfter(weekAgo)).length;

  final now = DateTime.now().toIso8601String().split('T').first;
  final warranties = await SupabaseService.client
      .from('warranties')
      .select('id, end_date')
      .eq('user_id', userId)
      .gte('end_date', now);
  final activeWarranties = (warranties as List).length;
  // Wygasające w ciągu najbliższych 14 dni — warning delta na karcie.
  final soon = DateTime.now()
      .add(const Duration(days: 14))
      .toIso8601String()
      .split('T')
      .first;
  final warrantiesExpiringSoon = warranties.where((w) {
    final end = w['end_date'] as String?;
    return end != null && end.compareTo(now) >= 0 && end.compareTo(soon) <= 0;
  }).length;

  return {
    'totalExpenses': total,
    'avgExpenses': avg,
    'receiptCount': receipts.length,
    'receiptsThisWeek': receiptsThisWeek,
    'activeWarranties': activeWarranties,
    'warrantiesExpiringSoon': warrantiesExpiringSoon,
    'topCategory': topCategory,
    'topMerchant': topMerchant,
    'topCategoryShare': topCategoryShare,
    'topCategoryAmount': topCategoryAmount,
  };
});

final gamificationDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};

  final data = await SupabaseService.client
      .from('user_gamification')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  return data ??
      {'points': 0, 'level': 1, 'streak_count': 0, 'total_receipts': 0};
});

class DashboardScreen extends ConsumerStatefulWidget {
  /// Optional bottom-nav index to land on. Used by push-notification
  /// deep linking — e.g. a warranty-expiring push routes to /?tab=3.
  final int? initialTab;
  const DashboardScreen({super.key, this.initialTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late int _currentTab = (widget.initialTab ?? 0).clamp(0, 4);

  // "Więcej" sub-screens. KSeF and Family are always visible — when
  // the user lacks the tier, the destination screen renders a locked
  // upsell instead of being hidden (V3 'naturalny funnel' pattern).
  static const _moreItems = [
    _MoreItem(Icons.store_rounded, 'Sklepy', _MoreItemKey.stores),
    _MoreItem(Icons.analytics_rounded, 'Analityka', _MoreItemKey.analytics),
    _MoreItem(
        Icons.emoji_events_rounded, 'Gamifikacja', _MoreItemKey.gamification),
    _MoreItem(Icons.family_restroom_rounded, 'Rodzina', _MoreItemKey.family),
    _MoreItem(Icons.summarize_rounded, 'Raporty', _MoreItemKey.reports),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
      _wireTutorial();
    });
  }

  void _wireTutorial() {
    if (!mounted) return;
    final ctrl = ref.read(coachmarkControllerProvider.notifier);
    ctrl.onChangeTab = (i) {
      if (!mounted) return;
      if (_currentTab != i) setState(() => _currentTab = i);
    };
    // Auto-start dla nowych userów po 600 ms — daje czas hero/stats
    // wyrenderować się przed pokazaniem spotlight'u.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      ctrl.start();
    });
  }

  Future<void> _checkProfile() async {
    if (!mounted) return;
    try {
      await ref.read(profileProvider.notifier).refresh();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final profile = ref.read(profileProvider).value;
    if (profile == null || !profile.profileCompleted) {
      if (mounted) context.go('/profile-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: IndexedStack(
                key: ValueKey(_currentTab),
                index: _currentTab,
                children: [
                  _HomeTab(),
                  const ReceiptListScreen(),
                  const KsefPanelScreen(),
                  const WarrantyListScreen(),
                  _MoreTab(items: _moreItems),
                ],
              ),
            ),
          ),
          const CoachmarkOverlay(),
        ],
      ),
      bottomNavigationBar: Stack(
        children: [
          NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (i) {
              if (i != _currentTab) Haptics.selection();
              setState(() => _currentTab = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Paragony',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded),
                label: 'KSeF',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: 'Gwarancje',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: 'Więcej',
              ),
            ],
          ),
          // Niewidoczne CoachmarkTarget'y nałożone na NavigationBar —
          // 5 równych kolumn 72 px wysokości, dokładnie pokrywają
          // NavigationDestination'y. Brak hitboxu (IgnorePointer) —
          // nie zabieramy tapów oryginalnej nawigacji.
          Positioned.fill(
            child: IgnorePointer(
              child: SizedBox(
                height: 72,
                child: Row(
                  children: const [
                    Expanded(child: SizedBox.expand()),
                    Expanded(
                      child: CoachmarkTarget(
                        stepId: 'tab_receipts',
                        padding: 4,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      child: CoachmarkTarget(
                        stepId: 'tab_ksef',
                        padding: 4,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      child: CoachmarkTarget(
                        stepId: 'tab_warranties',
                        padding: 4,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(
                      child: CoachmarkTarget(
                        stepId: 'tab_more',
                        padding: 4,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home Tab ────────────────────────────────────────────────

class _HomeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final gamification = ref.watch(gamificationDataProvider);

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.darkBackground,
          title: const AppLogoWithText(logoSize: 32, fontSize: 18),
          actions: [
            const CoachmarkTarget(
              stepId: 'notification_bell',
              child: NotificationBell(),
            ),
            IconButton(
              icon: const Icon(Icons.person_rounded),
              onPressed: () => context.go('/profile'),
              tooltip: 'Profil',
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.go('/settings'),
              tooltip: 'Ustawienia',
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Wylogowanie'),
                    content:
                        const Text('Czy na pewno chcesz się wylogować?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Anuluj'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Wyloguj'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              tooltip: 'Wyloguj',
            ),
          ],
        ),
        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _HomeHeroHeader(
                  userName: profile.value?.firstName,
                  stats: stats,
                  gamification: gamification,
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: stats.when(
                    loading: () => const KeyedSubtree(
                      key: ValueKey('stats-skeleton'),
                      child: DashboardStatsSkeleton(),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (data) => KeyedSubtree(
                      key: const ValueKey('stats-data'),
                      child: DashboardStats(
                        totalExpenses:
                            data['totalExpenses'] as double? ?? 0,
                        avgExpenses: data['avgExpenses'] as double? ?? 0,
                        receiptCount: data['receiptCount'] as int? ?? 0,
                        receiptsThisWeek:
                            data['receiptsThisWeek'] as int?,
                        activeWarranties:
                            data['activeWarranties'] as int? ?? 0,
                        warrantiesExpiringSoon:
                            data['warrantiesExpiringSoon'] as int?,
                        topCategory:
                            data['topCategory'] as String? ?? '-',
                        topMerchant:
                            data['topMerchant'] as String? ?? '-',
                        topCategoryShare:
                            data['topCategoryShare'] as double?,
                        topCategoryAmount:
                            data['topCategoryAmount'] as double?,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                gamification.when(
                  loading: () => const SizedBox(height: 150),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) {
                    final userId =
                        SupabaseService.auth.currentUser?.id ?? '';
                    final best =
                        ref.watch(bestAchievementProvider(userId));
                    return GamificationProgress(
                      level: data['level'] as int? ?? 1,
                      points: data['points'] as int? ?? 0,
                      streakDays: data['streak_count'] as int? ?? 0,
                      totalReceipts:
                          data['total_receipts'] as int? ?? 0,
                      bestAchievementIcon:
                          best.value?['icon'] as String?,
                      bestAchievementName:
                          best.value?['name'] as String?,
                    );
                  },
                ),
                const SizedBox(height: 16),
                CoachmarkTarget(
                  stepId: 'add_receipt',
                  padding: 8,
                  child: ReceiptUpload(
                    onUploaded: () {
                      ref.invalidate(dashboardStatsProvider);
                      ref.invalidate(gamificationDataProvider);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── Recent receipts ──
                _SectionHeader(
                  icon: Icons.receipt_long_rounded,
                  title: 'Ostatnie paragony',
                  actionLabel: 'Wszystkie',
                  onAction: () {
                    // Navigate to receipts tab via bottom nav
                    final state = context.findAncestorStateOfType<_DashboardScreenState>();
                    if (state != null && state.mounted) {
                      // ignore: invalid_use_of_protected_member
                      state.setState(() => state._currentTab = 1);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _RecentReceipts(),
                const SizedBox(height: 20),

                // ── Expiring warranties + Month summary ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _MonthSummary(stats: stats)),
                    const SizedBox(width: 12),
                    Expanded(child: _KsefSummary()),
                  ],
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── More Tab ────────────────────────────────────────────────

enum _MoreItemKey { stores, analytics, gamification, family, reports }

class _MoreItem {
  final IconData icon;
  final String label;
  final _MoreItemKey key;
  const _MoreItem(this.icon, this.label, this.key);
}

class _MoreTab extends StatefulWidget {
  final List<_MoreItem> items;
  const _MoreTab({required this.items});

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  int? _selectedIndex;

  Widget? get _selectedScreen {
    if (_selectedIndex == null) return null;
    if (_selectedIndex! >= widget.items.length) return null;
    switch (widget.items[_selectedIndex!].key) {
      case _MoreItemKey.stores:
        return const StoresScreen();
      case _MoreItemKey.analytics:
        return const AnalyticsScreen();
      case _MoreItemKey.gamification:
        return const GamificationScreen();
      case _MoreItemKey.family:
        return const FamilyScreen();
      case _MoreItemKey.reports:
        return const ReportsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex != null) {
      return Column(
        children: [
          // Back bar
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _selectedIndex = null),
                ),
                Text(
                  widget.items[_selectedIndex!].label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _selectedScreen!),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Więcej',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        ...widget.items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(item.label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => setState(() => _selectedIndex = i),
            ),
          );
        }),
        const SizedBox(height: 8),
        // Quick links
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            title: const Text('Profil',
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/profile'),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.workspace_premium_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            title: const Text('Plany cenowe',
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/pricing'),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.settings_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            title: const Text('Ustawienia',
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/settings'),
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ─────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    )),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Recent Receipts ────────────────────────────────────────

class _RecentReceipts extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRecent(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final items = snap.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.map((r) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r['merchant_name'] as String? ?? 'Paragon',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.formatCurrency(
                                (r['amount'] as num?)?.toDouble()),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (r['purchase_date'] != null)
                            Text(
                              Formatters.formatDate(
                                  DateTime.tryParse(r['purchase_date'])),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecent() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final data = await SupabaseService.client
          .from('receipts')
          .select('merchant_name, amount, purchase_date')
          .eq('user_id', userId)
          .eq('is_ksef_invoice', false)
          .order('uploaded_at', ascending: false)
          .limit(4);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }
}

// ─── Month Summary ──────────────────────────────────────────

class _MonthSummary extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> stats;
  const _MonthSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                const Text('Podsumowanie',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            stats.when(
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const Text('-'),
              data: (data) {
                final total = data['totalExpenses'] as double? ?? 0;
                final count = data['receiptCount'] as int? ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.formatCurrency(total),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '$count paragonów łącznie',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── KSeF Summary ───────────────────────────────────────────

class _KsefSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int>(
      future: _fetchKsefCount(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    const Text('Faktury KSeF',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  'zsynchronizowanych',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int> _fetchKsefCount() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final data = await SupabaseService.client
          .from('receipts')
          .select('id')
          .eq('user_id', userId)
          .eq('is_ksef_invoice', true);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }
}

/// V3 home hero — gradient header z greetingiem, kwotą XL miesiąca i
/// pillem poziomu. Zastępuje stary `WelcomeBanner` (jasnozielony pasek
/// na ciemnozielonym = niski kontrast).
class _HomeHeroHeader extends StatelessWidget {
  final String? userName;
  final AsyncValue<Map<String, dynamic>> stats;
  final AsyncValue<Map<String, dynamic>> gamification;

  const _HomeHeroHeader({
    required this.userName,
    required this.stats,
    required this.gamification,
  });

  @override
  Widget build(BuildContext context) {
    final greetName = (userName != null && userName!.trim().isNotEmpty)
        ? userName!.trim()
        : 'tutaj';
    final overline = 'Cześć, $greetName 👋';

    final data = stats.valueOrNull ?? const <String, dynamic>{};
    final total = (data['totalExpenses'] as double?) ?? 0;
    final count = (data['receiptCount'] as int?) ?? 0;

    final gami = gamification.valueOrNull ?? const <String, dynamic>{};
    final level = (gami['level'] as int?) ?? 1;
    final points = (gami['points'] as int?) ?? 0;

    final title = Formatters.formatCurrency(total);
    final caption = count > 0
        ? 'wydatków w tym miesiącu · $count ${_paragonyForm(count)}'
        : 'zacznij od pierwszego paragonu';

    return HeroHeader(
      overline: overline,
      title: title,
      caption: caption,
      pills: [
        HeroPill(
          icon: Icons.emoji_events_rounded,
          label: 'Poziom $level · $points pkt',
        ),
      ],
    );
  }

  String _paragonyForm(int n) {
    // Polish plural — 1 paragon, 2-4 paragony, 5+ paragonów.
    if (n == 1) return 'paragon';
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'paragony';
    }
    return 'paragonów';
  }
}
