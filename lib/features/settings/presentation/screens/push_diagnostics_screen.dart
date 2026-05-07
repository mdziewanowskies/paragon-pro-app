import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/messaging_service.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// Single-page diagnostics for FCM push registration. Shows exactly
/// what works and what doesn't so we can pin down why the backend
/// `device_push_tokens` table stays empty without scrolling
/// `flutter run` logs.
class PushDiagnosticsScreen extends ConsumerStatefulWidget {
  const PushDiagnosticsScreen({super.key});

  @override
  ConsumerState<PushDiagnosticsScreen> createState() =>
      _PushDiagnosticsScreenState();
}

class _PushDiagnosticsScreenState
    extends ConsumerState<PushDiagnosticsScreen> {
  PushDiagnostics? _diag;
  bool _loading = false;
  bool _registering = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final d = await MessagingService.diagnostics();
      if (mounted) setState(() => _diag = d);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    Haptics.tap();
    setState(() => _registering = true);
    try {
      final ok = await MessagingService.registerCurrentDevice();
      if (!mounted) return;
      AppSnack.show(
        context,
        ok
            ? 'Token zarejestrowany w device_push_tokens.'
            : 'Nie udało się zarejestrować tokena. Sprawdź permission + APNs.',
        kind: ok ? SnackKind.success : SnackKind.error,
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _sendTest() async {
    Haptics.tap();
    setState(() => _sending = true);
    try {
      await MessagingService.sendTestPushToSelf();
      if (!mounted) return;
      AppSnack.show(
        context,
        'Test wysłany. Jeśli nie dostaniesz banera w 10s, problem jest po stronie backendu / FCM.',
        kind: SnackKind.info,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnack.show(
        context,
        'Edge Function odrzuciła żądanie: $e',
        kind: SnackKind.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _diag;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostyka push'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading || d == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _section(
                title: 'Środowisko',
                children: [
                  _row('Platforma', d.platform),
                  _row('Użytkownik', d.userId ?? '— niezalogowany —'),
                ],
              ),
              _section(
                title: 'Uprawnienia',
                children: [
                  _row(
                    'Status',
                    d.authStatus,
                    ok: d.permissionGranted,
                  ),
                ],
                hint: d.permissionGranted
                    ? null
                    : 'iOS: jeśli odrzuciłeś push przy pierwszym '
                        'uruchomieniu, włącz w Ustawieniach systemowych. '
                        'Android 13+: aplikacja musi mieć POST_NOTIFICATIONS.',
              ),
              if (d.platform == 'ios')
                _section(
                  title: 'APNs',
                  children: [
                    _row(
                      'Token APNs',
                      d.hasApnsToken
                          ? '${d.apnsToken!.substring(0, 16)}...'
                          : 'BRAK',
                      ok: d.hasApnsToken,
                    ),
                  ],
                  hint: d.hasApnsToken
                      ? null
                      : 'Bez tokena APNs Firebase nie wystawi tokena '
                          'FCM. Sprawdź: (1) Push Notifications '
                          'capability w Apple Developer dla bundle '
                          'com.paragonpro.paragonPro, (2) APNs Auth '
                          'Key (.p8) wgrany w Firebase Console → '
                          'Project Settings → Cloud Messaging.',
                ),
              _section(
                title: 'Token FCM',
                children: [
                  _row(
                    'Token',
                    d.hasFcmToken
                        ? '${d.fcmToken!.substring(0, 24)}...'
                        : 'BRAK',
                    ok: d.hasFcmToken,
                  ),
                ],
              ),
              _section(
                title: 'Backend (device_push_tokens)',
                children: [
                  _row(
                    'Wpis w bazie',
                    d.backendRowFound ? 'JEST' : 'BRAK',
                    ok: d.backendRowFound,
                  ),
                  if (d.backendRowId != null)
                    _row('Row ID', d.backendRowId!),
                ],
                hint: d.backendRowFound
                    ? null
                    : 'Token nie został zarejestrowany. Naciśnij '
                        '„Zarejestruj urządzenie" poniżej.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _registering ? null : _register,
                  icon: _registering
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.app_registration_rounded),
                  label: const Text('Zarejestruj urządzenie ponownie'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: (!d.backendRowFound || _sending)
                      ? null
                      : _sendTest,
                  icon: _sending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Wyślij testowy push do siebie'),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Pełen łańcuch:\n'
                  'Permission → APNs token (iOS) / FCM Service (Android)\n'
                  '→ FCM token → device_push_tokens\n'
                  '→ trigger notifications → push-on-notify\n'
                  '→ send-native-push → APNs/Android FCM → urządzenie',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    String? hint,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3),
            ),
            const SizedBox(height: 8),
            ...children,
            if (hint != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hint,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool? ok}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ok != null) ...[
            Icon(
              ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 14,
              color: ok ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
