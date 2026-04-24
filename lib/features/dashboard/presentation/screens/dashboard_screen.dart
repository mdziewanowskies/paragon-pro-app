import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../gamification/data/best_achievement_provider.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/widgets/app_logo.dart';
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

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentTab = 0;

  // "Więcej" sub-screens
  static const _moreItems = [
    _MoreItem(Icons.store_rounded, 'Sklepy'),
    _MoreItem(Icons.analytics_rounded, 'Analityka'),
    _MoreItem(Icons.emoji_events_rounded, 'Gamifikacja'),
    _MoreItem(Icons.family_restroom_rounded, 'Rodzina'),
    _MoreItem(Icons.summarize_rounded, 'Raporty'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfile());
  }

  Future<void> _checkProfile() async {
    await ref.read(profileProvider.notifier).refresh();
    final profile = ref.read(profileProvider).value;
    if (profile == null || !profile.profileCompleted) {
      if (mounted) context.go('/profile-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
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
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Więcej',
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
                WelcomeBanner(userName: profile.value?.firstName),
                const SizedBox(height: 16),
                stats.when(
                  loading: () => const SizedBox(height: 200),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) => DashboardStats(
                    totalExpenses:
                        data['totalExpenses'] as double? ?? 0,
                    avgExpenses: data['avgExpenses'] as double? ?? 0,
                    receiptCount: data['receiptCount'] as int? ?? 0,
                    activeWarranties:
                        data['activeWarranties'] as int? ?? 0,
                    topCategory:
                        data['topCategory'] as String? ?? '-',
                    topMerchant:
                        data['topMerchant'] as String? ?? '-',
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
                ReceiptUpload(
                  onUploaded: () {
                    ref.invalidate(dashboardStatsProvider);
                    ref.invalidate(gamificationDataProvider);
                  },
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

class _MoreItem {
  final IconData icon;
  final String label;
  const _MoreItem(this.icon, this.label);
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
    switch (_selectedIndex!) {
      case 0:
        return const StoresScreen();
      case 1:
        return const AnalyticsScreen();
      case 2:
        return const GamificationScreen();
      case 3:
        return const FamilyScreen();
      case 4:
        return const ReportsScreen();
      default:
        return null;
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
                  icon: const Icon(Icons.arrow_back),
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
              trailing: const Icon(Icons.chevron_right),
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
            trailing: const Icon(Icons.chevron_right),
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
            trailing: const Icon(Icons.chevron_right),
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings'),
          ),
        ),
      ],
    );
  }
}
