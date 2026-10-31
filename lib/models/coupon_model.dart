class CouponModel {
  final String code;
  final String title;
  final String description;
  final String discountType; // 'FIXED_PAISE' or 'PERCENTAGE'
  final int discountValue;
  final int minBookingPaise;
  final int maxDiscountPaise;
  final bool isEligible;
  final int discountPaise;
  final int discountRupees;
  final String? ineligibilityReason;

  const CouponModel({
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minBookingPaise,
    required this.maxDiscountPaise,
    this.isEligible = true,
    this.discountPaise = 0,
    this.discountRupees = 0,
    this.ineligibilityReason,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      discountType: json['discountType'] as String? ?? 'FIXED_PAISE',
      discountValue: (json['discountValue'] as num?)?.toInt() ?? 0,
      minBookingPaise: (json['minBookingPaise'] as num?)?.toInt() ?? 0,
      maxDiscountPaise: (json['maxDiscountPaise'] as num?)?.toInt() ?? 0,
      isEligible: json['isEligible'] as bool? ?? true,
      discountPaise: (json['discountPaise'] as num?)?.toInt() ?? 0,
      discountRupees: (json['discountRupees'] as num?)?.toInt() ?? 0,
      ineligibilityReason: json['ineligibilityReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minBookingPaise': minBookingPaise,
      'maxDiscountPaise': maxDiscountPaise,
      'isEligible': isEligible,
      'discountPaise': discountPaise,
      'discountRupees': discountRupees,
      'ineligibilityReason': ineligibilityReason,
    };
  }

  String get discountBadgeText {
    if (discountType == 'PERCENTAGE') {
      return '$discountValue% OFF';
    }
    final rupees = (discountValue / 100).round();
    return '₹$rupees OFF';
  }
}
