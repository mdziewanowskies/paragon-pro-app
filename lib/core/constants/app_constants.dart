class AppConstants {
  AppConstants._();

  static const String appName = 'ParagonPro';
  static const String appTagline = 'Twój inteligentny asystent finansowy';

  // Supabase - replace with actual values or use env
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hxzimocyiblbyoxjxmhj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4emltb2N5aWJsYnlveGp4bWhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwNjU2MTksImV4cCI6MjA3NzY0MTYxOX0.4mBr-eLUfhGjeDGfzReS7rXRaFouyH8wrJgSLE1ogso',
  );

  // Google OAuth client IDs (from Google Cloud Console → Credentials)
  // Web client ID is also the one configured in Supabase Auth → Providers → Google.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  // Storage
  static const String receiptsBucket = 'receipts';

  // Subscription tiers
  static const String tierFree = 'free';
  static const String tierPremium = 'premium';

  // Limits
  static const int freeMonthlyReceipts = 5;
  static const int premiumMonthlyReceipts = -1; // unlimited

  // Pricing
  static const double premiumMonthlyPrice = 19.99;
  static const double premiumYearlyPrice = 179.99;

  // Gamification
  static const int pointsPerLevel = 100;

  // Date format
  static const String dateFormatPl = 'dd.MM.yyyy';
  static const String currencySymbol = 'zł';
  static const String currencyCode = 'PLN';

  // Categories (unified with web version)
  static const List<String> receiptCategories = [
    'Żywność',
    'Odzież',
    'Elektronika',
    'Sport',
    'Dom i Ogród',
    'Zdrowie',
    'Rozrywka',
    'Transport',
    'Edukacja',
    'Restauracje',
    'Inne',
  ];

  // Category icons (Material icon names)
  static const Map<String, int> categoryIcons = {
    'Żywność': 0xe57a, // shopping_cart
    'Odzież': 0xf04b4, // checkroom
    'Elektronika': 0xe1e3, // devices
    'Sport': 0xe2e3, // fitness_center
    'Dom i Ogród': 0xe318, // home
    'Zdrowie': 0xe4c1, // local_hospital
    'Rozrywka': 0xe40f, // movie
    'Transport': 0xe1d7, // directions_car
    'Edukacja': 0xe559, // school
    'Restauracje': 0xe56c, // restaurant
    'Inne': 0xe3b0, // label
  };
}
