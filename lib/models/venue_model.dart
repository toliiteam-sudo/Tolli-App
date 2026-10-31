import 'package:cloud_firestore/cloud_firestore.dart';

class CourtModel {
  final String id;
  final String name;
  final String sportId;
  final int capacity;
  final String surfaceType;
  final int hourlyRatePaise;
  final bool isActive;
  final int minBookingMinutes;

  const CourtModel({
    required this.id,
    required this.name,
    required this.sportId,
    required this.capacity,
    required this.surfaceType,
    required this.hourlyRatePaise,
    this.isActive = true,
    this.minBookingMinutes = 30,
  });

  int calculatePricePaise(int durationMinutes) {
    if (durationMinutes <= 0 || hourlyRatePaise <= 0) return 0;
    return ((hourlyRatePaise * durationMinutes) / 60.0).round();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sportId': sportId,
      'capacity': capacity,
      'surfaceType': surfaceType,
      'hourlyRatePaise': hourlyRatePaise,
      'isActive': isActive,
      'minBookingMinutes': minBookingMinutes,
    };
  }

  factory CourtModel.fromMap(Map<String, dynamic> map) {
    return CourtModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      sportId: map['sportId'] ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 10,
      surfaceType: map['surfaceType'] ?? 'Turf',
      hourlyRatePaise: (map['hourlyRatePaise'] as num?)?.toInt() ?? 60000,
      isActive: map['isActive'] ?? true,
      minBookingMinutes: (map['minBookingMinutes'] as num?)?.toInt() ?? 30,
    );
  }
}

class VenueSlotModel {
  final String id;
  final String courtId;
  final String venueId;
  final String date; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final int startTimestampMs;
  final int endTimestampMs;
  final int durationMinutes;
  final int pricePaise;
  final String status; // 'AVAILABLE', 'HELD', 'BOOKED'
  final String? heldByUserId;
  final int? holdExpiresAtMs;

  const VenueSlotModel({
    required this.id,
    required this.courtId,
    required this.venueId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startTimestampMs,
    required this.endTimestampMs,
    required this.durationMinutes,
    required this.pricePaise,
    this.status = 'AVAILABLE',
    this.heldByUserId,
    this.holdExpiresAtMs,
  });

  bool get isAvailable {
    if (status == 'BOOKED') return false;
    if (status == 'HELD' && holdExpiresAtMs != null) {
      if (DateTime.now().millisecondsSinceEpoch < holdExpiresAtMs!) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courtId': courtId,
      'venueId': venueId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'startTimestampMs': startTimestampMs,
      'endTimestampMs': endTimestampMs,
      'durationMinutes': durationMinutes,
      'pricePaise': pricePaise,
      'status': status,
      'heldByUserId': heldByUserId,
      'holdExpiresAtMs': holdExpiresAtMs,
    };
  }

  factory VenueSlotModel.fromMap(Map<String, dynamic> map) {
    return VenueSlotModel(
      id: map['id'] ?? '',
      courtId: map['courtId'] ?? '',
      venueId: map['venueId'] ?? '',
      date: map['date'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      startTimestampMs: (map['startTimestampMs'] as num?)?.toInt() ?? 0,
      endTimestampMs: (map['endTimestampMs'] as num?)?.toInt() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      pricePaise: (map['pricePaise'] as num?)?.toInt() ?? 60000,
      status: map['status'] ?? 'AVAILABLE',
      heldByUserId: map['heldByUserId'],
      holdExpiresAtMs: (map['holdExpiresAtMs'] as num?)?.toInt(),
    );
  }
}

class VenueModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewsCount;
  final List<String> supportedSports;
  final List<String> imageAssets;
  final List<String> facilities;
  final String operatingHours;
  final List<String> rules;
  final String cancellationPolicy;
  final int startingPricePaise;
  final List<CourtModel> courts;

  const VenueModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewsCount,
    required this.supportedSports,
    required this.imageAssets,
    required this.facilities,
    required this.operatingHours,
    required this.rules,
    required this.cancellationPolicy,
    required this.startingPricePaise,
    required this.courts,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'supportedSports': supportedSports,
      'imageAssets': imageAssets,
      'facilities': facilities,
      'operatingHours': operatingHours,
      'rules': rules,
      'cancellationPolicy': cancellationPolicy,
      'startingPricePaise': startingPricePaise,
      'courts': courts.map((c) => c.toMap()).toList(),
    };
  }

  factory VenueModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return VenueModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? 'Bhavnagar',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 21.7645,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 72.1519,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewsCount: (map['reviewsCount'] as num?)?.toInt() ?? 50,
      supportedSports: (map['supportedSports'] as List?)?.cast<String>() ?? ['Box Cricket'],
      imageAssets: (map['imageAssets'] as List?)?.cast<String>() ?? [],
      facilities: (map['facilities'] as List?)?.cast<String>() ?? [],
      operatingHours: map['operatingHours'] ?? '06:00 AM - 11:00 PM',
      rules: (map['rules'] as List?)?.cast<String>() ?? [],
      cancellationPolicy: map['cancellationPolicy'] ?? 'Full refund if cancelled 24h prior. 50% refund between 12-24h.',
      startingPricePaise: (map['startingPricePaise'] as num?)?.toInt() ?? 60000,
      courts: (map['courts'] as List?)
              ?.map((c) => CourtModel.fromMap(Map<String, dynamic>.from(c)))
              .toList() ??
          [],
    );
  }

  factory VenueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VenueModel.fromMap(data, doc.id);
  }
}
