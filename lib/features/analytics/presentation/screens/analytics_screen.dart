import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/category_style.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../../shared/widgets/stat_card.dart' as v3;
import '../../../receipts/data/receipt_repository.dart';

// Provider: full analytics data
final analyticsProvider =
    FutureProvider.autoDispose<_AnalyticsData>((ref) async {
  final userId = SupabaseService.auth.currentUser?.id;
  if (userId == null) return _AnalyticsData.empty();

  final repo = ref.read(receiptRepositoryProvider);
  final receipts = await repo.getReceipts(
    userId: userId,
    limit: 10000,
    filterType: ReceiptFilterType.receiptsOnly,
  );

  // Stats
  double total = 0;
  final Map<String, double> categories = {};
  final Map<String, double> merchants = {};
  final Map<String, double> monthly = {};
  final Map<String, int> merchantCounts = {};
  // Daily aggregation dla ostatnich 30 dni (klucz: ISO yyyy-MM-dd).
  // Audyt: "Bar chart: 30 słupków (dzień miesiąca), nie 5".
  final Map<String, double> daily = {};
  final cutoff = DateTime.now().subtract(const Duration(days: 30));

  for (final r in receipts) {
    final amt = r.amount ?? 0;
    total += amt;

    final cat = r.category ?? 'Inne';
    categories[cat] = (categories[cat] ?? 0) + amt;

    final merchant = r.merchantName ?? 'Nieznany';
    merchants[merchant] = (merchants[merchant] ?? 0) + amt;
    merchantCounts[merchant] = (merchantCounts[merchant] ?? 0) + 1;

    if (r.purchaseDate != null) {
      final key =
          '${r.purchaseDate!.year}-${r.purchaseDate!.month.toString().padLeft(2, '0')}';
      monthly[key] = (monthly[key] ?? 0) + amt;

      if (r.purchaseDate!.isAfter(cutoff)) {
        final d = r.purchaseDate!;
        final dayKey =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        daily[dayKey] = (daily[dayKey] ?? 0) + amt;
      }
    }
  }

  // Wypełniamy daily kluczami także dla dni bez paragonów — żeby wykres
  // miał 30 słupków, a dni "puste" pokazywały się jako 0 zł.
  for (int i = 0; i < 30; i++) {
    final d = DateTime.now().subtract(Duration(days: 29 - i));
    final k =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    daily.putIfAbsent(k, () => 0);
  }
  final sortedDaily = daily.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  // Unique months for average
  final monthCount = monthly.length.clamp(1, 999);
  final avg = total / monthCount;

  // Top category
  String topCategory = 'Inne';
  double topCategoryAmount = 0;
  final filteredCats = Map.of(categories)
    ..remove('Faktury')
    ..remove('Faktura KSeF');
  for (final e in filteredCats.entries) {
    if (e.value > topCategoryAmount) {
      topCategory = e.key;
      topCategoryAmount = e.value;
    }
  }

  // Top 5 merchants by amount
  final topMerchants = merchants.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Sort monthly by key
  final sortedMonthly = monthly.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  // Sort categories by value desc
  final sortedCategories = filteredCats.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Sum of categories actually shown in the pie chart. We use this
  // instead of `total` for percentage calculation so the legend always
  // sums to 100% even when invoices are filtered out.
  final categoriesTotal =
      sortedCategories.fold<double>(0, (acc, e) => acc + e.value);

  return _AnalyticsData(
    totalExpenses: total,
    monthlyAverage: avg,
    topCategory: topCategory,
    topCategoryAmount: topCategoryAmount,
    receiptCount: receipts.length,
    categories: sortedCategories,
    categoriesTotal: categoriesTotal,
    monthly: sortedMonthly,
    daily: sortedDaily,
    topMerchants: topMerchants.take(5).toList(),
    merchantCounts: merchantCounts,
  );
});

class _AnalyticsData {
  final double totalExpenses;
  final double monthlyAverage;
  final String topCategory;
  final double topCategoryAmount;
  final int receiptCount;
  final List<MapEntry<String, double>> categories;
  final double categoriesTotal;
  final List<MapEntry<String, double>> monthly;
  /// Wydatki per dzień dla ostatnich 30 dni (klucz: yyyy-MM-dd).
  /// Audyt: bar chart "30 słupków (dzień miesiąca), nie 5 miesięcy".
  final List<MapEntry<String, double>> daily;
  final List<MapEntry<String, double>> topMerchants;
  final Map<String, int> merchantCounts;

