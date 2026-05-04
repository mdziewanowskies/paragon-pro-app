import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/utils/validators.dart';
import '../../data/ksef_repository.dart';

class KsefSettings extends ConsumerStatefulWidget {
  final VoidCallback? onTokenSaved;

  const KsefSettings({super.key, this.onTokenSaved});

  @override
  ConsumerState<KsefSettings> createState() => _KsefSettingsState();
}

class _KsefSettingsState extends ConsumerState<KsefSettings> {
  final _nipController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool? _connectionOk;

  @override
  void dispose() {
    _nipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    final nipError = Validators.nip(_nipController.text);
    if (nipError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(nipError)));
      return;
    }
    if (_tokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Wklej token API KSeF')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).saveKsefToken(
            _nipController.text.trim(),
            _tokenController.text.trim(),
          );
      widget.onTokenSaved?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token KSeF zapisany pomyślnie!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionOk = null;
    });
    try {
      final repo = ref.read(ksefRepositoryProvider);
      final ok = await repo.testConnection();
      if (mounted) {
        setState(() {
          _connectionOk = ok;
          _isTesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Połączenie z KSeF działa poprawnie!'
                : 'Nie udało się połączyć z KSeF. Sprawdź NIP i token.'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    } on KsefException catch (e) {
      if (mounted) {
        setState(() {
          _connectionOk = false;
          _isTesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Błąd KSeF: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionOk = false;
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final hasToken =
        profile?.ksefToken != null && profile!.ksefToken!.isNotEmpty;

    if (_nipController.text.isEmpty && profile?.ksefNip != null) {
      _nipController.text = profile!.ksefNip!;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded),
                const SizedBox(width: 8),
                Text(
                  'Integracja KSeF',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (hasToken)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_connectionOk ?? true)
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (_connectionOk ?? true)
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 14,
                          color:
                              (_connectionOk ?? true) ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Skonfigurowano',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (_connectionOk ?? true)
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Security info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bezpieczne przechowywanie',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          'Twój token KSeF jest używany bezpiecznie przez serwer do komunikacji z API KSeF.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // How to get token
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Jak uzyskać token KSeF?',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...[
                    '1. Zaloguj się do portalu KSeF na ksef.mf.gov.pl',
                    '2. Przejdź do sekcji "Uprawnienia" lub "Autoryzacja"',
                    '3. Wygeneruj token API dla swojej firmy',
                    '4. Skopiuj token i wklej go poniżej',
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(step,
                          style: const TextStyle(fontSize: 12, height: 1.4)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // NIP field
            TextField(
              controller: _nipController,
              decoration: const InputDecoration(
                labelText: 'NIP firmy *',
                hintText: '1234567890',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // Token field
            TextField(
              controller: _tokenController,
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: 'Token API KSeF *',
                hintText: hasToken
                    ? '••••••••  (zapisany)'
                    : 'Wklej token z portalu KSeF',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveToken,
                    child: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Zapisz token'),
                  ),
                ),
                if (hasToken) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _connectionOk == true
                                ? Icons.check_circle_rounded
                                : Icons.wifi_tethering_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _isTesting
                          ? 'Testowanie...'
                          : _connectionOk == true
                              ? 'OK'
                              : 'Test połączenia',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
