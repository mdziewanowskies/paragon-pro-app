class KsefSessionToken {
  final String sessionToken;
  final DateTime expiry;
  final String? referenceNumber;

  KsefSessionToken({
    required this.sessionToken,
    required this.expiry,
    this.referenceNumber,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);

  factory KsefSessionToken.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'] as String?;
    return KsefSessionToken(
      sessionToken: json['sessionToken']?['token'] as String? ??
          json['token'] as String? ??
          '',
      expiry: timestamp != null
          ? DateTime.parse(timestamp).add(const Duration(minutes: 25))
          : DateTime.now().add(const Duration(minutes: 25)),
      referenceNumber: json['referenceNumber'] as String?,
    );
  }
}

class KsefInvoice {
  final String ksefReferenceNumber;
  final String invoiceNumber;
  final DateTime invoicingDate;
  final String subjectByNip;
  final String? subjectByName;
  final String? subjectToNip;
  final String? subjectToName;
  final double netValue;
  final double vatValue;
  final double grossValue;
  final String? vatRate;
  final List<KsefInvoiceItem> items;
  final String? invoiceXml;

  KsefInvoice({
    required this.ksefReferenceNumber,
    required this.invoiceNumber,
    required this.invoicingDate,
    required this.subjectByNip,
    this.subjectByName,
    this.subjectToNip,
    this.subjectToName,
    required this.netValue,
    required this.vatValue,
    required this.grossValue,
    this.vatRate,
    this.items = const [],
    this.invoiceXml,
  });

  factory KsefInvoice.fromQueryResponse(Map<String, dynamic> json) {
    final headers =
        json['invoiceHeader'] as Map<String, dynamic>? ?? json;
    final subjectBy =
        headers['subjectBy'] as Map<String, dynamic>? ?? {};
    final subjectTo =
        headers['subjectTo'] as Map<String, dynamic>? ?? {};
    final subjectByIssuedByIdentifier =
        subjectBy['issuedByIdentifier'] as Map<String, dynamic>? ?? {};
    final subjectToIssuedToIdentifier =
        subjectTo['issuedToIdentifier'] as Map<String, dynamic>? ?? {};

    return KsefInvoice(
      ksefReferenceNumber:
          json['ksefReferenceNumber'] as String? ?? '',
      invoiceNumber:
          headers['invoiceReferenceNumber'] as String? ?? '',
      invoicingDate: DateTime.parse(
          headers['invoicingDate'] as String? ??
              DateTime.now().toIso8601String()),
      subjectByNip:
          subjectByIssuedByIdentifier['identifier'] as String? ?? '',
      subjectByName: headers['subjectByName'] as String? ??
          subjectBy['issuedByName']?['fullName'] as String?,
      subjectToNip:
          subjectToIssuedToIdentifier['identifier'] as String? ?? '',
      subjectToName: headers['subjectToName'] as String? ??
          subjectTo['issuedToName']?['fullName'] as String?,
      netValue: _toDouble(headers['net']),
      vatValue: _toDouble(headers['vat']),
      grossValue: _toDouble(headers['gross']),
      vatRate: headers['vatRate'] as String?,
    );
  }

  factory KsefInvoice.fromSyncResponse(Map<String, dynamic> json) {
    return KsefInvoice(
      ksefReferenceNumber:
          json['ksefReferenceNumber'] as String? ?? '',
      invoiceNumber:
          json['invoiceReferenceNumber'] as String? ?? '',
      invoicingDate: DateTime.parse(
          json['invoicingDate'] as String? ??
              DateTime.now().toIso8601String()),
      subjectByNip: json['subjectBy']?['issuedByIdentifier']
              ?['identifier'] as String? ??
          '',
      subjectByName:
          json['subjectBy']?['issuedByName']?['fullName'] as String?,
      subjectToNip: json['subjectTo']?['issuedToIdentifier']
              ?['identifier'] as String? ??
          '',
      subjectToName:
          json['subjectTo']?['issuedToName']?['fullName'] as String?,
      netValue: _toDouble(json['net']),
      vatValue: _toDouble(json['vat']),
      grossValue: _toDouble(json['gross']),
    );
  }

  Map<String, dynamic> toReceiptJson(String userId) => {
        'user_id': userId,
        'image_url': '',
        'merchant_name': subjectByName ?? subjectByNip,
        'merchant_address': null,
        'amount': grossValue,
        'purchase_date': invoicingDate.toIso8601String().split('T').first,
        'category': 'Faktury',
        'is_ksef_invoice': true,
        'ksef_number': ksefReferenceNumber,
        'seller_nip': subjectByNip,
        'buyer_nip': subjectToNip,
        'net_amount': netValue,
        'vat_amount': vatValue,
        'gross_amount': grossValue,
        'vat_rate': vatRate,
        'receipt_number': invoiceNumber,
        'ai_processed': false,
      };

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }
}

class KsefInvoiceItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double netValue;
  final double vatValue;
  final double grossValue;
  final String vatRate;

  KsefInvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.netValue,
    required this.vatValue,
    required this.grossValue,
    required this.vatRate,
  });
}

class KsefQueryCriteria {
  final String subjectType; // 'subject1' (seller) or 'subject2' (buyer)
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? invoiceNumber;
  final String? ksefReferenceNumber;
  final String? subjectNip;

  KsefQueryCriteria({
    this.subjectType = 'subject1',
    required this.dateFrom,
    required this.dateTo,
    this.invoiceNumber,
    this.ksefReferenceNumber,
    this.subjectNip,
  });

  Map<String, dynamic> toQueryBody() {
    final criteria = <String, dynamic>{
      'subjectType': subjectType,
      'type': 'incremental',
      'acquisitionTimestampThresholdFrom':
          dateFrom.toUtc().toIso8601String(),
      'acquisitionTimestampThresholdTo':
          dateTo.toUtc().toIso8601String(),
    };

    if (invoiceNumber != null && invoiceNumber!.isNotEmpty) {
      criteria['invoiceNumber'] = invoiceNumber;
    }
    if (ksefReferenceNumber != null && ksefReferenceNumber!.isNotEmpty) {
      criteria['ksefReferenceNumber'] = ksefReferenceNumber;
    }

    return {
      'queryCriteria': {
        'subjectType': subjectType,
        'type': 'incremental',
        'acquisitionTimestampThresholdFrom':
            dateFrom.toUtc().toIso8601String(),
        'acquisitionTimestampThresholdTo':
            dateTo.toUtc().toIso8601String(),
      },
    };
  }
}

enum KsefEnvironment {
  production,
  test,
  demo,
}

extension KsefEnvironmentExtension on KsefEnvironment {
  String get baseUrl {
    switch (this) {
      case KsefEnvironment.production:
        return 'https://ksef.mf.gov.pl/api';
      case KsefEnvironment.test:
        return 'https://ksef-test.mf.gov.pl/api';
      case KsefEnvironment.demo:
        return 'https://ksef-demo.mf.gov.pl/api';
    }
  }

  String get label {
    switch (this) {
      case KsefEnvironment.production:
        return 'Produkcja';
      case KsefEnvironment.test:
        return 'Test';
      case KsefEnvironment.demo:
        return 'Demo';
    }
  }
}