  _AnalyticsData({
    required this.totalExpenses,
    required this.monthlyAverage,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.receiptCount,
    required this.categories,
    required this.categoriesTotal,
    required this.monthly,
    required this.daily,
    required this.topMerchants,
    required this.merchantCounts,
  });

  factory _AnalyticsData.empty() => _AnalyticsData(
        totalExpenses: 0,
        monthlyAverage: 0,
        topCategory: '-',
        topCategoryAmount: 0,
        receiptCount: 0,
        categories: [],
        categoriesTotal: 0,
        monthly: [],
        daily: [],
        topMerchants: [],
        merchantCounts: {},
      );
}

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);

    return analytics.when(
      loading: () => const LoadingSpinner(message: 'Ładowanie analityki...'),
      error: (e, _) => Center(child: Text('Błąd: $e')),
      data: (data) {
        if (data.receiptCount == 0) {
          return const Center(
            child: Text('Dodaj paragony, aby zobaczyć analitykę'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
          Haptics.medium();
          ref.invalidate(analyticsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 350));
          Haptics.success();
        },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AnalyticsHero(data: data),
              const SizedBox(height: 16),
              _StatCards(data: data),
              const SizedBox(height: 16),
              _CategoryPieChart(data: data),
              const SizedBox(height: 16),
              _DailyBarChart(data: data),
              const SizedBox(height: 16),
              _TopMerchants(data: data),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

// ─── Hero header ────────────────────────────────────────────

class _AnalyticsHero extends StatelessWidget {
  final _AnalyticsData data;
  const _AnalyticsHero({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = data.monthly
        .firstWhere((e) => e.key == thisMonthKey,
            orElse: () => const MapEntry('', 0))
        .value;

    return HeroHeader(
      overline: 'Wydatki w tym miesiącu',
      title: Formatters.formatCurrency(thisMonth),
      caption:
          'średnia miesięczna · ${Formatters.formatCurrency(data.monthlyAverage)}',
      minHeight: 180,
      pills: [
        HeroPill(
          icon: Icons.receipt_long_rounded,
          label: '${data.receiptCount} paragonów łącznie',
        ),
      ],
    );
  }
}

// ─── 4 Stat Cards (V3 palette) ──────────────────────────────

class _StatCards extends StatelessWidget {
  final _AnalyticsData data;
  const _StatCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        v3.StatCard(
          icon: Icons.trending_up_rounded,
          variant: v3.StatCardVariant.success,
          value: Formatters.formatCurrency(data.totalExpenses),
          caption: 'łączne wydatki',
        ),
        v3.StatCard(
          icon: Icons.calendar_month_rounded,
          variant: v3.StatCardVariant.info,
          value: Formatters.formatCurrency(data.monthlyAverage),
          caption: 'średnia miesięczna',
        ),
        v3.StatCard(
          icon: Icons.category_rounded,
          variant: v3.StatCardVariant.gold,
          value: data.topCategory,
          caption: 'top kategoria',
          delta: data.topCategoryAmount > 0
              ? Formatters.formatCurrency(data.topCategoryAmount)
              : null,
        ),
        v3.StatCard(
          icon: Icons.receipt_long_rounded,
          variant: v3.StatCardVariant.highlight,
          value: '${data.receiptCount}',
          caption: 'paragonów łącznie',
        ),
      ],
    );
  }
}

// ─── Pie Chart ───────────────────────────────────────────────

/// V3 donut wykres kategorii — semantyczne kolory (Żywność = gold,
/// Tech = aqua, Auto = violet, Usługi = primary, Inne = gray) z
/// `CategoryStyle.of()`, plus XL kwota w centrum z captionem.
///
/// Audyt: "donut chart w jednej tonacji zielonej — segmentów nie da się
/// rozróżnić bez legendy. To anty-pattern wykresu" — naprawione przez
/// reuse tych samych kolorów co karty paragonu.
class _CategoryPieChart extends StatelessWidget {
  final _AnalyticsData data;
  const _CategoryPieChart({required this.data});

  /// Fallback dla kategorii spoza palety semantycznej — dystynktywne
  /// odcienie, ale nie zielone (żeby się nie myliły z primary).
  static const _fallbackColors = [
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF8B5CF6), // indigo
    Color(0xFFF97316), // orange
  ];

  Color _colorFor(String category, int index) {
    final visual = CategoryStyle.of(category);
    // Jeśli kategoria mapuje do "Inne" (fallback w CategoryStyle), używamy
    // dystynktywnego koloru z _fallbackColors zamiast generic szarego —
    // żeby segmenty były rozróżnialne.
    if (visual.color == AppColors.textSecondary) {
      return _fallbackColors[index % _fallbackColors.length];
    }
    return visual.color;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wydatki wg kategorii',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: data.categories.asMap().entries.map((e) {
                        final pct = data.categoriesTotal > 0
                            ? e.value.value / data.categoriesTotal * 100
                            : 0;
                        return PieChartSectionData(
                          color: _colorFor(e.value.key, e.key),
                          value: e.value.value,
                          title:
                              pct > 8 ? '${pct.toStringAsFixed(0)}%' : '',
                          radius: 56,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 3,
                      // Większy hole — robi z pie wykresu prawdziwy donut.
                      centerSpaceRadius: 56,
                    ),
                  ),
                  // Centrum: XL kwota + caption (audyt rekomenduje).
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Formatters.formatCurrency(data.categoriesTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'razem',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: data.categories.asMap().entries.map((e) {
                final pct = data.categoriesTotal > 0
                    ? (e.value.value / data.categoriesTotal * 100)
                    : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorFor(e.value.key, e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${e.value.key} · ${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bar Chart (last 30 days) ───────────────────────────────

/// V3 bar chart 30 dni. Audyt: "30 słupków (dzień miesiąca), nie 5.
/// Wartość pod osią X tylko co 5 dni. Tooltip on tap z spring animation
/// + haptic Light. Dominujący słupek = lighter green".
class _DailyBarChart extends StatelessWidget {
  final _AnalyticsData data;
  const _DailyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.daily.isEmpty) return const SizedBox.shrink();

    final maxY = data.daily
        .map((e) => e.value)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final safeMaxY = maxY > 0 ? maxY * 1.15 : 100.0;
    // Lighter green dla słupka dominującego (powyżej 90% maxY) — ten
    // jeden wyróżnia się "spike day" (np. duży zakup).
    final highlightThreshold = maxY * 0.9;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Wydatki w ostatnich 30 dniach',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap na słupek = szczegóły dnia',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: safeMaxY,
                  barGroups: data.daily.asMap().entries.map((e) {
                    final isHighlight =
                        maxY > 0 && e.value.value >= highlightThreshold;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          width: 6,
                          color: isHighlight
                              ? AppColors.primary400
                              : AppColors.primary500
                                  .withValues(alpha: 0.7),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, _) => Text(
                          Formatters.formatCurrencyShort(value),
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        // Etykieta co 5 dni — gęstsza siatka czytelniej
                        // niż wszystkie 30 (audyt: "wartość pod osią X
                        // tylko co 5 dni").
                        interval: 5,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= data.daily.length) {
                            return const SizedBox.shrink();
                          }
                          final parts = data.daily[idx].key.split('-');
                          final day = int.tryParse(parts.last) ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$day',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 100,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.surfaceDivider.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      // Light haptic tylko przy faktycznym tap'ie (nie
                      // przy gesture continuous'ie).
                      if (event is FlTapDownEvent &&
                          response?.spot != null) {
                        Haptics.tap();
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final entry = data.daily[group.x];
                        final parts = entry.key.split('-');
                        final day = int.tryParse(parts[2]) ?? 0;
                        final month = int.tryParse(parts[1]) ?? 0;
                        const months = [
                          '', 'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
                          'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
                        ];
                        return BarTooltipItem(
                          '$day ${months[month]}\n${Formatters.formatCurrency(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top 5 Merchants ────────────────────────────────────────

class _TopMerchants extends StatelessWidget {
  final _AnalyticsData data;
  const _TopMerchants({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.topMerchants.isEmpty) return const SizedBox.shrink();

    final max = data.topMerchants.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gdzie wydajesz najwięcej (Top 5)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...data.topMerchants.map((e) {
              final ratio = max > 0 ? e.value / max : 0.0;
              final count = data.merchantCounts[e.key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$count ×  ${Formatters.formatCurrency(e.value)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
