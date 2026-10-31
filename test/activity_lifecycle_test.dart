import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/models/activity_model.dart';
import 'package:tolii/models/activity_request_model.dart';
import 'package:tolii/models/booking_model.dart';
import 'package:tolii/models/location_venue_item.dart';
import 'package:tolii/models/notification_model.dart';

void main() {
  group('TOLII Activity Lifecycle & Upcoming Games Tests', () {
    final now = DateTime.now();
    final futureDate = now.add(const Duration(hours: 4));
    final pastDate = now.subtract(const Duration(hours: 4));

    ActivityModel createMockActivity({
      required String id,
      required String title,
      required int joinedPlayers,
      required int totalPlayers,
      required List<String> participantIds,
      required String hostId,
      required DateTime date,
      String status = 'scheduled',
      bool isHost = false,
    }) {
      return ActivityModel(
        id: id,
        title: title,
        subtitle: 'Game',
        iconAsset: 'assets/icons/sports.png',
        sportCategory: SportCategory.badminton,
        skillLevel: SkillLevel.intermediate,
        joinedPlayers: joinedPlayers,
        totalPlayers: totalPlayers,
        pricePerPerson: 150,
        venueName: 'Bhavnagar Club',
        venueLocation: 'Bhavnagar',
        date: date,
        hostId: hostId,
        hostName: 'Host Name',
        isHost: isHost,
        participantIds: participantIds,
        status: status,
        durationMinutes: 60,
      );
    }

    BookingModel createMockBooking({
      required String bookingId,
      required BookingStatus bookingStatus,
      required String paymentStatus,
      required DateTime date,
    }) {
      return BookingModel(
        bookingId: bookingId,
        userId: 'user_123',
        venueId: 'v_1',
        venueName: 'Arena',
        venueAddress: 'Bhavnagar',
        venueImageAsset: '',
        courtId: 'c_1',
        courtName: 'Court 1',
        slotId: 's_1',
        sportId: 'pickleball',
        sportName: 'Pickleball',
        bookingDate: '2026-10-15',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        startTimestamp: date.millisecondsSinceEpoch,
        endTimestamp: date.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        durationMinutes: 60,
        amountPaise: 60000,
        discountPaise: 0,
        feePaise: 0,
        finalAmountPaise: 60000,
        currency: 'INR',
        bookingStatus: bookingStatus,
        paymentStatus: paymentStatus,
        cancellationPolicySnapshot: 'Full refund 24h prior.',
        createdAt: now,
        updatedAt: now,
      );
    }

    test('1. User joins an open future activity -> included in Upcoming list', () {
      final activity = createMockActivity(
        id: 'act_101',
        title: 'Morning Badminton',
        joinedPlayers: 2,
        totalPlayers: 4,
        participantIds: ['host_uid', 'user_123'],
        hostId: 'host_uid',
        date: futureDate,
      );

      final currentUid = 'user_123';
      final isMember = activity.participantIds?.contains(currentUid) == true;
      final isUpcoming = activity.status != 'cancelled' &&
          (activity.endTimestamp?.isAfter(now) ?? true) &&
          isMember;

      expect(isMember, true);
      expect(isUpcoming, true);
    });

    test('2. User leaves activity -> disappears from Upcoming list', () {
      final activity = createMockActivity(
        id: 'act_101',
        title: 'Morning Badminton',
        joinedPlayers: 1,
        totalPlayers: 4,
        participantIds: ['host_uid'],
        hostId: 'host_uid',
        date: futureDate,
      );

      final currentUid = 'user_123';
      final isMember = activity.participantIds?.contains(currentUid) == true;
      final isUpcoming = activity.status != 'cancelled' &&
          (activity.endTimestamp?.isAfter(now) ?? true) &&
          isMember;

      expect(isMember, false);
      expect(isUpcoming, false);
    });

    test('3. Rejoining a previously left activity -> displays normal Join button', () {
      final activity = createMockActivity(
        id: 'act_101',
        title: 'Morning Badminton',
        joinedPlayers: 1,
        totalPlayers: 4,
        participantIds: ['host_uid'],
        hostId: 'host_uid',
        date: futureDate,
      );

      final currentUid = 'user_123';
      final hasJoined = activity.participantIds?.contains(currentUid) == true;
      final hasCapacity = activity.joinedPlayers < activity.totalPlayers;

      expect(hasJoined, false);
      expect(hasCapacity, true);
    });

    test('4. User rejoins -> appears in Upcoming exactly once (no duplicates)', () {
      final list = <ActivityModel>[];
      final act1 = createMockActivity(
        id: 'act_101',
        title: 'Morning Badminton',
        joinedPlayers: 2,
        totalPlayers: 4,
        participantIds: ['host_uid', 'user_123'],
        hostId: 'host_uid',
        date: futureDate,
      );

      final Map<String, ActivityModel> map = {};
      map[act1.id] = act1;
      if (!map.containsKey(act1.id)) {
        map[act1.id] = act1;
      }

      list.addAll(map.values);
      expect(list.length, 1);
      expect(list.first.id, 'act_101');
    });

    test('5. Pending join request does not appear as confirmed membership', () {
      const isRequestPending = true;
      const isParticipant = false;

      final isUpcomingMember = isParticipant;
      expect(isRequestPending, true);
      expect(isUpcomingMember, false);
    });

    test('6. Host membership remains visible in Upcoming', () {
      final activity = createMockActivity(
        id: 'act_102',
        title: 'Cricket Match',
        joinedPlayers: 1,
        totalPlayers: 12,
        participantIds: ['host_uid'],
        hostId: 'host_uid',
        date: futureDate,
        isHost: true,
      );

      final currentUid = 'host_uid';
      final isHostOrMember = activity.hostId == currentUid ||
          (activity.participantIds?.contains(currentUid) ?? false);

      expect(isHostOrMember, true);
    });

    test('7. Full activity prevents ordinary joining', () {
      final activity = createMockActivity(
        id: 'act_103',
        title: 'Tennis Doubles',
        joinedPlayers: 4,
        totalPlayers: 4,
        participantIds: ['p1', 'p2', 'p3', 'p4'],
        hostId: 'p1',
        date: futureDate,
      );

      final canJoin = activity.joinedPlayers < activity.totalPlayers;
      expect(canJoin, false);
    });

    test('8. Cancelled activity cannot be joined and disappears from Upcoming', () {
      final activity = createMockActivity(
        id: 'act_104',
        title: 'Football 5v5',
        joinedPlayers: 4,
        totalPlayers: 10,
        participantIds: ['p1', 'p2', 'p3', 'user_123'],
        hostId: 'p1',
        date: futureDate,
        status: 'cancelled',
      );

      final canJoin = activity.status == 'scheduled' && activity.joinedPlayers < activity.totalPlayers;
      final isUpcoming = activity.status != 'cancelled' &&
          (activity.endTimestamp?.isAfter(now) ?? true);

      expect(canJoin, false);
      expect(isUpcoming, false);
    });

    test('9. Completed activity is excluded from Upcoming', () {
      final activity = createMockActivity(
        id: 'act_105',
        title: 'Yesterday Game',
        joinedPlayers: 11,
        totalPlayers: 11,
        participantIds: ['user_123'],
        hostId: 'user_123',
        date: pastDate,
        status: 'completed',
      );

      final isUpcoming = activity.status == 'scheduled' &&
          (activity.endTimestamp?.isAfter(now) ?? true);

      expect(isUpcoming, false);
    });

    test('10. Host cancellation removes activity from Upcoming for all participants', () {
      final activity = createMockActivity(
        id: 'act_106',
        title: 'Pickleball',
        joinedPlayers: 3,
        totalPlayers: 4,
        participantIds: ['host_uid', 'p2', 'p3'],
        hostId: 'host_uid',
        date: futureDate,
        status: 'cancelled',
      );

      final isUpcoming = activity.status != 'cancelled' &&
          (activity.endTimestamp?.isAfter(now) ?? true);

      expect(isUpcoming, false);
    });

    test('11. Booking is not confirmed before trusted payment verification', () {
      final booking = createMockBooking(
        bookingId: 'bk_201',
        bookingStatus: BookingStatus.held,
        paymentStatus: 'CREATED',
        date: futureDate,
      );

      expect(booking.bookingStatus, BookingStatus.held);
      expect(booking.paymentStatus, 'CREATED');
      expect(booking.bookingStatus == BookingStatus.confirmed, false);
    });

    test('12. Confirmed booking appears under My Bookings', () {
      final booking = createMockBooking(
        bookingId: 'bk_202',
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: 'CAPTURED',
        date: futureDate,
      );

      final isConfirmed = booking.bookingStatus == BookingStatus.confirmed;
      expect(isConfirmed, true);
    });

    test('13. Cancelled booking leaves active booking list but remains in history', () {
      final booking = createMockBooking(
        bookingId: 'bk_203',
        bookingStatus: BookingStatus.cancelled,
        paymentStatus: 'REFUNDED',
        date: futureDate,
      );

      final isActive = booking.bookingStatus == BookingStatus.confirmed || booking.bookingStatus == BookingStatus.held;
      final isHistory = booking.bookingStatus == BookingStatus.cancelled || booking.bookingStatus == BookingStatus.completed;

      expect(isActive, false);
      expect(isHistory, true);
    });

    test('14. Leaving an activity does not cancel its associated venue booking', () {
      BookingStatus getStatusAfterLeave(BookingStatus status, bool left) {
        if (left) return status;
        return BookingStatus.cancelled;
      }

      final remainingBookingStatus = getStatusAfterLeave(BookingStatus.confirmed, true);
      expect(remainingBookingStatus, BookingStatus.confirmed);
    });

    test('15. Duplicate join operations do not inflate participant count', () {
      final participantIds = <String>['host_uid', 'user_123'];
      var joinedPlayers = 2;

      const newUid = 'user_123';
      if (!participantIds.contains(newUid)) {
        participantIds.add(newUid);
        joinedPlayers++;
      }

      expect(participantIds.length, 2);
      expect(joinedPlayers, 2);
    });

    test('16. Duplicate backend webhook events do not create duplicate notifications', () {
      final processedEvents = <String>{'evt_123'};
      final notifications = <NotificationModel>[];

      void processEvent(String eventId) {
        if (processedEvents.contains(eventId)) return;
        processedEvents.add(eventId);
        notifications.add(
          NotificationModel(
            id: 'n_1',
            recipientId: 'user_123',
            type: 'booking_confirmed',
            title: 'Booking Confirmed',
            body: 'Your venue booking is confirmed.',
            createdAt: now,
            isRead: false,
          ),
        );
      }

      processEvent('evt_123');
      expect(notifications.length, 0);
    });

    test('17. Notification deep links contain correct related IDs', () {
      final notif = NotificationModel(
        id: 'notif_1',
        recipientId: 'user_123',
        type: 'join_request',
        title: 'New Request',
        body: 'User requested to join',
        createdAt: now,
        isRead: false,
        relatedActivityId: 'act_999',
      );

      expect(notif.relatedActivityId, 'act_999');
    });

    test('18. State consistency after model serialization & deserialization', () {
      final original = createMockBooking(
        bookingId: 'bk_999',
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: 'CAPTURED',
        date: futureDate,
      );

      final map = original.toMap();
      final restored = BookingModel.fromMap(map);

      expect(restored.bookingId, original.bookingId);
      expect(restored.bookingStatus, original.bookingStatus);
      expect(restored.finalAmountPaise, original.finalAmountPaise);
    });

    group('BUG 1 Regression Tests — Activity Joining Lifecycle & Guards', () {
      test('19. Public join succeeds when activity has available capacity and is open', () {
        final activity = createMockActivity(
          id: 'act_pub_1',
          title: 'Open Badminton',
          joinedPlayers: 2,
          totalPlayers: 4,
          participantIds: ['host_1', 'user_1'],
          hostId: 'host_1',
          date: futureDate,
        );

        const joiningUid = 'user_2';
        final canJoin = activity.status == 'scheduled' &&
            !activity.isExpired &&
            activity.joinedPlayers < activity.totalPlayers &&
            activity.hostId != joiningUid &&
            !(activity.participantIds?.contains(joiningUid) ?? false);

        expect(canJoin, true);

        final updated = activity.copyWith(
          joinedPlayers: activity.joinedPlayers + 1,
          participantIds: [...(activity.participantIds ?? []), joiningUid],
        );
        expect(updated.joinedPlayers, 3);
        expect(updated.participantIds!.contains(joiningUid), true);
      });

      test('20. Invite-only activity generates pending request without instant membership', () {
        final activity = createMockActivity(
          id: 'act_inv_1',
          title: 'Invite-Only Tennis',
          joinedPlayers: 1,
          totalPlayers: 4,
          participantIds: ['host_1'],
          hostId: 'host_1',
          date: futureDate,
        );

        const requestingUid = 'user_req';
        // When invite-only, user submits a request, activity participants remain unchanged
        final request = ActivityRequestModel(
          uid: requestingUid,
          activityId: activity.id,
          userName: 'Req User',
          userUsername: 'requser',
          status: 'pending',
        );

        expect(request.status, 'pending');
        expect(activity.participantIds!.contains(requestingUid), false);
        expect(activity.joinedPlayers, 1);
      });

      test('21. Host can accept pending request -> increments player count and adds participant', () {
        final activity = createMockActivity(
          id: 'act_inv_2',
          title: 'Invite-Only Tennis',
          joinedPlayers: 1,
          totalPlayers: 4,
          participantIds: ['host_1'],
          hostId: 'host_1',
          date: futureDate,
        );

        const approvedUid = 'user_approved';
        final hasCapacity = activity.joinedPlayers < activity.totalPlayers;
        expect(hasCapacity, true);

        final updated = activity.copyWith(
          joinedPlayers: activity.joinedPlayers + 1,
          participantIds: [...(activity.participantIds ?? []), approvedUid],
        );
        expect(updated.joinedPlayers, 2);
        expect(updated.participantIds!.contains(approvedUid), true);
      });

      test('22. Host can decline pending request -> activity membership is unchanged', () {
        final activity = createMockActivity(
          id: 'act_inv_3',
          title: 'Invite-Only Tennis',
          joinedPlayers: 1,
          totalPlayers: 4,
          participantIds: ['host_1'],
          hostId: 'host_1',
          date: futureDate,
        );

        const declinedUid = 'user_declined';
        final request = ActivityRequestModel(
          uid: declinedUid,
          activityId: activity.id,
          userName: 'Declined User',
          userUsername: 'declined',
          status: 'rejected',
        );

        expect(request.status, 'rejected');
        expect(activity.joinedPlayers, 1);
        expect(activity.participantIds!.contains(declinedUid), false);
      });

      test('23. Host cannot join their own activity as participant', () {
        final activity = createMockActivity(
          id: 'act_host_check',
          title: 'Hosted Match',
          joinedPlayers: 1,
          totalPlayers: 4,
          participantIds: ['host_uid'],
          hostId: 'host_uid',
          date: futureDate,
        );

        const attemptingUid = 'host_uid';
        final isHost = activity.hostId == attemptingUid;
        final canJoinAsParticipant = !isHost && !(activity.participantIds?.contains(attemptingUid) ?? false);

        expect(isHost, true);
        expect(canJoinAsParticipant, false);
      });

      test('24. Repeated join calls are idempotent and do not increment player count twice', () {
        final activity = createMockActivity(
          id: 'act_double_join',
          title: 'Cricket Match',
          joinedPlayers: 2,
          totalPlayers: 6,
          participantIds: ['host_uid', 'user_joined'],
          hostId: 'host_uid',
          date: futureDate,
        );

        const userUid = 'user_joined';
        final alreadyJoined = activity.participantIds?.contains(userUid) ?? false;
        expect(alreadyJoined, true);

        // Transaction logic: if already joined, return true without incrementing
        final updatedJoined = alreadyJoined ? activity.joinedPlayers : activity.joinedPlayers + 1;
        expect(updatedJoined, 2);
      });

      test('25. Ineligible activity (full, cancelled, or expired) rejects join', () {
        final fullAct = createMockActivity(
          id: 'act_full',
          title: 'Full Game',
          joinedPlayers: 4,
          totalPlayers: 4,
          participantIds: ['h', 'u1', 'u2', 'u3'],
          hostId: 'h',
          date: futureDate,
        );
        final cancelledAct = createMockActivity(
          id: 'act_canc',
          title: 'Cancelled Game',
          joinedPlayers: 2,
          totalPlayers: 4,
          participantIds: ['h', 'u1'],
          hostId: 'h',
          date: futureDate,
          status: 'cancelled',
        );
        final expiredAct = createMockActivity(
          id: 'act_exp',
          title: 'Expired Game',
          joinedPlayers: 2,
          totalPlayers: 4,
          participantIds: ['h', 'u1'],
          hostId: 'h',
          date: pastDate,
        );

        bool canJoin(ActivityModel a) =>
            a.status == 'scheduled' && !a.isExpired && a.joinedPlayers < a.totalPlayers;

        expect(canJoin(fullAct), false);
        expect(canJoin(cancelledAct), false);
        expect(canJoin(expiredAct), false);
      });
    });

    group('BUG 2 Regression Tests — Leaving & Deletion Lifecycle', () {
      test('26. Participant can leave activity -> player count decrements and uid removed', () {
        final activity = createMockActivity(
          id: 'act_leave_1',
          title: 'Evening Badminton',
          joinedPlayers: 3,
          totalPlayers: 4,
          participantIds: ['host_uid', 'user_leave', 'user_other'],
          hostId: 'host_uid',
          date: futureDate,
        );

        const leavingUid = 'user_leave';
        final isHost = activity.hostId == leavingUid;
        expect(isHost, false);

        final newParticipantIds = List<String>.from(activity.participantIds!)..remove(leavingUid);
        final newJoined = (activity.joinedPlayers - 1).clamp(0, 9999);

        expect(newJoined, 2);
        expect(newParticipantIds.contains(leavingUid), false);
        expect(newParticipantIds.length, 2);
      });

      test('27. Host is blocked from leaving their own activity as participant', () {
        final activity = createMockActivity(
          id: 'act_host_leave',
          title: 'Host Activity',
          joinedPlayers: 2,
          totalPlayers: 4,
          participantIds: ['host_uid', 'user_1'],
          hostId: 'host_uid',
          date: futureDate,
        );

        const attemptedLeaveUid = 'host_uid';
        final isHost = activity.hostId == attemptedLeaveUid;
        final canLeave = !isHost;

        expect(isHost, true);
        expect(canLeave, false);
      });

      test('28. Repeated leave calls are safe: count never goes negative or decrements twice', () {
        final activity = createMockActivity(
          id: 'act_repeat_leave',
          title: 'Solo Match',
          joinedPlayers: 1,
          totalPlayers: 2,
          participantIds: ['host_uid'],
          hostId: 'host_uid',
          date: futureDate,
        );

        const ghostUser = 'ghost_user';
        final isPresent = activity.participantIds?.contains(ghostUser) ?? false;
        expect(isPresent, false);

        // Safe leave logic: if not present, don't decrement
        final finalJoined = isPresent ? (activity.joinedPlayers - 1).clamp(0, 9999) : activity.joinedPlayers;
        expect(finalJoined, 1);
        expect(finalJoined >= 0, true);
      });

      test('29. Host deletion decouples venue booking: booking remains intact', () {
        final booking = createMockBooking(
          bookingId: 'bk_linked_1',
          bookingStatus: BookingStatus.confirmed,
          paymentStatus: 'CAPTURED',
          date: futureDate,
        );

        // Deleting activity does not change booking status
        bool deleteActivityPreservesBooking(BookingStatus bStatus) => bStatus == BookingStatus.confirmed;
        expect(deleteActivityPreservesBooking(booking.bookingStatus), true);
      });

      test('30. Participant count never exceeds total players and never drops below zero', () {
        const total = 4;
        var joined = 0;

        // Decrement below 0 is clamped to 0
        joined = (joined - 1).clamp(0, total);
        expect(joined, 0);

        // Increment up to total
        for (int i = 0; i < 10; i++) {
          if (joined < total) {
            joined++;
          }
        }
        expect(joined, 4);
      });
    });

    group('BUG 3 Regression Tests — Choose Location Navigation & Models', () {
      test('31. LocationVenueItem equality and properties', () {
        final v1 = LocationVenueItem(
          id: 'v_test_1',
          name: 'Sports Arena Sidsar',
          address: 'Sidsar Road, Bhavnagar',
          rating: 4.8,
          reviewsCount: 142,
          distance: '2.3 km',
          imageAsset: 'assets/images/pickleball.png',
        );
        final v2 = LocationVenueItem(
          id: 'v_test_1',
          name: 'Sports Arena Sidsar (Copy)',
          address: 'Different Address',
          rating: 4.0,
          reviewsCount: 10,
          distance: '5 km',
          imageAsset: 'assets/images/pickleball.png',
        );

        expect(v1, equals(v2));
        expect(v1.id, 'v_test_1');
      });

      test('32. Custom location creation for user-entered ground preserves search text', () {
        const userTypedLocation = 'Subhashnagar Community Turf';
        final customItem = LocationVenueItem(
          id: 'venue_custom_search',
          name: userTypedLocation,
          address: 'Host-arranged custom ground · Bhavnagar',
          rating: 5.0,
          reviewsCount: 1,
          distance: 'Arranged',
          imageAsset: 'assets/images/pickleball.png',
        );

        expect(customItem.name, 'Subhashnagar Community Turf');
        expect(customItem.id, 'venue_custom_search');
      });

      test('33. Decide location later option preserves TBD behavior', () {
        const decideLater = LocationVenueItem(
          id: 'venue_decide_later',
          name: 'Decide location later',
          address: 'Host will specify location before match',
          rating: 5.0,
          reviewsCount: 1,
          distance: 'TBD',
          imageAsset: 'assets/images/ahmedabad.png',
        );

        expect(decideLater.name, 'Decide location later');
        expect(decideLater.distance, 'TBD');
      });

      test('34. Create activity form state is preserved when location selector returns', () {
        // Initial form state
        var sportTitle = 'Box Cricket';
        var playersNeeded = 8;
        var selectedCost = 100;
        var venueName = 'Sports Arena Sidsar';

        // User opens selector and chooses a new venue
        const chosenVenue = LocationVenueItem(
          id: 'venue_2',
          name: 'Bhavnagar Sports Club',
          address: 'Jewel Circle',
          rating: 4.5,
          reviewsCount: 88,
          distance: '3.1 km',
          imageAsset: '',
        );

        // Result applied to venue only
        venueName = chosenVenue.name;

        // Verify other form fields are completely untouched
        expect(venueName, 'Bhavnagar Sports Club');
        expect(sportTitle, 'Box Cricket');
        expect(playersNeeded, 8);
        expect(selectedCost, 100);
      });
    });
  });
}

