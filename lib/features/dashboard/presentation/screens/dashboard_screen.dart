import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../gamification/data/best_achievement_provider.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/theme_toggle.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/gamification_progress.dart';
import '../widgets/welcome_banner.dart';
import '../../../receipts/presentation/screens/receipt_list_screen.dart';
import '../../../receipts/presentation/widgets/receipt_upload.dart';
import '../../../receipts/data/receipt_repository.dart';
import '../../../warranties/presentation/screens/warranty_list_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../gamification/presentation/screens/gamification_screen.dart';
import '../../../family/presentation/screens/family_screen.dart';
import '../../../ksef/presentation/screens/ksef_panel_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../stores/presentation/screens/stores_screen.dart';

// Dashboard data providers
final dashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return {};

  final repo = ref.read(receiptRepositoryProvider);

  // Get only regular receipts for stats (exclude KSeF invoices)
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
  // Exclude "Faktury" from top category — we only want receipt categories
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

  // Active warranties count — only those not yet expired
  final now = DateTime.now().toIso8601String().split('T').first;
  final warranties = await SupabaseService.client
      .from('warranties')
      .select('id')
      .eq('user_id', userId)
      .gte('end_date', now);
  final activeWarranties = (warranties as List).length;

  return {
    'totalExpenses': total,
    'avgExpenses': avg,
    'receiptCount': receipts.length,
    'activeWarranties': activeWarranties,
    'topCategory': topCategory,
    'topMerchant': topMerchant,
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
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _tabs = const [
    Tab(icon: Icon(Icons.store_rounded), text: 'Sklepy'),
    Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Paragony'),
    Tab(icon: Icon(Icons.description_rounded), text: 'KSeF'),
    Tab(icon: Icon(Icons.shield_rounded), text: 'Gwarancje'),
    Tab(icon: Icon(Icons.analytics_rounded), text: 'Analityka'),
    Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Gamifikacja'),
    Tab(icon: Icon(Icons.family_restroom_rounded), text: 'Rodzina'),
    Tab(icon: Icon(Icons.summarize_rounded), text: 'Raporty'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Check profile on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfile();
    });
  }

  Future<void> _checkProfile() async {
    await ref.read(profileProvider.notifier).refresh();
    final profile = ref.read(profileProvider).value;
    if (profile == null || !profile.profileCompleted) {
      if (mounted) context.go('/profile-setup');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final gamification = ref.watch(gamificationDataProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App bar with gradient
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
              title: const AppLogoWithText(logoSize: 32, fontSize: 18),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_rounded),
                  onPressed: () => context.go('/profile'),
                  tooltip: 'Profil',
                ),
                const ThemeToggle(),
                IconButton(
                  icon: const Icon(Icons.shopping_bag_rounded),
                  onPressed: () => context.go('/pricing'),
                  tooltip: 'Subskrypcja',
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
                        content: const Text(
                            'Czy na pewno chcesz się wylogować?'),
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
            // Dashboard content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Welcome banner
                    WelcomeBanner(
                      userName: profile.value?.firstName,
                    ),
                    const SizedBox(height: 16),
                    // Stats
                    stats.when(
                      loading: () => const SizedBox(height: 200),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (data) => DashboardStats(
                        totalExpenses:
                            data['totalExpenses'] as double? ?? 0,
                        avgExpenses:
                            data['avgExpenses'] as double? ?? 0,
                        receiptCount:
                            data['receiptCount'] as int? ?? 0,
                        activeWarranties:
                            data['activeWarranties'] as int? ?? 0,
                        topCategory:
                            data['topCategory'] as String? ?? '-',
                        topMerchant:
                            data['topMerchant'] as String? ?? '-',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Gamification progress
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
                          streakDays:
                              data['streak_count'] as int? ?? 0,
                          totalReceipts:
                              data['total_receipts'] as int? ?? 0,
                          bestAchievementIcon: best.value?['icon'] as String?,
                          bestAchievementName: best.value?['name'] as String?,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Receipt upload
                    ReceiptUpload(
                      onUploaded: () {
                        ref.invalidate(dashboardStatsProvider);
                        ref.invalidate(gamificationDataProvider);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                ),
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBackground
                    : AppColors.lightBackground,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            StoresScreen(),
            ReceiptListScreen(),
            KsefPanelScreen(),
            WarrantyListScreen(),
            AnalyticsScreen(),
            GamificationScreen(),
            FamilyScreen(),
            ReportsScreen(),
          ],
        ),
      ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _StickyTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}
