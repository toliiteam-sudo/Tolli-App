import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/models/activity_model.dart';

void main() {
  group('Upcoming Activities Data & Filtering Logic Tests', () {
    const testUid = 'user_123';
    final now = DateTime.now();

    test('Hosted activity is included even if user is not in participantIds', () {
      final hostedActivity = ActivityModel(
        id: 'act_1',
        title: 'Box Cricket',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 8,
        pricePerPerson: 100,
        date: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        hostId: testUid,
        isHost: true,
        participantIds: [], // Empty participantIds!
      );

      final isHosted = hostedActivity.hostId == testUid;
      final isUpcoming = hostedActivity.endTimestamp != null &&
          hostedActivity.endTimestamp!.isAfter(now) &&
          hostedActivity.status != 'cancelled';

      expect(isHosted, isTrue);
      expect(isUpcoming, isTrue);
    });

    test('Future activity with startTimestamp > now is included', () {
      final futureActivity = ActivityModel(
        id: 'act_2',
        title: 'Football',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 10,
        pricePerPerson: 150,
        date: now.add(const Duration(hours: 4)),
        durationMinutes: 90,
        hostId: testUid,
        isHost: true,
      );

      expect(futureActivity.endTimestamp!.isAfter(now), isTrue);
    });

    test('Currently running activity (started but endTimestamp > now) remains in upcoming', () {
      final runningActivity = ActivityModel(
        id: 'act_3',
        title: 'Badminton',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 2,
        totalPlayers: 4,
        pricePerPerson: 80,
        date: now.subtract(const Duration(minutes: 30)), // Started 30 mins ago
        durationMinutes: 60, // Ends in 30 mins
        hostId: testUid,
        isHost: true,
      );

      expect(runningActivity.date!.isBefore(now), isTrue);
      expect(runningActivity.endTimestamp!.isAfter(now), isTrue);
    });

    test('Ended activity (endTimestamp <= now) is excluded from upcoming', () {
      final endedActivity = ActivityModel(
        id: 'act_4',
        title: 'Tennis',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 2,
        totalPlayers: 2,
        pricePerPerson: 200,
        date: now.subtract(const Duration(hours: 2)),
        durationMinutes: 60, // Ended 1 hour ago
        hostId: testUid,
        isHost: true,
      );

      expect(endedActivity.endTimestamp!.isAfter(now), isFalse);
    });

    test('Deduplication by activityId handles hosted and joined overlap', () {
      final hostedAct = ActivityModel(
        id: 'act_box_cricket',
        title: 'Box Cricket',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 8,
        pricePerPerson: 100,
        date: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        hostId: testUid,
        isHost: true,
      );

      final joinedAct = ActivityModel(
        id: 'act_box_cricket',
        title: 'Box Cricket',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 8,
        pricePerPerson: 100,
        date: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        hostId: testUid,
        participantIds: [testUid],
      );

      final Map<String, ActivityModel> map = {};
      map[hostedAct.id] = hostedAct;
      if (!map.containsKey(joinedAct.id)) {
        map[joinedAct.id] = joinedAct;
      }

      expect(map.length, 1);
      expect(map['act_box_cricket']!.isHost, isTrue);
    });

    test('Activities are sorted chronologically', () {
      final actEarlier = ActivityModel(
        id: 'act_1',
        title: 'Box Cricket',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 8,
        pricePerPerson: 100,
        date: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        hostId: testUid,
      );

      final actLater = ActivityModel(
        id: 'act_2',
        title: 'Football',
        subtitle: 'Bhavnagar',
        iconAsset: '',
        skillLevel: SkillLevel.allLevels,
        joinedPlayers: 1,
        totalPlayers: 10,
        pricePerPerson: 150,
        date: now.add(const Duration(hours: 5)),
        durationMinutes: 60,
        hostId: testUid,
      );

      final list = [actLater, actEarlier];
      list.sort((a, b) => (a.date ?? now).compareTo(b.date ?? now));

      expect(list[0].id, 'act_1');
      expect(list[1].id, 'act_2');
    });
  });
}
