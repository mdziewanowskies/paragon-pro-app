class ReceiptModel {
  final String id;
  final String userId;
  final String imageUrl;
  final double? amount;
  final String? merchantName;
  final String? merchantAddress;
  final String? receiptNumber;
  final DateTime? purchaseDate;
  final String? category;
  final List<String>? categories;
  final List<dynamic>? items;
  final String? notes;
  final bool aiProcessed;
  final double? aiConfidence;
  final bool hasWarranty;
  // KSeF fields
  final bool isKsefInvoice;
  final String? ksefNumber;
  final String? ksefQrCode;
  final String? sellerNip;
  final String? buyerNip;
  final double? netAmount;
  final double? vatAmount;
  final double? grossAmount;
  final String? vatRate;
  // Family sharing
  final bool sharedWithFamily;
  final String? familyId;
  final DateTime uploadedAt;

  ReceiptModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.amount,
    this.merchantName,
    this.merchantAddress,
    this.receiptNumber,
    this.purchaseDate,
    this.category,
    this.categories,
    this.items,
    this.notes,
    this.aiProcessed = false,
    this.aiConfidence,
    this.hasWarranty = false,
    this.isKsefInvoice = false,
    this.ksefNumber,
    this.ksefQrCode,
    this.sellerNip,
    this.buyerNip,
    this.netAmount,
    this.vatAmount,
    this.grossAmount,
    this.vatRate,
    this.sharedWithFamily = false,
    this.familyId,
    required this.uploadedAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      imageUrl: json['image_url'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      merchantName: json['merchant_name'] as String?,
      merchantAddress: json['merchant_address'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      purchaseDate: json['purchase_date'] != null
          ? DateTime.parse(json['purchase_date'] as String)
          : null,
      category: json['category'] as String?,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      items: json['items'] as List<dynamic>?,
      notes: json['notes'] as String?,
      aiProcessed: json['ai_processed'] as bool? ?? false,
      aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
      hasWarranty: json['has_warranty'] as bool? ?? false,
      isKsefInvoice: json['is_ksef_invoice'] as bool? ?? false,
      ksefNumber: json['ksef_number'] as String?,
      ksefQrCode: json['ksef_qr_code'] as String?,
      sellerNip: json['seller_nip'] as String?,
      buyerNip: json['buyer_nip'] as String?,
      netAmount: (json['net_amount'] as num?)?.toDouble(),
      vatAmount: (json['vat_amount'] as num?)?.toDouble(),
      grossAmount: (json['gross_amount'] as num?)?.toDouble(),
      vatRate: json['vat_rate'] as String?,
      sharedWithFamily: json['shared_with_family'] as bool? ?? false,
      familyId: json['family_id'] as String?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'image_url': imageUrl,
        'amount': amount,
        'merchant_name': merchantName,
        'merchant_address': merchantAddress,
        'receipt_number': receiptNumber,
        'purchase_date': purchaseDate?.toIso8601String().split('T').first,
        'category': category,
        'categories': categories,
        'items': items,
        'notes': notes,
        'ai_processed': aiProcessed,
        'ai_confidence': aiConfidence,
        'has_warranty': hasWarranty,
        'is_ksef_invoice': isKsefInvoice,
        'ksef_number': ksefNumber,
        'seller_nip': sellerNip,
        'buyer_nip': buyerNip,
        'net_amount': netAmount,
        'vat_amount': vatAmount,
        'gross_amount': grossAmount,
        'vat_rate': vatRate,
        'shared_with_family': sharedWithFamily,
        'family_id': familyId,
      };

  bool get hasValidImageUrl =>
      imageUrl.isNotEmpty &&
      (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

  bool get isKsefWithoutImage => isKsefInvoice && !hasValidImageUrl;

  ReceiptModel copyWith({
    double? amount,
    String? merchantName,
    String? merchantAddress,
    String? receiptNumber,
    DateTime? purchaseDate,
    String? category,
    List<String>? categories,
    String? notes,
    bool? hasWarranty,
    bool? sharedWithFamily,
  }) {
    return ReceiptModel(
      id: id,
      userId: userId,
      imageUrl: imageUrl,
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      merchantAddress: merchantAddress ?? this.merchantAddress,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      items: items,
      notes: notes ?? this.notes,
      aiProcessed: aiProcessed,
      aiConfidence: aiConfidence,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      isKsefInvoice: isKsefInvoice,
      ksefNumber: ksefNumber,
      ksefQrCode: ksefQrCode,
      sellerNip: sellerNip,
      buyerNip: buyerNip,
      netAmount: netAmount,
      vatAmount: vatAmount,
      grossAmount: grossAmount,
      vatRate: vatRate,
      sharedWithFamily: sharedWithFamily ?? this.sharedWithFamily,
      familyId: familyId,
      uploadedAt: uploadedAt,
    );
  }
}
