import '../../receipts/data/models/receipt_model.dart';
import '../../warranties/presentation/screens/warranty_list_screen.dart';

/// Curated demo content widoczny TYLKO podczas aktywnego tutorialu
/// (CoachmarkController.active == true). Pozwala pokazać UI z realistycz-
/// nymi danymi nawet jeśli user ma puste konto / brak premium.
///
/// Wszystkie ID prefixed 'demo-' żeby nigdy nie kolidowały z prawdziwymi
/// rekordami w bazie i żeby ewentualne tap'y mogły być wczesnie zignorowane.
class TutorialDemoData {
  static const _demoUser = 'demo-user';

  static DateTime _daysAgo(int d) =>
      DateTime.now().subtract(Duration(days: d));
  static DateTime _daysAhead(int d) =>
      DateTime.now().add(Duration(days: d));

  /// 6 paragonów z różnych kategorii i sklepów — pokazuje filtry,
  /// statusy i ikonki kategorii.
  static List<ReceiptModel> receipts() => [
        ReceiptModel(
          id: 'demo-r-1',
          userId: _demoUser,
          imageUrl: '',
          amount: 234.50,
          merchantName: 'Biedronka',
          purchaseDate: _daysAgo(1),
          category: 'Spożywcze',
          aiProcessed: true,
          aiConfidence: 0.96,
          uploadedAt: _daysAgo(1),
        ),
        ReceiptModel(
          id: 'demo-r-2',
          userId: _demoUser,
          imageUrl: '',
          amount: 4299.00,
          merchantName: 'Media Markt',
          purchaseDate: _daysAgo(8),
          category: 'Elektronika',
          aiProcessed: true,
          aiConfidence: 0.99,
          hasWarranty: true,
          notes: 'Laptop Lenovo ThinkPad X1 Carbon Gen 12',
          uploadedAt: _daysAgo(8),
        ),
        ReceiptModel(
          id: 'demo-r-3',
          userId: _demoUser,
          imageUrl: '',
          amount: 156.80,
          merchantName: 'Rossmann',
          purchaseDate: _daysAgo(3),
          category: 'Drogeria',
          aiProcessed: true,
          aiConfidence: 0.92,
          uploadedAt: _daysAgo(3),
        ),
        ReceiptModel(
          id: 'demo-r-4',
          userId: _demoUser,
          imageUrl: '',
          amount: 89.99,
          merchantName: 'Empik',
          purchaseDate: _daysAgo(5),
          category: 'Książki',
          aiProcessed: true,
          uploadedAt: _daysAgo(5),
        ),
        ReceiptModel(
          id: 'demo-r-5',
          userId: _demoUser,
          imageUrl: '',
          amount: 312.00,
          merchantName: 'Decathlon',
          purchaseDate: _daysAgo(14),
          category: 'Sport',
          aiProcessed: true,
          hasWarranty: true,
          notes: 'Buty do biegania ASICS Gel-Kayano',
          uploadedAt: _daysAgo(14),
        ),
        ReceiptModel(
          id: 'demo-r-6',
          userId: _demoUser,
          imageUrl: '',
          amount: 67.20,
          merchantName: 'Żabka',
          purchaseDate: _daysAgo(2),
          category: 'Spożywcze',
          aiProcessed: true,
          uploadedAt: _daysAgo(2),
        ),
      ];

  /// 3 faktury KSeF — pokazują panel KSeF z prawdziwą strukturą
  /// (NIP, kwoty netto/VAT/brutto, numer KSeF).
  static List<ReceiptModel> ksefInvoices() => [
        ReceiptModel(
          id: 'demo-k-1',
          userId: _demoUser,
          imageUrl: '',
          merchantName: 'Allegro sp. z o.o.',
          purchaseDate: _daysAgo(6),
          isKsefInvoice: true,
          ksefNumber: '5260250995-20260508-A1B2C3',
          sellerNip: '5260250995',
          buyerNip: '7010123456',
          netAmount: 1219.51,
          vatAmount: 280.49,
          grossAmount: 1500.00,
          amount: 1500.00,
          vatRate: '23',
          uploadedAt: _daysAgo(6),
        ),
        ReceiptModel(
          id: 'demo-k-2',
          userId: _demoUser,
          imageUrl: '',
          merchantName: 'Orange Polska S.A.',
          purchaseDate: _daysAgo(12),
          isKsefInvoice: true,
          ksefNumber: '5261029318-20260502-D4E5F6',
          sellerNip: '5261029318',
          buyerNip: '7010123456',
          netAmount: 81.30,
          vatAmount: 18.70,
          grossAmount: 100.00,
          amount: 100.00,
          vatRate: '23',
          uploadedAt: _daysAgo(12),
        ),
        ReceiptModel(
          id: 'demo-k-3',
          userId: _demoUser,
          imageUrl: '',
          merchantName: 'PKN Orlen S.A.',
          purchaseDate: _daysAgo(20),
          isKsefInvoice: true,
          ksefNumber: '7740001454-20260424-G7H8I9',
          sellerNip: '7740001454',
          buyerNip: '7010123456',
          netAmount: 243.90,
          vatAmount: 56.10,
          grossAmount: 300.00,
          amount: 300.00,
          vatRate: '23',
          uploadedAt: _daysAgo(20),
        ),
      ];

  /// 3 gwarancje — jedna aktywna długa, jedna wkrótce wygasająca,
  /// jedna już wygasła (archiwum). Pokrywa 3 zakładki w
  /// WarrantyListScreen.
  static List<WarrantyModel> warranties() => [
        WarrantyModel(
          id: 'demo-w-1',
          receiptId: 'demo-r-2',
          userId: _demoUser,
          warrantyMonths: 24,
          startDate: _daysAgo(8),
          endDate: _daysAhead(722),
          status: 'active',
          notes: 'Laptop Lenovo ThinkPad X1 Carbon Gen 12',
          merchantName: 'Media Markt',
          amount: 4299.00,
        ),
        WarrantyModel(
          id: 'demo-w-2',
          receiptId: 'demo-r-5',
          userId: _demoUser,
          warrantyMonths: 12,
          startDate: _daysAgo(340),
          endDate: _daysAhead(25),
          status: 'active',
          notes: 'Buty do biegania ASICS Gel-Kayano',
          merchantName: 'Decathlon',
          amount: 312.00,
        ),
        WarrantyModel(
          id: 'demo-w-3',
          receiptId: null,
          userId: _demoUser,
          warrantyMonths: 12,
          startDate: _daysAgo(420),
          endDate: _daysAgo(55),
          status: 'archived',
          notes: 'Słuchawki Sony WH-1000XM5',
          merchantName: 'Media Expert',
          amount: 1599.00,
        ),
      ];

  /// Statystyki dashboard'u — wartości wyglądają realistycznie,
  /// żeby progress / level / streak były wiarygodne.
  static Map<String, dynamic> dashboardStats() => {
        'totalExpenses': 5159.49,
        'avgExpenses': 859.91,
        'receiptCount': 6,
        'receiptsThisWeek': 3,
        'activeWarranties': 2,
        'warrantiesExpiringSoon': 1,
        'topCategory': 'Elektronika',
        'topCategoryShare': 0.83,
        'topCategoryAmount': 4299.00,
        'topMerchant': 'Media Markt',
      };

  static bool isDemo(String? id) => id != null && id.startsWith('demo-');
}
