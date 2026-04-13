import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/utils/validators.dart';

class KsefSettings extends ConsumerStatefulWidget {
  const KsefSettings({super.key});

  @override
  ConsumerState<KsefSettings> createState() => _KsefSettingsState();
}

class _KsefSettingsState extends ConsumerState<KsefSettings> {
  final _nipController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _isSaving = false;

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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;

    // Pre-fill if available
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
                          'Twój token KSeF jest przechowywany bezpiecznie i używany tylko do komunikacji z API KSeF.',
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
                      Icon(Icons.info_outline, color: Colors.amber, size: 18),
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
                hintText: 'Wklej token z portalu KSeF',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureToken ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureToken = !_obscureToken),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveToken,
                child: _isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Zapisz token KSeF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
