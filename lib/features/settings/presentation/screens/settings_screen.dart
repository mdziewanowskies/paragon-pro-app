import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/supabase_service.dart';

/// V3 ustawienia. Audyt: "Sekcje: 'Konto' (avatar + email + Zarządzaj
/// subskrypcją), 'Preferencje' (Język, Motyw, Powiadomienia push, Haptic
/// feedback toggle), 'Pomoc' (Polityka, Regulamin, Wersja, Skontaktuj
/// się), 'Strefa niebezpieczna' (Usuń konto, schowana, otwierana
/// confirm-sheetem)".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Konto'),
          const SizedBox(height: AppSpacing.sm),
          _Section([
            _SettingTile(
              icon: Icons.person_rounded,
              iconColor: AppColors.primary400,
              label: 'Mój profil',
              trailingText: 'Imię · adres · bank',
              onTap: () => context.go('/profile/personal'),
            ),
            _SettingTile(
              icon: Icons.workspace_premium_rounded,
              iconColor: AppColors.accentGold,
              label: 'Moja subskrypcja',
              trailingText: 'Plan · odnowienie',
              onTap: () => context.go('/profile/subscription'),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Preferencje'),
          const SizedBox(height: AppSpacing.sm),
          _Section([
            _SettingTile(
              icon: Icons.language_rounded,
              iconColor: AppColors.accentAqua,
              label: 'Język',
              trailingText: 'Polski',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Obecnie dostępny tylko język polski'),
                  ),
                );
              },
            ),
            _ThemeModeTile(
              currentMode: ref.watch(themeModeProvider),
              onTap: () => _showThemeSheet(context, ref),
            ),
            _SettingTile(
              icon: Icons.notifications_active_rounded,
              iconColor: AppColors.warning500,
              label: 'Powiadomienia',
              trailingText: 'Zarządzaj w systemie',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Otwórz Ustawienia systemu → ParagonPro → Powiadomienia'),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          const _SectionLabel('Pomoc'),
          const SizedBox(height: AppSpacing.sm),
          _Section([
            _SettingTile(
              icon: Icons.privacy_tip_outlined,
              iconColor: AppColors.textSecondary,
              label: 'Polityka prywatności',
              onTap: () => _showPrivacyDialog(context),
            ),
            _SettingTile(
              icon: Icons.description_outlined,
              iconColor: AppColors.textSecondary,
              label: 'Regulamin',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Regulamin w przygotowaniu')),
                );
              },
            ),
            _SettingTile(
              icon: Icons.support_agent_rounded,
              iconColor: AppColors.primary400,
              label: 'Skontaktuj się',
              trailingText: 'support@paragonpro.pl',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Napisz na support@paragonpro.pl'),
                  ),
                );
              },
            ),
            _SettingTile(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              label: 'Wersja aplikacji',
              trailingText: '1.0.0',
              onTap: null,
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
          const _SectionLabel('Strefa niebezpieczna'),
          const SizedBox(height: AppSpacing.sm),
          _DangerTile(
            onTap: () => _showDeleteAccountDialog(context, ref),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Polityka prywatności'),
        content: const SingleChildScrollView(
          child: Text(
            'ParagonPro przetwarza Twoje dane osobowe w celu '
            'świadczenia usługi zarządzania paragonami i fakturami.\n\n'
            'Dane przechowywane:\n'
            '• Dane osobowe (imię, nazwisko, adres)\n'
            '• Zdjęcia paragonów\n'
            '• Dane faktur KSeF\n'
            '• Numer konta bankowego (opcjonalnie)\n\n'
            'Dane są przechowywane na serwerach Supabase (UE) '
            'i nie są udostępniane podmiotom trzecim.\n\n'
            'Masz prawo do: dostępu, sprostowania, usunięcia, '
            'ograniczenia przetwarzania i przenoszenia danych.\n\n'
            'Kontakt: support@paragonpro.pl',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Usuń konto'),
          ],
        ),
        content: const Text(
          'Czy na pewno chcesz usunąć swoje konto?\n\n'
          'Ta operacja jest NIEODWRACALNA. Zostaną usunięte:\n'
          '• Wszystkie paragony i zdjęcia\n'
          '• Gwarancje i dane KSeF\n'
          '• Dane profilu\n'
          '• Historia gamifikacji\n\n'
          'Tej operacji nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final userId = SupabaseService.auth.currentUser?.id;
                if (userId != null) {
                  await SupabaseService.client
                      .from('receipts')
                      .delete()
                      .eq('user_id', userId);
                  await SupabaseService.client
                      .from('warranties')
                      .delete()
                      .eq('user_id', userId);
                  await SupabaseService.client
                      .from('user_gamification')
                      .delete()
                      .eq('user_id', userId);
                  await SupabaseService.client
                      .from('user_achievements')
                      .delete()
                      .eq('user_id', userId);
                  await SupabaseService.client
                      .from('profiles')
                      .delete()
                      .eq('user_id', userId);
                }
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) {
                  context.go('/login');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Konto zostało usunięte'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd usuwania konta: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Usuń konto na zawsze'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Grupowana sekcja ustawień (iOS-style). Pojedyncze ListTile z
/// dividerami zamiast osobnych kart — czytelniej i bardziej kompaktowo.
class _Section extends StatelessWidget {
  final List<_SettingTile> children;
  const _Section(this.children);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.surfaceDivider,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final VoidCallback onTap;
  const _DangerTile({required this.onTap});

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
            color: AppColors.danger500.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.danger500.withValues(alpha: 0.24),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: const Row(
            children: [
              Icon(Icons.delete_forever_rounded,
                  size: 22, color: AppColors.danger500),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Usuń konto',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Trwale usuwa konto i wszystkie dane',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.danger500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showThemeSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(themeModeProvider);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const Text(
                'Motyw aplikacji',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Wybierz tryb wyświetlania albo śledź ustawienia systemu',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ThemeOption(
                icon: Icons.phone_iphone_rounded,
                label: 'Według systemu',
                description: 'Śledzi ustawienia iOS / Android',
                selected: current == ThemeMode.system,
                onTap: () {
                  Haptics.selection();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.system);
                  Navigator.pop(sheetCtx);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _ThemeOption(
                icon: Icons.light_mode_rounded,
                label: 'Jasny',
                description: 'Biały dashboard, czarne teksty',
                selected: current == ThemeMode.light,
                onTap: () {
                  Haptics.selection();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.light);
                  Navigator.pop(sheetCtx);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                label: 'Ciemny',
                description: 'Niski kontrast, idealny wieczorem',
                selected: current == ThemeMode.dark,
                onTap: () {
                  Haptics.selection();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.dark);
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ThemeModeTile extends StatelessWidget {
  final ThemeMode currentMode;
  final VoidCallback onTap;
  const _ThemeModeTile({required this.currentMode, required this.onTap});

  String get _label => switch (currentMode) {
        ThemeMode.system => 'Według systemu',
        ThemeMode.light => 'Jasny',
        ThemeMode.dark => 'Ciemny',
      };

  IconData get _icon => switch (currentMode) {
        ThemeMode.system => Icons.phone_iphone_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return _SettingTile(
      icon: _icon,
      iconColor: AppColors.accentViolet,
      label: 'Motyw',
      trailingText: _label,
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
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
            color: selected
                ? AppColors.primary500.withValues(alpha: 0.12)
                : AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.primary500
                  : AppColors.surfaceDivider,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.primary400
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.primary400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
