import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/supabase_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Język'),
              subtitle: const Text('Polski'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Obecnie dostępny tylko język polski')),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Privacy policy
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Polityka prywatności'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
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
              },
            ),
          ),
          const SizedBox(height: 8),

          // Terms
          Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Regulamin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Regulamin w przygotowaniu')),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // App version
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Wersja aplikacji'),
              subtitle: const Text('1.0.0'),
            ),
          ),
          const SizedBox(height: 16),

          // Test notifications
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: const Text('Test powiadomień'),
                  subtitle: const Text(
                      'Sprawdź czy notyfikacje działają',
                      style: TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService.requestPermission();
                            await NotificationService.showInstant(
                              title: 'Test ParagonPro',
                              body: 'Powiadomienia działają poprawnie!',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Wysłano testowe powiadomienie')),
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Instant',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await NotificationService.requestPermission();
                            await NotificationService
                                .scheduleWarrantyReminder(
                              warrantyId: 'test_${DateTime.now().millisecondsSinceEpoch}',
                              merchantName: 'Test Sklep',
                              expiryDate: DateTime.now()
                                  .add(const Duration(minutes: 1, days: 30)),
                              daysBefore: 30,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Zaplanowano testowe powiadomienie za ~1 min')),
                              );
                            }
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 16),
                          label: const Text('Za 1 min',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Delete account — required by App Store Guideline 5.1.1
          Card(
            color: Colors.red.withValues(alpha: 0.05),
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded,
                  color: Colors.red),
              title: const Text('Usuń konto',
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text(
                'Trwale usuwa konto i wszystkie dane',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
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
                  // Delete user data
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
                        content:
                            Text('Konto zostało usunięte')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Błąd usuwania konta: $e')),
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
