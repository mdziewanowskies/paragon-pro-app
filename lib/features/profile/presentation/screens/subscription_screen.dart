import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/loading_spinner.dart';

/// V3 ekran subskrypcji. Audyt: "Karta 'Plan Premium' jako hero:
/// gradient (premium gold #FBBF24 → #F59E0B), korona icon, 'Plan
/// Premium' + 'odnowienie 14 czerwca'. CTA outline → 'Zarządzaj'".
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(revenueCatStatusProvider);
    final supabaseSub = ref.watch(subscriptionProvider);
    final supabaseTier = supabaseSub.valueOrNull;
    final hasPremiumInSupabase = supabaseTier?.isPremium ?? false;
    final isFamilyLite = supabaseTier?.isFamilyLite ?? false;
    final isInheritedFromFamily =
        supabaseTier?.isInheritedFromFamily ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/profile'),
        ),
        title: const Text('Moja subskrypcja'),
      ),
      body: subscription.when(
        loading: () => const LoadingSpinner(),
        error: (_, __) => const Center(
            child: Text('Błąd ładowania subskrypcji')),
        data: (sub) {
          final isPremium = sub.isPremium || hasPremiumInSupabase;
          final tierLabel = isPremium
              ? 'Premium'
              : isFamilyLite
                  ? 'Family Lite'
                  : sub.tierLabel;
          final expiry = sub.expirationDate;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PlanHero(
                isPremium: isPremium,
                isFamilyLite: isFamilyLite,
                isTrial: sub.isTrial,
                isLifetime: sub.isLifetime,
                willRenew: sub.willRenew,
                expirationDate: expiry,
                tierLabel: tierLabel,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (isFamilyLite && !isPremium)
                _InfoBanner(
                  icon: Icons.info_outline_rounded,
                  text: isInheritedFromFamily
                      ? 'Family Lite z planu rodziny — masz 15 paragonów miesięcznie, wspólne wydatki i gamifikację rodzinną.'
                      : 'Family Lite — 15 paragonów/mies, wspólne wydatki, gamifikacja rodzinna.',
                ),
              if (isFamilyLite && !isPremium)
                const SizedBox(height: AppSpacing.lg),
              const _SectionLabel('Co dostajesz'),
              const SizedBox(height: AppSpacing.sm),
              _PerksCard(isPremium: isPremium),
              const SizedBox(height: AppSpacing.xl),
              if (!isPremium)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/pricing'),
                    icon:
                        const Icon(Icons.workspace_premium_rounded),
                    label: Text(
                      isFamilyLite
                          ? 'Odblokuj pełne Premium'
                          : 'Ulepsz do Premium',
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        RevenueCatService.showCustomerCenter(),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text('Zarządzaj subskrypcją'),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _PlanHero extends StatelessWidget {
  final bool isPremium;
  final bool isFamilyLite;
  final bool isTrial;
  final bool isLifetime;
  final bool willRenew;
  final DateTime? expirationDate;
  final String tierLabel;

  const _PlanHero({
    required this.isPremium,
    required this.isFamilyLite,
    required this.isTrial,
    required this.isLifetime,
    required this.willRenew,
    required this.expirationDate,
    required this.tierLabel,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isPremium
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentGold, AppColors.accentGoldDeep],
          )
        : AppColors.heroGradientV3;
    final overline = isTrial
        ? 'Okres próbny'
        : isPremium
            ? 'Twój plan'
            : 'Aktualny plan';
    final caption = _captionFor();

    return HeroHeader(
      gradient: gradient,
      minHeight: 200,
      overline: overline,
      title: 'Plan $tierLabel',
      caption: caption,
      pills: isLifetime
          ? const [
              HeroPill(
                icon: Icons.all_inclusive_rounded,
                label: 'Dożywotnio',
                background: Color(0x33052E1F),
              ),
            ]
          : willRenew
              ? const [
                  HeroPill(
                    icon: Icons.autorenew_rounded,
                    label: 'Auto-odnowienie',
                  ),
                ]
              : null,
    );
  }

  String _captionFor() {
    if (isLifetime) {
      return 'Subskrypcja dożywotnia — bez końca';
    }
    final d = expirationDate;
    if (d == null) {
      return isPremium
          ? 'Pełen dostęp do KSeF, analityki i rodzin'
          : 'Bez integracji KSeF, limit 5 paragonów/mies';
    }
    final dateLabel = _polishDate(d);
    if (willRenew) {
      return 'Odnawia się $dateLabel';
    }
    return 'Wygasa $dateLabel';
  }

  String _polishDate(DateTime d) {
    const months = [
      'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
      'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
    );
  }
}

class _PerksCard extends StatelessWidget {
  final bool isPremium;
  const _PerksCard({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final perks = isPremium
        ? const [
            ('Skany paragonów', 'bez limitów', true),
            ('Faktury KSeF', 'synchronizacja + XML', true),
            ('Analityka', 'pełna z donut + bar chart', true),
            ('Rodzina', 'do 5 osób, wspólne wydatki', true),
            ('Wsparcie', 'priorytetowe', true),
          ]
        : const [
            ('Skany paragonów', '5 / miesiąc', false),
            ('Faktury KSeF', 'wymaga Premium', false),
            ('Analityka', 'podstawowa', true),
            ('Rodzina', 'wymaga Premium', false),
            ('Wsparcie', 'standard', true),
          ];

    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.md,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        children: [
          for (var i = 0; i < perks.length; i++) ...[
            _PerkRow(
              label: perks[i].$1,
              value: perks[i].$2,
              enabled: perks[i].$3,
            ),
            if (i < perks.length - 1)
              Divider(height: 1, color: c.surfaceDivider),
          ],
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;

  const _PerkRow({
    required this.label,
    required this.value,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.lock_rounded,
            size: 18,
            color: enabled
                ? AppColors.primary400
                : c.textTertiary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled
                    ? c.textPrimary
                    : c.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: enabled
                  ? c.textSecondary
                  : c.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentAqua.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.accentAqua.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.accentAqua),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
