import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/loading_spinner.dart';

/// V3 profile hub. Audyt: "Rozbij profil na 3 podstrony: 'Moja
/// subskrypcja', 'KSeF / integracje', 'Dane osobowe'. Wjazd przez
/// ListItem cards z chevronem".
///
/// Stara wersja była 554-liniową planszą trzech niezwiązanych tematów
/// (rozliczenia + integracje + dane osobowe). Księgowa szukała NIP-u,
/// a dostawała token API KSeF — mieszane priorytety.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final supabaseTier = ref.watch(subscriptionProvider).valueOrNull;
    final isPremium = supabaseTier?.isPremium ?? false;
    final isFamilyLite = supabaseTier?.isFamilyLite ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Profil'),
      ),
      body: profileState.when(
        loading: () => const LoadingSpinner(),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (profile) {
          final name = [profile?.firstName, profile?.lastName]
              .where((p) => p != null && p.trim().isNotEmpty)
              .join(' ')
              .trim();
          final displayName = name.isEmpty
              ? (profile?.username ?? 'Twój profil')
              : name;
          final username = profile?.username;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHero(
                name: displayName,
                username: username,
                tierLabel: isPremium
                    ? 'Premium'
                    : isFamilyLite
                        ? 'Family Lite'
                        : 'Free',
                isPremium: isPremium,
                isFamilyLite: isFamilyLite,
              ),
              const SizedBox(height: AppSpacing.xl),
              _NavCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: AppColors.accentGold,
                title: 'Moja subskrypcja',
                subtitle: isPremium
                    ? 'Plan Premium — pełen dostęp'
                    : isFamilyLite
                        ? 'Family Lite z planu rodziny'
                        : 'Plan Free — kup Premium dla pełnych funkcji',
                onTap: () => context.go('/profile/subscription'),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.description_rounded,
                iconColor: AppColors.accentAqua,
                title: 'Integracje KSeF',
                subtitle: profile?.ksefToken != null &&
                        profile!.ksefToken!.isNotEmpty
                    ? 'Skonfigurowane'
                    : 'Nie skonfigurowane',
                onTap: () => context.go('/profile/ksef'),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.person_rounded,
                iconColor: AppColors.primary400,
                title: 'Dane osobowe',
                subtitle: name.isEmpty
                    ? 'Uzupełnij imię i nazwisko'
                    : 'Imię, adres, numer konta',
                onTap: () => context.go('/profile/personal'),
              ),
              const SizedBox(height: AppSpacing.xl),
              _NavCard(
                icon: Icons.monetization_on_rounded,
                iconColor: AppColors.primary500,
                title: 'Plany cenowe',
                subtitle: 'Porównaj Premium z Family',
                onTap: () => context.go('/pricing'),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.settings_rounded,
                iconColor: AppColors.textSecondary,
                title: 'Ustawienia aplikacji',
                subtitle: 'Język, motyw, powiadomienia',
                onTap: () => context.go('/settings'),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LogoutTile(
                onLogout: () async {
                  final confirm = await showCupertinoModalPopup<bool>(
                    context: context,
                    builder: (ctx) => CupertinoActionSheet(
                      title: const Text('Wylogowanie'),
                      message: const Text(
                          'Czy na pewno chcesz się wylogować?'),
                      actions: [
                        CupertinoActionSheetAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Wyloguj'),
                        ),
                      ],
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Anuluj'),
                      ),
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

/// Mały hero z avatarem (litera imienia) + nazwa + tier pill. Audyt
/// rekomenduje hero-celebrację posiadania subskrypcji w profilu.
class _ProfileHero extends StatelessWidget {
  final String name;
  final String? username;
  final String tierLabel;
  final bool isPremium;
  final bool isFamilyLite;

  const _ProfileHero({
    required this.name,
    required this.username,
    required this.tierLabel,
    required this.isPremium,
    required this.isFamilyLite,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final gradient = isPremium
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.accentGold, AppColors.accentGoldDeep],
          )
        : AppColors.heroGradientV3;

    return HeroHeader(
      gradient: gradient,
      minHeight: 160,
      overline: username != null && username!.isNotEmpty
          ? '@$username'
          : 'Twój profil',
      title: name,
      caption: isPremium
          ? 'Plan Premium · pełen dostęp'
          : isFamilyLite
              ? 'Family Lite · z planu rodziny'
              : 'Plan Free',
      pills: [
        HeroPill(
          icon: isPremium
              ? Icons.workspace_premium_rounded
              : Icons.card_membership_rounded,
          label: tierLabel,
          background: isPremium
              ? AppColors.primary900.withValues(alpha: 0.32)
              : Colors.white.withValues(alpha: 0.18),
        ),
      ],
      fab: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// ListTile-style nav card. Audyt: "Wjazd przez ListItem cards z
/// chevronem".
class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.danger500.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.danger500.withValues(alpha: 0.24)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded,
                  size: 18, color: AppColors.danger500),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Wyloguj się',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
