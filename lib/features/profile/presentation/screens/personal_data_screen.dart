import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/hero_header.dart';
import '../../../../shared/widgets/loading_spinner.dart';

/// V3 ekran danych osobowych — wycięty z głównego profilu.
/// Audyt: "Rozbij profil na 3 podstrony: ... 'Dane osobowe'".
class PersonalDataScreen extends ConsumerStatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  ConsumerState<PersonalDataScreen> createState() =>
      _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
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

  void _populate() {
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

  Future<void> _save() async {
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.go('/profile'),
        ),
        title: const Text('Dane osobowe'),
      ),
      body: profileState.when(
        loading: () => const LoadingSpinner(),
        error: (e, _) => Center(child: Text('Błąd: $e')),
        data: (profile) {
          _populate();
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const HeroHeader(
                  minHeight: 140,
                  overline: 'Twoje dane',
                  title: 'Personalizuj',
                  caption:
                      'Imię, adres i numer konta — używane przy reklamacjach i fakturach',
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionLabel('Profil'),
                const SizedBox(height: AppSpacing.sm),
                _CardBox(
                  child: Column(
                    children: [
                      _Field(
                        controller: _usernameController,
                        label: 'Nazwa użytkownika',
                        icon: Icons.alternate_email_rounded,
                        validator: Validators.username,
                      ),
                      const _CardDivider(),
                      _Field(
                        controller: _firstNameController,
                        label: 'Imię',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => Validators.required(v, 'Imię'),
                      ),
                      const _CardDivider(),
                      _Field(
                        controller: _lastNameController,
                        label: 'Nazwisko',
                        icon: Icons.badge_outlined,
                        validator: (v) => Validators.required(v, 'Nazwisko'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('Adres'),
                const SizedBox(height: AppSpacing.sm),
                _CardBox(
                  child: Column(
                    children: [
                      _Field(
                        controller: _streetController,
                        label: 'Ulica',
                        icon: Icons.location_on_outlined,
                      ),
                      const _CardDivider(),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _houseNumberController,
                              label: 'Nr domu',
                              flat: true,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 56,
                            color: AppColors.surfaceDivider,
                          ),
                          Expanded(
                            child: _Field(
                              controller: _apartmentNumberController,
                              label: 'Nr mieszkania',
                              flat: true,
                            ),
                          ),
                        ],
                      ),
                      const _CardDivider(),
                      _Field(
                        controller: _postalCodeController,
                        label: 'Kod pocztowy',
                        icon: Icons.markunread_mailbox_outlined,
                        validator: (v) => v != null && v.isNotEmpty
                            ? Validators.postalCode(v)
                            : null,
                      ),
                      const _CardDivider(),
                      _Field(
                        controller: _cityController,
                        label: 'Miasto',
                        icon: Icons.location_city_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionLabel('Finanse'),
                const SizedBox(height: AppSpacing.sm),
                _CardBox(
                  child: TextFormField(
                    controller: _bankAccountController,
                    obscureText: _obscureIban,
                    decoration: InputDecoration(
                      labelText: 'Numer konta bankowego',
                      hintText: 'PL00 0000 0000 0000 0000 0000 0000',
                      prefixIcon:
                          const Icon(Icons.account_balance_outlined),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscureIban
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                            ),
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
                                    content: Text('Numer konta skopiowany'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Zapisz zmiany'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _CardBox extends StatelessWidget {
  final Widget child;
  const _CardBox({required this.child});

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
        child: child,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: AppColors.surfaceDivider,
      indent: 16,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? Function(String?)? validator;
  final bool flat;

  const _Field({
    required this.controller,
    required this.label,
    this.icon,
    this.validator,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: flat ? 12 : 4,
        vertical: 4,
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 18) : null,
          border: flat ? InputBorder.none : null,
          enabledBorder: flat ? InputBorder.none : null,
          focusedBorder: flat ? InputBorder.none : null,
          filled: !flat,
        ),
        validator: validator,
      ),
    );
  }
}
