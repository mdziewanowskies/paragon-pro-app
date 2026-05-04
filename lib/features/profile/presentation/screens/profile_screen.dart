import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/purchase_service.dart';
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
    final subscription = ref.watch(revenueCatStatusProvider);
    final supabaseSub = ref.watch(subscriptionProvider);
    final hasPremiumInSupabase =
        supabaseSub.valueOrNull?.isPremium ?? false;

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
          _populateFields();

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Section: Subskrypcja ──
                _SectionHeader('Subskrypcja'),
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: subscription.when(
                      loading: () => const LoadingSpinner(),
                      error: (_, __) =>
                          const Text('Błąd ładowania subskrypcji'),
                      data: (sub) {
                        final isPremium =
                            sub.isPremium || hasPremiumInSupabase;
                        final tierLabel = isPremium && sub.isFree
                            ? 'Premium'
                            : sub.tierLabel;
                        return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPremium
                                    ? Icons.workspace_premium_rounded
                                    : Icons.card_membership_rounded,
                                size: 20,
                                color: isPremium
                                    ? Colors.amber
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Plan $tierLabel',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (sub.isTrial) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Trial',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (sub.expirationDate != null &&
                              !sub.isLifetime) ...[
                            const SizedBox(height: 8),
                            Text(
                              sub.willRenew
                                  ? 'Odnawia się: ${sub.expirationDate!.day}.${sub.expirationDate!.month}.${sub.expirationDate!.year}'
                                  : 'Wygasa: ${sub.expirationDate!.day}.${sub.expirationDate!.month}.${sub.expirationDate!.year}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                          if (sub.isLifetime) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Subskrypcja dożywotnia',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.green),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (!isPremium)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    context.go('/pricing'),
                                child:
                                    const Text('Ulepsz do Pro'),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => RevenueCatService
                                    .showCustomerCenter(),
                                child: const Text(
                                    'Zarządzaj subskrypcją'),
                              ),
                            ),
                        ],
                      );
                      },
                    ),
                  ),
                ),

                // ── Section: Integracja KSeF ──
                _SectionHeader('Integracja KSeF'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KsefSettings(),
                ),

                // ── Section: Dane osobowe ──
                _SectionHeader('Dane osobowe'),
                _GroupedField(
                    controller: _usernameController,
                    label: 'Nazwa użytkownika',
                    validator: Validators.username),
                _GroupedRow(children: [
                  _GroupedField(
                      controller: _firstNameController,
                      label: 'Imię',
                      validator: (v) => Validators.required(v, 'Imię')),
                  _GroupedField(
                      controller: _lastNameController,
                      label: 'Nazwisko',
                      validator: (v) => Validators.required(v, 'Nazwisko')),
                ]),

                // ── Section: Adres ──
                _SectionHeader('Adres'),
                _GroupedField(
                    controller: _streetController, label: 'Ulica'),
                _GroupedRow(children: [
                  _GroupedField(
                      controller: _houseNumberController,
                      label: 'Nr domu'),
                  _GroupedField(
                      controller: _apartmentNumberController,
                      label: 'Nr mieszkania'),
                ]),
                _GroupedRow(children: [
                  _GroupedField(
                      controller: _postalCodeController,
                      label: 'Kod pocztowy',
                      validator: (v) =>
                          v != null && v.isNotEmpty
                              ? Validators.postalCode(v)
                              : null),
                  _GroupedField(
                      controller: _cityController, label: 'Miasto'),
                ]),

                // ── Section: Finanse ──
                _SectionHeader('Finanse'),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _bankAccountController,
                    obscureText: _obscureIban,
                    decoration: InputDecoration(
                      labelText: 'Numer konta bankowego',
                      hintText: 'PL00 0000 0000 0000 0000 0000 0000',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscureIban
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                                size: 20),
                            onPressed: () => setState(
                                () => _obscureIban = !_obscureIban),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              if (_bankAccountController.text.isNotEmpty) {
                                Clipboard.setData(ClipboardData(
                                    text: _bankAccountController.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Numer konta skopiowany')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Save button ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Zapisz zmiany'),
                    ),
                  ),
                ),

                // ── Quick links ──
                _SectionHeader(''),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _QuickLink(
                        icon: Icons.monetization_on_rounded,
                        label: 'Plany cenowe',
                        onTap: () => context.go('/pricing'),
                      ),
                      _QuickLink(
                        icon: Icons.settings_rounded,
                        label: 'Ustawienia',
                        onTap: () => context.go('/settings'),
                      ),
                      _QuickLink(
                        icon: Icons.logout_rounded,
                        label: 'Wyloguj się',
                        color: Colors.red,
                        onTap: () async {
                          final confirm = await showCupertinoModalPopup<bool>(
                            context: context,
                            builder: (ctx) => CupertinoActionSheet(
                              title: const Text('Wylogowanie'),
                              message: const Text(
                                  'Czy na pewno chcesz się wylogować?'),
                              actions: [
                                CupertinoActionSheetAction(
                                  isDestructiveAction: true,
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Wyloguj'),
                                ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
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
                    ],
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

// ─── Helpers ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _GroupedField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _GroupedField({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }
}

class _GroupedRow extends StatelessWidget {
  final List<_GroupedField> children;
  const _GroupedRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: children.asMap().entries.map((entry) {
          final i = entry.key;
          final child = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
              child: TextFormField(
                controller: child.controller,
                decoration: InputDecoration(labelText: child.label),
                validator: child.validator,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w500, fontSize: 15)),
        trailing:
            Icon(Icons.chevron_right_rounded, color: color ?? Colors.grey, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
