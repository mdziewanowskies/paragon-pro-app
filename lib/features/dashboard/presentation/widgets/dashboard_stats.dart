import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/animated_counter.dart';

class DashboardStats extends StatelessWidget {
  final double totalExpenses;
  final double avgExpenses;
  final int receiptCount;
  final int activeWarranties;
  final String topCategory;
  final String topMerchant;

  const DashboardStats({
    super.key,
    this.totalExpenses = 0,
    this.avgExpenses = 0,
    this.receiptCount = 0,
    this.activeWarranties = 0,
    this.topCategory = '-',
    this.topMerchant = '-',
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Łączne wydatki',
          value: Formatters.formatCurrency(totalExpenses),
          subtitle: 'Średnia: ${Formatters.formatCurrency(avgExpenses)}',
          gradient: AppColors.heroGradient,
        ),
        _StatCard(
          icon: Icons.receipt_long_rounded,
          title: 'Paragony',
          valueWidget: AnimatedCounter(
            value: receiptCount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          subtitle: 'Wszystkie paragony',
          gradient: AppColors.accentGradient,
        ),
        _StatCard(
          icon: Icons.shield_rounded,
          title: 'Gwarancje',
          valueWidget: AnimatedCounter(
            value: activeWarranties,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: 'Aktywne',
          isSecondary: true,
        ),
        _StatCard(
          icon: Icons.category_rounded,
          title: 'Top kategoria',
          value: topCategory,
          subtitle: topMerchant,
          isPrimary: true,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final String subtitle;
  final LinearGradient? gradient;
  final bool isSecondary;
  final bool isPrimary;

  const _StatCard({
    required this.icon,
    required this.title,
    this.value,
    this.valueWidget,
    required this.subtitle,
    this.gradient,
    this.isSecondary = false,
    this.isPrimary = false,
  }) : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasGradient = gradient != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: hasGradient ? gradient : null,
        color: hasGradient
            ? null
            : isSecondary
                ? (isDark ? AppColors.darkSecondary : AppColors.lightSecondary)
                : isPrimary
                    ? (isDark
                        ? AppColors.darkPrimary.withValues(alpha: 0.3)
                        : AppColors.lightPrimary.withValues(alpha: 0.1))
                    : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: hasGradient
            ? null
            : Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: hasGradient
                    ? Colors.white.withValues(alpha: 0.8)
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasGradient
                        ? Colors.white.withValues(alpha: 0.8)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          valueWidget ??
              Text(
                value!,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: hasGradient
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: hasGradient
                  ? Colors.white.withValues(alpha: 0.7)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
