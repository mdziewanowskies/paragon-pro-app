class ProfileModel {
  final String id;
  final String userId;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? street;
  final String? houseNumber;
  final String? apartmentNumber;
  final String? postalCode;
  final String? city;
  final String? bankAccountNumber;
  final String? signatureDataUrl;
  final String? ksefToken;
  final String? ksefNip;
  final DateTime? ksefTokenAddedAt;
  final bool profileCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProfileModel({
    required this.id,
    required this.userId,
    this.username,
    this.firstName,
    this.lastName,
    this.street,
    this.houseNumber,
    this.apartmentNumber,
    this.postalCode,
    this.city,
    this.bankAccountNumber,
    this.signatureDataUrl,
    this.ksefToken,
    this.ksefNip,
    this.ksefTokenAddedAt,
    this.profileCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      street: json['street'] as String?,
      houseNumber: json['house_number'] as String?,
      apartmentNumber: json['apartment_number'] as String?,
      postalCode: json['postal_code'] as String?,
      city: json['city'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      signatureDataUrl: json['signature_data_url'] as String?,
      ksefToken: json['ksef_token'] as String?,
      ksefNip: json['ksef_nip'] as String?,
      ksefTokenAddedAt: json['ksef_token_added_at'] != null
          ? DateTime.parse(json['ksef_token_added_at'] as String)
          : null,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'street': street,
        'house_number': houseNumber,
        'apartment_number': apartmentNumber,
        'postal_code': postalCode,
        'city': city,
        'bank_account_number': bankAccountNumber,
        'signature_data_url': signatureDataUrl,
        'ksef_token': ksefToken,
        'ksef_nip': ksefNip,
        'profile_completed': profileCompleted,
      };

  String get fullName => [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');

  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) {
      var addr = street!;
      if (houseNumber != null && houseNumber!.isNotEmpty) {
        addr += ' $houseNumber';
      }
      if (apartmentNumber != null && apartmentNumber!.isNotEmpty) {
        addr += '/$apartmentNumber';
      }
      parts.add(addr);
    }
    if (postalCode != null && city != null) {
      parts.add('$postalCode $city');
    }
    return parts.join(', ');
  }

  ProfileModel copyWith({
    String? username,
    String? firstName,
    String? lastName,
    String? street,
    String? houseNumber,
    String? apartmentNumber,
    String? postalCode,
    String? city,
    String? bankAccountNumber,
    String? signatureDataUrl,
    String? ksefToken,
    String? ksefNip,
    bool? profileCompleted,
  }) {
    return ProfileModel(
      id: id,
      userId: userId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      street: street ?? this.street,
      houseNumber: houseNumber ?? this.houseNumber,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      signatureDataUrl: signatureDataUrl ?? this.signatureDataUrl,
      ksefToken: ksefToken ?? this.ksefToken,
      ksefNip: ksefNip ?? this.ksefNip,
      ksefTokenAddedAt: ksefTokenAddedAt,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
