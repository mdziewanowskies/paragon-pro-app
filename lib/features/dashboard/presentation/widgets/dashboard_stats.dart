import 'package:flutter/material.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/stat_card.dart';

/// V3 stats grid 2×2 — każda karta dostaje swój semantyczny kolor.
/// Audyt: "primary green tylko jako akcent, karty stat dostają 4 różne
/// kolory (success / info / highlight / gold)".
class DashboardStats extends StatelessWidget {
  final double totalExpenses;
  final double avgExpenses;
  final int receiptCount;
  final int activeWarranties;
  final String topCategory;
  final String topMerchant;

  /// Procentowy udział top kategorii w wydatkach (np. 56). Renderuje
  /// się w stopce karty "Top kategoria" jako mini-delta.
  final double? topCategoryShare;

  /// Wartość wydana w top kategorii — fallback do `topMerchant`
  /// jeśli nieznana.
  final double? topCategoryAmount;

  /// Delta % wydatków vs poprzedni miesiąc (np. -12 = mniej o 12%,
  /// 8 = więcej o 8%). Null = ukrywamy linię delty.
  final double? expensesDelta;

  /// Liczba paragonów dodanych w ostatnich 7 dniach.
  final int? receiptsThisWeek;

  /// Liczba gwarancji wygasających w ciągu najbliższych 14 dni.
  final int? warrantiesExpiringSoon;

  const DashboardStats({
    super.key,
    this.totalExpenses = 0,
    this.avgExpenses = 0,
    this.receiptCount = 0,
    this.activeWarranties = 0,
    this.topCategory = '-',
    this.topMerchant = '-',
    this.topCategoryShare,
    this.topCategoryAmount,
    this.expensesDelta,
    this.receiptsThisWeek,
    this.warrantiesExpiringSoon,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        StatCard(
          icon: Icons.account_balance_wallet_rounded,
          variant: StatCardVariant.success,
          value: Formatters.formatCurrency(totalExpenses),
          caption: 'wydatki w tym miesiącu',
          delta: _formatExpensesDelta(),
        ),
        StatCard(
          icon: Icons.receipt_long_rounded,
          variant: StatCardVariant.info,
          value: receiptCount.toString(),
          caption: 'paragony zeskanowane',
          delta: receiptsThisWeek != null && receiptsThisWeek! > 0
              ? '+$receiptsThisWeek w tym tygodniu'
              : null,
        ),
        StatCard(
          icon: Icons.shield_rounded,
          variant: StatCardVariant.highlight,
          value: activeWarranties.toString(),
          caption: 'aktywne gwarancje',
          delta:
              warrantiesExpiringSoon != null && warrantiesExpiringSoon! > 0
                  ? '⚠ $warrantiesExpiringSoon wygasa wkrótce'
                  : null,
        ),
        StatCard(
          icon: Icons.category_rounded,
          variant: StatCardVariant.gold,
          value: topCategory,
          caption: topCategoryShare != null
              ? 'top kategoria · ${topCategoryShare!.toStringAsFixed(0)}%'
              : 'top kategoria',
          delta: topCategoryAmount != null
              ? Formatters.formatCurrency(topCategoryAmount!)
              : (topMerchant != '-' ? topMerchant : null),
        ),
      ],
    );
  }

  String? _formatExpensesDelta() {
    if (expensesDelta == null || expensesDelta == 0) return null;
    final up = expensesDelta! > 0;
    final symbol = up ? '▲' : '▼';
    final pct = expensesDelta!.abs().toStringAsFixed(0);
    return '$symbol $pct% wzgl. zeszłego mies.';
  }
}
