import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/loading_spinner.dart';
import '../../../ksef/presentation/widgets/ksef_settings.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _apartmentNumberController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _bankAccountController = TextEditingController();
  bool _isLoading = false;
  bool _initialized = false;
  bool _obscureIban = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _streetController.dispose();
    _houseNumberController.dispose();
    _apartmentNumberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  void _populateFields() {
    final profile = ref.read(profileProvider).value;
    if (profile != null && !_initialized) {
      _usernameController.text = profile.username ?? '';
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _streetController.text = profile.street ?? '';
      _houseNumberController.text = profile.houseNumber ?? '';
      _apartmentNumberController.text = profile.apartmentNumber ?? '';
      _postalCodeController.text = profile.postalCode ?? '';
      _cityController.text = profile.city ?? '';
      _bankAccountController.text = profile.bankAccountNumber ?? '';
      _initialized = true;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile({
        'username': _usernameController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'street': _streetController.text.trim(),
        'house_number': _houseNumberController.text.trim(),
        'apartment_number': _apartmentNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'bank_account_number': _bankAccountController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil zaktualizowany!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final subscription = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Powrót do panelu'),
        titleTextStyle: Theme.of(context).textTheme.titleMedium,
      ),
      body: profileState.when(
        loading: () => const LoadingSpinner(),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (profile) {
          _populateFields();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Subscription section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded),
                            const SizedBox(width: 8),
                            Text(
                              'Subskrypcja',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const Spacer(),
                            subscription.when(
                              data: (sub) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sub.tier == 'free'
                                      ? 'Darmowy'
                                      : sub.tier == 'premium'
                                          ? 'Premium'
                                          : 'Rodzinny',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              loading: () =>
                                  const SizedBox(width: 16, height: 16),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Zarządzaj swoim planem i limitami',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        subscription.when(
                          data: (sub) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Progress bar
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Paragony w tym miesiącu',
                                            style: TextStyle(fontSize: 13)),
                                        Text(
                                          '${sub.currentMonthReceipts} / ${sub.maxReceiptsPerMonth}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: sub.usagePercentage,
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Twój plan obejmuje:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              _FeatureRow(
                                  '${sub.maxReceiptsPerMonth} paragonów/miesiąc',
                                  true),
                              _FeatureRow(
                                  'Podstawowe OCR', true),
                              if (sub.isPremium) ...[
                                _FeatureRow('Zaawansowane OCR AI', true),
                                _FeatureRow(
                                    'Zaawansowana analityka', true),
                                _FeatureRow(
                                    'Priorytetowe wsparcie', true),
                              ],
                              const SizedBox(height: 16),
                              if (sub.isFree)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        context.go('/pricing'),
                                    icon: const Icon(
                                        Icons.workspace_premium_rounded),
                                    label: const Text('Ulepsz do Premium'),
                                  ),
                                ),
                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      context.go('/pricing'),
                                  child: const Text(
                                      'Zobacz wszystkie plany'),
                                ),
                              ),
                            ],
                          ),
                          loading: () => const LoadingSpinner(),
                          error: (_, __) =>
                              const Text('Błąd ładowania subskrypcji'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // KSeF section
                const KsefSettings(),
                const SizedBox(height: 16),
                // Profile form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dane osobowe',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                                labelText: 'Nazwa użytkownika'),
                            validator: Validators.username,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Imię'),
                                  validator: (v) =>
                                      Validators.required(v, 'Imię'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Nazwisko'),
                                  validator: (v) =>
                                      Validators.required(v, 'Nazwisko'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _streetController,
                            decoration: const InputDecoration(
                                labelText: 'Ulica'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _houseNumberController,
                                  decoration: const InputDecoration(
                                      labelText: 'Nr domu'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller:
                                      _apartmentNumberController,
                                  decoration: const InputDecoration(
                                      labelText: 'Nr mieszkania'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _postalCodeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Kod pocztowy'),
                                  validator: (v) => v != null &&
                                          v.isNotEmpty
                                      ? Validators.postalCode(v)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(
                                      labelText: 'Miasto'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bankAccountController,
                            obscureText: _obscureIban,
                            decoration: InputDecoration(
                              labelText: 'Numer konta bankowego',
                              hintText:
                                  'PL00 0000 0000 0000 0000 0000 0000',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(_obscureIban
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _obscureIban = !_obscureIban),
                                    tooltip: _obscureIban
                                        ? 'Pokaż'
                                        : 'Ukryj',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      if (_bankAccountController
                                          .text.isNotEmpty) {
                                        Clipboard.setData(ClipboardData(
                                            text: _bankAccountController
                                                .text));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Numer konta skopiowany')));
                                      }
                                    },
                                    tooltip: 'Kopiuj',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _saveProfile,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2),
                                    )
                                  : const Text('Zapisz zmiany'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Wyloguj się'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool included;

  const _FeatureRow(this.text, this.included);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: included ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
