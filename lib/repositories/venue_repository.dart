import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_assets.dart';
import '../models/venue_model.dart';
import '../services/booking_backend_service.dart';
import '../utils/booking_time_utils.dart';

class VenueRepository {
  static final VenueRepository _instance = VenueRepository._internal();
  factory VenueRepository() => _instance;
  VenueRepository._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  /// Default Seed Venues (Real venue structures for sports discovery)
  static final List<VenueModel> defaultVenues = [
    VenueModel(
      id: 'venue_sidsar_arena',
      name: 'Sports Arena Sidsar',
      address: 'Sidsar Road, Near Engineering College, Bhavnagar',
      city: 'Bhavnagar',
      latitude: 21.7235,
      longitude: 72.1319,
      rating: 4.8,
      reviewsCount: 142,
      supportedSports: ['Box Cricket', 'Pickleball', 'Badminton', 'Football'],
      imageAssets: [AppAssets.pickleballCourtsPng, AppAssets.ahmedabadPng],
      facilities: ['Floodlights', 'Free Parking', 'Changing Rooms', 'Drinking Water', 'Equipment Rental'],
      operatingHours: '06:00 AM - 11:00 PM',
      rules: ['Non-marking shoes compulsory for Badminton.', 'Report 10 mins before slot.'],
      cancellationPolicy: 'Full refund if cancelled 24 hours in advance. 50% refund between 12-24h.',
      startingPricePaise: 60000, // ₹600
      courts: const [
        CourtModel(
          id: 'court_sidsar_cricket_1',
          name: 'Box Cricket Arena 1',
          sportId: 'Box Cricket',
          capacity: 14,
          surfaceType: 'Synthetic Turf',
          hourlyRatePaise: 80000,
        ),
        CourtModel(
          id: 'court_sidsar_pickleball_1',
          name: 'Pro Pickleball Court A',
          sportId: 'Pickleball',
          capacity: 4,
          surfaceType: 'Acrylic Hard Court',
          hourlyRatePaise: 60000,
        ),
      ],
    ),
    VenueModel(
      id: 'venue_bhavnagar_club',
      name: 'Bhavnagar Sports Club',
      address: 'Jewel Circle, Waghawadi Road, Bhavnagar',
      city: 'Bhavnagar',
      latitude: 21.7580,
      longitude: 72.1465,
      rating: 4.6,
      reviewsCount: 88,
      supportedSports: ['Badminton', 'Tennis', 'Pickleball'],
      imageAssets: [AppAssets.aanganBadmintonPng, AppAssets.pickleballCourtsPng],
      facilities: ['Indoor AC', 'Shower Rooms', 'Café', 'Pro Shop', 'Valet Parking'],
      operatingHours: '05:30 AM - 10:30 PM',
      rules: ['Standard sports attire required.', 'No food on court floor.'],
      cancellationPolicy: 'Full refund up to 24h before start time.',
      startingPricePaise: 50000, // ₹500
      courts: const [
        CourtModel(
          id: 'court_bsc_badminton_1',
          name: 'Indoor Synthetic Court 1',
          sportId: 'Badminton',
          capacity: 4,
          surfaceType: 'Wooden Cushion + Mat',
          hourlyRatePaise: 50000,
        ),
        CourtModel(
          id: 'court_bsc_tennis_1',
          name: 'Championship Tennis Court',
          sportId: 'Tennis',
          capacity: 4,
          surfaceType: 'Clay',
          hourlyRatePaise: 90000,
        ),
      ],
    ),
    VenueModel(
      id: 'venue_victoria_turf',
      name: 'Victoria Park Turf',
      address: 'Near Victoria Park Gate, Bhavnagar',
      city: 'Bhavnagar',
      latitude: 21.7450,
      longitude: 72.1380,
      rating: 4.5,
      reviewsCount: 65,
      supportedSports: ['Football', 'Box Cricket'],
      imageAssets: [AppAssets.ahmedabadPng, AppAssets.pickleballCourtsPng],
      facilities: ['Floodlights', 'Parking', 'First Aid', 'Spectator Seating'],
      operatingHours: '06:00 AM - 11:30 PM',
      rules: ['Football studs permitted (molded only).'],
      cancellationPolicy: 'Full refund 24h prior. Non-refundable within 6 hours.',
      startingPricePaise: 100000, // ₹1000
      courts: const [
        CourtModel(
          id: 'court_vpt_football_1',
          name: '5v5 FIFA Turf',
          sportId: 'Football',
          capacity: 10,
          surfaceType: 'FIFA Grade 50mm Grass',
          hourlyRatePaise: 120000,
        ),
        CourtModel(
          id: 'court_vpt_cricket_1',
          name: 'Night Box Cricket Turf',
          sportId: 'Box Cricket',
          capacity: 12,
          surfaceType: 'Green Turf',
          hourlyRatePaise: 100000,
        ),
      ],
    ),
    VenueModel(
      id: 'venue_bodakdev_academy',
      name: 'Bodakdev Sports Academy',
      address: 'Sindhu Bhavan Road, Bodakdev, Ahmedabad',
      city: 'Ahmedabad',
      latitude: 23.0395,
      longitude: 72.5066,
      rating: 4.9,
      reviewsCount: 210,
      supportedSports: ['Pickleball', 'Badminton', 'Basketball'],
      imageAssets: [AppAssets.ahmedabadPng, AppAssets.aanganBadmintonPng],
      facilities: ['CCTV Security', 'Juice Bar', 'Coaching Available', 'AC Lounge'],
      operatingHours: '06:00 AM - 11:00 PM',
      rules: ['Clean non-marking footwear required.'],
      cancellationPolicy: 'Full refund if cancelled 24h prior.',
      startingPricePaise: 70000, // ₹700
      courts: const [
        CourtModel(
          id: 'court_bsa_pickleball_1',
          name: 'Center Court Pickleball',
          sportId: 'Pickleball',
          capacity: 4,
          surfaceType: 'Premium Acrylic',
          hourlyRatePaise: 70000,
        ),
      ],
    ),
  ];

