import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// V3 Sprint 1 — Tutorial powitalny dla nowych użytkowników.
///
/// Architektura:
/// - Controller trzyma listę kroków + indeks aktualnego + mapę
///   stepId → GlobalKey (kluczy zarejestrowanych z `CoachmarkTarget`).
/// - Kroki mogą wymagać przełączenia zakładki bottom-navu — pole
///   `tabIndex` pilnuje kontekstu; UI scope nawiguje przed pokazaniem
///   spotlight'u.
/// - Po ukończeniu zapisuje flagę `tutorial.coachmark.completed_v1`
///   w SharedPreferences i wraca na zakładkę 0 (Home).
class CoachmarkStep {
  final String id;
  final String title;
  final String body;
  final IconData? icon;

  /// Wymagany tab w `Dashboard` przed pokazaniem kroku. Null = bez
  /// zmiany (pozostajemy gdzie jesteśmy).
  final int? tabIndex;

  /// Krok introdukcyjny lub finałowy — bez konkretnego targetu,
  /// renderowany na środku ekranu jako pełna karta powitalna.
  final bool isIntro;

  const CoachmarkStep({
    required this.id,
    required this.title,
    required this.body,
    this.icon,
    this.tabIndex,
    this.isIntro = false,
  });
}

class CoachmarkState {
  final int index;
  final bool active;
  final bool completed;

  const CoachmarkState({
    this.index = 0,
    this.active = false,
    this.completed = false,
  });

  CoachmarkState copyWith({int? index, bool? active, bool? completed}) =>
      CoachmarkState(
        index: index ?? this.index,
        active: active ?? this.active,
        completed: completed ?? this.completed,
      );
}

class CoachmarkController extends StateNotifier<CoachmarkState> {
  CoachmarkController() : super(const CoachmarkState()) {
    _loadCompleted();
  }

  static const _prefsKey = 'tutorial.coachmark.completed_v1';

  /// Mapa stepId → GlobalKey z `CoachmarkTarget`. Aktualizowana przez
  /// `register/unregister` w cyklu życia widgetów.
  final Map<String, GlobalKey> _targets = {};

  /// Callback do `Dashboard` żeby kontroler mógł przełączyć zakładkę
  /// przed wyświetleniem kroku.
  void Function(int tabIndex)? onChangeTab;

  /// Wszystkie kroki tutorialu — kolejność = kolejność prezentacji.
  static const steps = <CoachmarkStep>[
    CoachmarkStep(
      id: 'intro',
      title: 'Witaj w ParagonPro!',
      body:
          'Pokażę Ci najważniejsze funkcje aplikacji w 60 sekund. Zobaczysz, gdzie dodawać paragony, jak przeglądać gwarancje i co znajdziesz w analityce.',
      icon: Icons.auto_awesome_rounded,
      tabIndex: 0,
      isIntro: true,
    ),
    CoachmarkStep(
      id: 'notification_bell',
      title: 'Powiadomienia',
      body:
          'Tutaj znajdziesz alerty: wygasające gwarancje, raporty miesięczne, zaproszenia do rodziny i sukcesy z gamifikacji.',
      icon: Icons.notifications_active_rounded,
      tabIndex: 0,
    ),
    CoachmarkStep(
      id: 'add_receipt',
      title: 'Dodaj paragon',
      body:
          'Najszybciej zrobisz to z poziomu Home — zdjęciem aparatu lub z galerii. OCR sam wczyta sklep, datę i kwotę.',
      icon: Icons.add_a_photo_rounded,
      tabIndex: 0,
    ),
    CoachmarkStep(
      id: 'tab_receipts',
      title: 'Paragony',
      body:
          'Wszystkie Twoje paragony i faktury KSeF w jednym miejscu. Filtruj po kategorii, sklepie, datach lub szukaj po tekście.',
      icon: Icons.receipt_long_rounded,
      tabIndex: 1,
    ),
    CoachmarkStep(
      id: 'receipt_gestures',
      title: 'Gesty na karcie',
      body:
          'Przytrzymaj kartę paragonu, by zobaczyć szybki podgląd. Przesuń w lewo, by edytować lub usunąć paragon.',
      icon: Icons.touch_app_rounded,
      tabIndex: 1,
    ),
    CoachmarkStep(
      id: 'tab_ksef',
      title: 'KSeF',
      body:
          'Twój asystent VAT. Skonfiguruj token API, synchronizuj faktury i pobieraj XML gotowe do księgowości.',
      icon: Icons.account_balance_rounded,
      tabIndex: 2,
    ),
    CoachmarkStep(
      id: 'tab_warranties',
      title: 'Gwarancje',
      body:
          'Trzymaj gwarancje w jednej liście — z timeline, statusem i alertem na 30 dni przed wygaśnięciem.',
      icon: Icons.shield_rounded,
      tabIndex: 3,
    ),
    CoachmarkStep(
      id: 'tab_more',
      title: 'Więcej',
      body:
          'Analityka wydatków, osiągnięcia, ustawienia profilu, motyw aplikacji i opcje rodziny — wszystko tutaj.',
      icon: Icons.dashboard_customize_rounded,
      tabIndex: 4,
    ),
    CoachmarkStep(
      id: 'outro',
      title: 'Gotowe!',
      body:
          'To wszystko, czego potrzebujesz na start. Możesz uruchomić tutorial ponownie z Ustawień, jeśli zechcesz odświeżyć wiedzę.',
      icon: Icons.celebration_rounded,
      tabIndex: 0,
      isIntro: true,
    ),
  ];

  CoachmarkStep get currentStep => steps[state.index];

  GlobalKey? keyFor(String id) => _targets[id];

  void register(String id, GlobalKey key) {
    _targets[id] = key;
  }

  void unregister(String id, GlobalKey key) {
    if (_targets[id] == key) _targets.remove(id);
  }

  Future<void> _loadCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool(_prefsKey) ?? false;
      if (done) state = state.copyWith(completed: true);
    } catch (_) {}
  }

  /// Startuje tutorial od początku, jeśli nie był jeszcze ukończony.
  /// Trigger ze strony Dashboard po pierwszym renderze.
  void start() {
    if (state.completed || state.active) return;
    state = state.copyWith(active: true, index: 0);
    _applyStepTab();
  }

  /// Wymuszony restart — z Ustawień.
  void forceStart() {
    state = state.copyWith(active: true, index: 0, completed: false);
    _applyStepTab();
  }

  void next() {
    if (!state.active) return;
    final last = state.index == steps.length - 1;
    if (last) {
      _finish();
      return;
    }
    state = state.copyWith(index: state.index + 1);
    _applyStepTab();
  }

  void previous() {
    if (!state.active) return;
    if (state.index == 0) return;
    state = state.copyWith(index: state.index - 1);
    _applyStepTab();
  }

  void skip() => _finish();

  void _applyStepTab() {
    final s = currentStep;
    final tab = s.tabIndex;
    if (tab != null) onChangeTab?.call(tab);
  }

  Future<void> _finish() async {
    state = state.copyWith(active: false, completed: true);
    onChangeTab?.call(0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {}
  }
}

final coachmarkControllerProvider =
    StateNotifierProvider<CoachmarkController, CoachmarkState>(
  (ref) => CoachmarkController(),
);

/// Convenience flag — czytaj w listach żeby przełączyć na demo data.
final tutorialActiveProvider = Provider<bool>((ref) {
  return ref.watch(coachmarkControllerProvider).active;
});
