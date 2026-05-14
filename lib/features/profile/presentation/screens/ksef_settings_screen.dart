import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../ksef/presentation/widgets/ksef_settings.dart';

/// V3 ekran konfiguracji KSeF — wycięty z profilu do osobnej podstrony.
/// Audyt: "Help-banner: kolor info (aqua), nie warning yellow" + Walidacja
/// tokenu KSeF w real-time już istnieje w `KsefSettings`.
class KsefSettingsScreen extends ConsumerWidget {
  const KsefSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/profile'),
        ),
        title: const Text('Integracje KSeF'),
      ),
      body: profileState.when(
        loading: () => const LoadingSpinner(),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (profile) {
          final hasToken = profile?.ksefToken != null &&
              profile!.ksefToken!.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              HeroHeader(
                minHeight: 160,
                overline: 'KSeF · Twój Asystent VAT',
                title: hasToken ? 'Skonfigurowane' : 'Skonfiguruj integrację',
                caption: hasToken
                    ? 'Synchronizuj faktury i pobieraj XML automatycznie'
                    : 'Wpisz token API KSeF żeby zacząć synchronizację',
                pills: [
                  HeroPill(
                    icon: hasToken
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    label: hasToken ? 'Aktywne' : 'Wymaga tokenu',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              KsefSettings(),
              const SizedBox(height: AppSpacing.lg),
              const _GuideCard(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

/// Help banner audyt: "kolor info (aqua #06B6D4 12% opacity tło), nie
/// warning yellow. Tekst 'Zobacz przewodnik wideo (45 s)' jako
/// mini-link". Wersja MVP — link wideo zostaje placeholder TODO.
class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentAqua.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentAqua.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  size: 18, color: AppColors.accentAqua),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Jak uzyskać token KSeF?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _GuideStep(
            number: 1,
            text: 'Zaloguj się do portalu KSeF Ministerstwa Finansów',
          ),
          const _GuideStep(
            number: 2,
            text: 'Wygeneruj token "Authorization" w sekcji API',
          ),
          const _GuideStep(
            number: 3,
            text: 'Skopiuj token i wklej go w pole powyżej',
          ),
          const _GuideStep(
            number: 4,
            text: 'Sprawdź połączenie przyciskiem "Test"',
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final int number;
  final String text;
  const _GuideStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentAqua.withValues(alpha: 0.2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.accentAqua,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