  /// Helper to filter venues by selected sport and search query
  List<VenueModel> filterVenues(
    List<VenueModel> list, {
    String? selectedSport,
    String? searchQuery,
  }) {
    List<VenueModel> result = list;
    if (selectedSport != null && selectedSport.isNotEmpty && selectedSport != 'All') {
      result = result
          .where((v) => v.supportedSports.any(
              (s) => s.toLowerCase() == selectedSport.toLowerCase()))
          .toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result
          .where((v) =>
              v.name.toLowerCase().contains(q) ||
              v.address.toLowerCase().contains(q) ||
              v.city.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  /// Get all venues as a Future with timeout and error handling
  Future<List<VenueModel>> getVenues({
    String? selectedSport,
    String? searchQuery,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      if (_firestore == null) {
        return filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery);
      }
      final snapshot = await _firestore!
          .collection('venues')
          .get()
          .timeout(timeout);

      List<VenueModel> list = [];
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs.map((doc) => VenueModel.fromFirestore(doc)).toList();
      } else {
        list = defaultVenues;
      }
      return filterVenues(list, selectedSport: selectedSport, searchQuery: searchQuery);
    } catch (e) {
      debugPrint('[VenueRepository] Error fetching venues: $e');
      return filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery);
    }
  }

  /// Stream venues from Firestore or default list with timeout & graceful fallback
  Stream<List<VenueModel>> streamVenues({
    String? selectedSport,
    String? searchQuery,
    Duration timeout = const Duration(seconds: 3),
  }) {
    try {
      if (_firestore == null) {
        return Stream.value(
          filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery),
        );
      }
      return _firestore!
          .collection('venues')
          .snapshots()
          .map<List<VenueModel>>((snapshot) {
            List<VenueModel> list = [];
            if (snapshot.docs.isNotEmpty) {
              list = snapshot.docs.map((doc) => VenueModel.fromFirestore(doc)).toList();
            } else {
              list = defaultVenues;
            }
            return filterVenues(list, selectedSport: selectedSport, searchQuery: searchQuery);
          })
          .timeout(
            timeout,
            onTimeout: (sink) {
              sink.add(filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery));
            },
          )
          .handleError((err) {
            debugPrint('[VenueRepository] Error streaming venues: $err');
            return filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery);
          });
    } catch (e) {
      debugPrint('[VenueRepository] Firebase unavailable, using default venues: $e');
      return Stream.value(
        filterVenues(defaultVenues, selectedSport: selectedSport, searchQuery: searchQuery),
      );
    }
  }

  /// Get venue by ID
  Future<VenueModel?> getVenueById(String venueId) async {
    try {
      if (_firestore != null) {
        final doc = await _firestore!.collection('venues').doc(venueId).get();
        if (doc.exists) {
          return VenueModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      debugPrint('[VenueRepository] Error getting venue by ID: $e');
    }
    return defaultVenues.firstWhere((v) => v.id == venueId, orElse: () => defaultVenues.first);
  }

  /// Lookup venue operating hours by venueId
  String _resolveOperatingHours(String venueId, String? operatingHours) {
    if (operatingHours != null && operatingHours.trim().isNotEmpty) {
      return operatingHours;
    }
    for (final v in defaultVenues) {
      if (v.id == venueId) return v.operatingHours;
    }
    return '06:00 AM - 11:00 PM';
  }

  /// Generate granular 30-minute slots between venue open and close times
  List<VenueSlotModel> _generateGranularSlots({
    required String venueId,
    required CourtModel court,
    required String dateStr,
    required String operatingHours,
    required List<Map<String, dynamic>> activeBookings,
  }) {
    final opHours = BookingTimeUtils.parseOperatingHours(operatingHours);
    final openMinutes = opHours.openMinutes;
    final closeMinutes = opHours.closeMinutes;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final List<VenueSlotModel> list = [];

    for (int startMin = openMinutes; startMin < closeMinutes; startMin += 30) {
      final endMin = startMin + 30;
      final startStr = BookingTimeUtils.formatMinutesToTime(startMin);
      final endStr = BookingTimeUtils.formatMinutesToTime(endMin);
      final slotId = '${court.id}_${dateStr}_slot_$startMin';
      final slotStartMs = BookingTimeUtils.getTimestampMs(dateStr, startMin);
      final slotEndMs = BookingTimeUtils.getTimestampMs(dateStr, endMin);

      String status = 'AVAILABLE';
      String? heldBy;
      int? holdExpires;

      for (final b in activeBookings) {
        final bStatus = (b['bookingStatus'] as String?)?.toUpperCase();
        if (bStatus == 'CANCELLED' || bStatus == 'REFUNDED' || bStatus == 'REFUND_PENDING') {
          continue;
        }

        final bHoldExpires = (b['holdExpiresAt'] as num?)?.toInt();

        // Calculate start and end minutes of existing booking
        int bStartMin = -1;
        int bEndMin = -1;
        if (b['startTime'] != null && b['endTime'] != null) {
          bStartMin = BookingTimeUtils.parseTimeToMinutes(b['startTime'] as String);
          bEndMin = BookingTimeUtils.parseTimeToMinutes(b['endTime'] as String);
          if (bEndMin <= bStartMin && b['durationMinutes'] != null) {
            bEndMin = bStartMin + (b['durationMinutes'] as num).toInt();
          }
        } else if (b['startTimestamp'] != null && b['endTimestamp'] != null) {
          final bStartDt = DateTime.fromMillisecondsSinceEpoch((b['startTimestamp'] as num).toInt());
          final bEndDt = DateTime.fromMillisecondsSinceEpoch((b['endTimestamp'] as num).toInt());
          bStartMin = bStartDt.hour * 60 + bStartDt.minute;
          bEndMin = bEndDt.hour * 60 + bEndDt.minute;
        }

        final bSlotId = b['slotId'] as String?;
        final legacyMatch = (bSlotId != null && (bSlotId == slotId || b['startTime'] == startStr));
        final intervalOverlaps = (bStartMin >= 0 && bEndMin > bStartMin)
            ? BookingTimeUtils.doIntervalsOverlap(startMin, endMin, bStartMin, bEndMin)
            : legacyMatch;

        if (intervalOverlaps || legacyMatch) {
          if (bStatus == 'CONFIRMED' || bStatus == 'COMPLETED') {
            status = 'BOOKED';
            break;
          } else if (bStatus == 'HELD') {
            if (bHoldExpires != null && nowMs < bHoldExpires) {
              status = 'HELD';
              heldBy = b['userId'] as String?;
              holdExpires = bHoldExpires;
            }
          }
        }
      }

      list.add(
        VenueSlotModel(
          id: slotId,
          courtId: court.id,
          venueId: venueId,
          date: dateStr,
          startTime: startStr,
          endTime: endStr,
          startTimestampMs: slotStartMs,
          endTimestampMs: slotEndMs,
          durationMinutes: 30,
          pricePaise: BookingTimeUtils.calculateCourtPricePaise(
            hourlyRatePaise: court.hourlyRatePaise,
            durationMinutes: 30,
          ),
          status: status,
          heldByUserId: heldBy,
          holdExpiresAtMs: holdExpires,
        ),
      );
    }

    return list;
  }

  /// Get slots as a Future with timeout and error handling
  Future<List<VenueSlotModel>> getSlots({
    required String venueId,
    required CourtModel court,
    required String dateStr,
    String? operatingHours,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final effectiveOpHours = _resolveOperatingHours(venueId, operatingHours);

    final List<Map<String, dynamic>> activeBookings = [];

    // 1. Fetch from Firestore if available
    try {
      if (_firestore != null) {
        final snapshot = await _firestore!
            .collection('bookings')
            .where('venueId', isEqualTo: venueId)
            .where('courtId', isEqualTo: court.id)
            .where('bookingDate', isEqualTo: dateStr)
            .get()
            .timeout(timeout);

        for (final doc in snapshot.docs) {
          activeBookings.add(doc.data());
        }
      }
    } catch (e) {
      debugPrint('[VenueRepository] Error fetching Firestore bookings: $e');
    }

    // 2. Fetch authoritative backend bookings (in-memory / verified / holds)
    try {
      final backendBookings = await BookingBackendService().getSlotAvailability(
        venueId: venueId,
        courtId: court.id,
        date: dateStr,
      );
      for (final b in backendBookings) {
        final bId = b['bookingId'];
        if (bId != null && !activeBookings.any((item) => item['bookingId'] == bId)) {
          activeBookings.add(b);
        }
      }
    } catch (e) {
      debugPrint('[VenueRepository] Error fetching backend slot availability: $e');
    }

    return _generateGranularSlots(
      venueId: venueId,
      court: court,
      dateStr: dateStr,
      operatingHours: effectiveOpHours,
      activeBookings: activeBookings,
    );
  }

  /// Generate or stream time slots for a court and date (YYYY-MM-DD)
  Stream<List<VenueSlotModel>> streamSlots({
    required String venueId,
    required CourtModel court,
    required String dateStr,
    String? operatingHours,
    Duration timeout = const Duration(seconds: 3),
  }) {
    final effectiveOpHours = _resolveOperatingHours(venueId, operatingHours);

    List<VenueSlotModel> generateDefault() => _generateGranularSlots(
          venueId: venueId,
          court: court,
          dateStr: dateStr,
          operatingHours: effectiveOpHours,
          activeBookings: const [],
        );

    try {
      if (_firestore == null) {
        return Stream.fromFuture(
          getSlots(
            venueId: venueId,
            court: court,
            dateStr: dateStr,
            operatingHours: operatingHours,
          ),
        );
      }
      return _firestore!
          .collection('bookings')
          .where('venueId', isEqualTo: venueId)
          .where('courtId', isEqualTo: court.id)
          .where('bookingDate', isEqualTo: dateStr)
          .snapshots()
          .map((snapshot) {
            final activeBookings = snapshot.docs.map((doc) => doc.data()).toList();
            return _generateGranularSlots(
              venueId: venueId,
              court: court,
              dateStr: dateStr,
              operatingHours: effectiveOpHours,
              activeBookings: activeBookings,
            );
          })
          .timeout(
            timeout,
            onTimeout: (sink) {
              sink.add(generateDefault());
            },
          )
          .handleError((err) {
            debugPrint('[VenueRepository] Error streaming slots: $err');
            return generateDefault();
          });
    } catch (e) {
      return Stream.value(generateDefault());
    }
  }

  /// Evaluate the booking status of an interval across granular 30-min slots.
  /// Returns: 'AVAILABLE', 'HELD', 'BOOKED', 'EXCEEDS_CLOSING', or 'UNAVAILABLE'
  static String evaluateIntervalStatus({
    required List<VenueSlotModel> granularSlots,
    required String startTime,
    required int durationMinutes,
    required int closeMinutes,
  }) {
    final startMin = BookingTimeUtils.parseTimeToMinutes(startTime);
    final endMin = startMin + durationMinutes;

    if (endMin > closeMinutes) {
      return 'EXCEEDS_CLOSING';
    }

    bool hasHeld = false;
    bool foundAnyCoveredSlot = false;

    for (final slot in granularSlots) {
      final slotStart = BookingTimeUtils.parseTimeToMinutes(slot.startTime);
      final slotEnd = BookingTimeUtils.parseTimeToMinutes(slot.endTime);

      if (BookingTimeUtils.doIntervalsOverlap(startMin, endMin, slotStart, slotEnd)) {
        foundAnyCoveredSlot = true;
        if (slot.status == 'BOOKED') {
          return 'BOOKED';
        }
        if (slot.status == 'HELD' && !slot.isAvailable) {
          hasHeld = true;
        }
      }
    }

    if (!foundAnyCoveredSlot) {
      return 'UNAVAILABLE';
    }
    if (hasHeld) {
      return 'HELD';
    }
    return 'AVAILABLE';
  }

  /// Create a composite VenueSlotModel representing the full requested interval
  static VenueSlotModel createCompositeSlot({
    required CourtModel court,
    required String venueId,
    required String dateStr,
    required String startTime,
    required int durationMinutes,
  }) {
    final startMin = BookingTimeUtils.parseTimeToMinutes(startTime);
    final endMin = startMin + durationMinutes;
    final endTime = BookingTimeUtils.formatMinutesToTime(endMin);
    final startMs = BookingTimeUtils.getTimestampMs(dateStr, startMin);
    final endMs = BookingTimeUtils.getTimestampMs(dateStr, endMin);
    final pricePaise = court.calculatePricePaise(durationMinutes);
    final slotId = '${court.id}_${dateStr}_${startMin}_${durationMinutes}m';

    return VenueSlotModel(
      id: slotId,
      courtId: court.id,
      venueId: venueId,
      date: dateStr,
      startTime: startTime,
      endTime: endTime,
      startTimestampMs: startMs,
      endTimestampMs: endMs,
      durationMinutes: durationMinutes,
      pricePaise: pricePaise,
      status: 'AVAILABLE',
    );
  }
}
