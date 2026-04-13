class AppConstants {
  AppConstants._();

  static const String appName = 'ParagonPro';
  static const String appTagline = 'Twój inteligentny asystent finansowy';

  // Supabase - replace with actual values or use env
  static const String supabaseUrl = String.fromEnvironment(
    'https://hxzimocyiblbyoxjxmhj.supabase.co',
    defaultValue: 'https://your-project.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4emltb2N5aWJsYnlveGp4bWhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNjU2MTksImV4cCI6MjA3NzY0MTYxOX0.4mBr-eLUfhGjeDGfzReS7rXRaFouyH8wrJgSLE1ogso',
    defaultValue: 'your-anon-key',
  );

  // Storage
  static const String receiptsBucket = 'receipts';

  // Subscription tiers
  static const String tierFree = 'free';
  static const String tierPremium = 'premium';
  static const String tierFamily = 'family';

  // Limits
  static const int freeMonthlyReceipts = 10;
  static const int premiumMonthlyReceipts = 100;
  static const int familyMonthlyReceipts = 500;

  // Pricing
  static const double premiumPrice = 29.0;
  static const double familyPrice = 49.0;

  // Gamification
  static const int pointsPerLevel = 100;

  // Date format
  static const String dateFormatPl = 'dd.MM.yyyy';
  static const String currencySymbol = 'zł';
  static const String currencyCode = 'PLN';

  // Categories
  static const List<String> receiptCategories = [
    'Spożywcze',
    'Elektronika',
    'Odzież',
    'Zdrowie',
    'Rozrywka',
    'Transport',
    'Dom i ogród',
    'Edukacja',
    'Restauracje',
    'Sport',
    'Inne',
  ];

  // Category icons (Material icon names)
  static const Map<String, int> categoryIcons = {
    'Spożywcze': 0xe57a, // shopping_cart
    'Elektronika': 0xe1e3, // devices
    'Odzież': 0xf04b4, // checkroom
    'Zdrowie': 0xe4c1, // local_hospital
    'Rozrywka': 0xe40f, // movie
    'Transport': 0xe1d7, // directions_car
    'Dom i ogród': 0xe318, // home
    'Edukacja': 0xe559, // school
    'Restauracje': 0xe56c, // restaurant
    'Sport': 0xe2e3, // fitness_center
    'Inne': 0xe3b0, // label
  };
}
