import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_assets.dart';

enum SportCategory {
  boxCricket,
  pickleball,
  football,
  badminton,
  basketball,
  volleyball,
  tableTennis,
  running,
  cycling,
  yoga,
  gym,
  hiking,
  walking,
  cafeHangout,
  gaming,
  photography,
  movie,
  dance,
  shopping,
}

enum ActivityMembershipStatus {
  loading,
  host,
  joined,
  pending,
  notJoined,
}

enum SkillLevel {
  beginner('Beginner', Color(0xFFE8F0FE), Color(0xFF1E5BBF)),
  intermediate('Intermediate', Color(0xFFFEF3C7), Color(0xFFD97706)),
  allLevels('All Levels', Color(0xFFD1FAE5), Color(0xFF059669)),
  advanced('Advanced', Color(0xFFFFE4E6), Color(0xFFE11D48));

  final String label;
  final Color backgroundColor;
  final Color textColor;

  const SkillLevel(this.label, this.backgroundColor, this.textColor);
}

class ActivityModel {
  final String id;
  final String title;
  final String subtitle;
  final String iconAsset;
  final SportCategory sportCategory;
  final SkillLevel skillLevel;
  final int joinedPlayers;
  final int totalPlayers;
  final int pricePerPerson;
  final String note;
  final DateTime? date;
  final bool isHost;
  final String? hostId;
  final String? hostName;
  final String? hostUsername;
  final String? hostPhotoUrl;
  final String? venueName;
  final String? venueLocation;
  final bool venueConfirmed;
  final List<PlayerModel>? players;
  final List<String>? participantIds;
  final bool isInviteOnly;
  final String city;
  final double? latitude;
  final double? longitude;
  final String equipment;
  final int durationMinutes;
  final String status; // 'scheduled', 'live', 'completed', 'cancelled'

  const ActivityModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    this.sportCategory = SportCategory.boxCricket,
    required this.skillLevel,
    required this.joinedPlayers,
    required this.totalPlayers,
    required this.pricePerPerson,
    this.note = 'No equipment needed',
    this.date,
    this.isHost = false,
    this.hostId,
    this.hostName,
    this.hostUsername,
    this.hostPhotoUrl,
    this.venueName,
    this.venueLocation,
    this.venueConfirmed = true,
    this.players,
    this.participantIds,
    this.isInviteOnly = true,
    this.city = 'Bhavnagar',
    this.latitude,
    this.longitude,
    this.equipment = 'None',
    this.durationMinutes = 60,
    this.status = 'scheduled',
  });

  DateTime? get endTimestamp =>
      date?.add(Duration(minutes: durationMinutes));

  bool get isExpired =>
      endTimestamp != null && endTimestamp!.isBefore(DateTime.now());

  double get progress =>
      totalPlayers > 0 ? (joinedPlayers / totalPlayers).clamp(0.0, 1.0) : 0.0;

  String get playersText => '$joinedPlayers/$totalPlayers players';

  String get priceText => '₹$pricePerPerson/person';

  static String getIconForCategory(SportCategory category) {
    switch (category) {
      case SportCategory.boxCricket:
        return AppAssets.actBoxCricket;
      case SportCategory.pickleball:
        return AppAssets.actPickleball;
      case SportCategory.football:
        return AppAssets.actFootball;
      case SportCategory.badminton:
        return AppAssets.actBadminton;
      case SportCategory.basketball:
        return AppAssets.actBasketball;
      case SportCategory.volleyball:
        return AppAssets.actVolleyball;
      case SportCategory.tableTennis:
        return AppAssets.actTableTennis;
      case SportCategory.running:
        return AppAssets.actRunning;
      case SportCategory.cycling:
        return AppAssets.actCycling;
      case SportCategory.yoga:
        return AppAssets.actYoga;
      case SportCategory.gym:
        return AppAssets.actGym;
      case SportCategory.hiking:
        return AppAssets.actHiking;
      case SportCategory.walking:
        return AppAssets.actWalking;
      case SportCategory.cafeHangout:
        return AppAssets.actCafeHangout;
      case SportCategory.gaming:
        return AppAssets.actGaming;
      case SportCategory.photography:
        return AppAssets.actPhotography;
      case SportCategory.movie:
        return AppAssets.actMovie;
      case SportCategory.dance:
        return AppAssets.actDance;
      case SportCategory.shopping:
        return AppAssets.actShopping;
    }
  }

  factory ActivityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? currentUid,
  }) {
    final data = doc.data() ?? {};
    final String hostId = data['hostId'] as String? ?? '';

    SportCategory category = SportCategory.boxCricket;
    final catStr = data['sportCategory'] as String?;
    if (catStr != null) {
      category = SportCategory.values.firstWhere(
        (e) => e.name == catStr,
        orElse: () => SportCategory.boxCricket,
      );
    }

    SkillLevel skill = SkillLevel.allLevels;
    final skillStr = data['skillLevel'] as String?;
    if (skillStr != null) {
      skill = SkillLevel.values.firstWhere(
        (e) => e.name == skillStr,
        orElse: () => SkillLevel.allLevels,
      );
    }

    DateTime? date;
    final ts = data['date'] ?? data['startTimestamp'];
    if (ts is Timestamp) {
      date = ts.toDate();
    } else if (ts is String) {
      date = DateTime.tryParse(ts);
    }

    final String title = data['title'] as String? ?? 'Sports Activity';
    final String venueName = data['venueName'] as String? ?? 'Bhavnagar';
    final String iconAsset = data['iconAsset'] as String? ?? getIconForCategory(category);
    final String subtitle = data['subtitle'] as String? ?? '$venueName · Bhavnagar';

    final rawParticipantIds = data['participantIds'];
    final List<String> participantIds = rawParticipantIds is List
        ? rawParticipantIds.map((e) => e.toString()).toList()
        : (hostId.isNotEmpty ? [hostId] : []);

    final int durationMinutes = (data['durationMinutes'] as num?)?.toInt() ?? 60;

    return ActivityModel(
      id: doc.id,
      title: title,
      subtitle: subtitle,
      iconAsset: iconAsset,
      sportCategory: category,
      skillLevel: skill,
      joinedPlayers: (data['joinedPlayers'] as num?)?.toInt() ?? 1,
      totalPlayers: (data['totalPlayers'] as num?)?.toInt() ?? 8,
      pricePerPerson: (data['pricePerPerson'] as num?)?.toInt() ?? 0,
      note: data['note'] as String? ?? 'No equipment needed',
      date: date,
      isHost: currentUid != null && currentUid.isNotEmpty && hostId == currentUid,
      hostId: hostId,
      hostName: data['hostName'] as String? ?? 'Host',
      hostUsername: data['hostUsername'] as String? ?? '',
      hostPhotoUrl: data['hostPhotoUrl'] as String?,
      venueName: venueName,
      venueLocation: data['venueLocation'] as String? ?? venueName,
      venueConfirmed: data['venueConfirmed'] as bool? ?? true,
      participantIds: participantIds,
      isInviteOnly: data['isInviteOnly'] as bool? ?? true,
      city: data['city'] as String? ?? 'Bhavnagar',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      equipment: data['equipment'] as String? ?? 'None',
      durationMinutes: durationMinutes,
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'title': title,
      'subtitle': subtitle,
      'iconAsset': iconAsset,
      'sportCategory': sportCategory.name,
      'skillLevel': skillLevel.name,
      'joinedPlayers': joinedPlayers,
      'totalPlayers': totalPlayers,
      'pricePerPerson': pricePerPerson,
      'note': note,
      'hostId': hostId,
      'hostName': hostName,
      'hostUsername': hostUsername,
      'hostPhotoUrl': hostPhotoUrl,
      'venueName': venueName,
      'venueLocation': venueLocation,
      'venueConfirmed': venueConfirmed,
      'participantIds': participantIds ?? (hostId != null && hostId!.isNotEmpty ? [hostId!] : []),
      'isInviteOnly': isInviteOnly,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'equipment': equipment,
      'durationMinutes': durationMinutes,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (date != null) {
      data['date'] = Timestamp.fromDate(date!);
      data['startTimestamp'] = Timestamp.fromDate(date!);
      final end = endTimestamp;
      if (end != null) {
        data['endTimestamp'] = Timestamp.fromDate(end);
      }
    }

    return data;
  }

  ActivityModel copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconAsset,
    SportCategory? sportCategory,
    SkillLevel? skillLevel,
    int? joinedPlayers,
    int? totalPlayers,
    int? pricePerPerson,
    String? note,
    DateTime? date,
    bool? isHost,
    String? hostId,
    String? hostName,
    String? hostUsername,
    String? hostPhotoUrl,
    String? venueName,
    String? venueLocation,
    bool? venueConfirmed,
    List<PlayerModel>? players,
    List<String>? participantIds,
    bool? isInviteOnly,
    String? city,
    double? latitude,
    double? longitude,
    String? equipment,
    int? durationMinutes,
    String? status,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconAsset: iconAsset ?? this.iconAsset,
      sportCategory: sportCategory ?? this.sportCategory,
      skillLevel: skillLevel ?? this.skillLevel,
      joinedPlayers: joinedPlayers ?? this.joinedPlayers,
      totalPlayers: totalPlayers ?? this.totalPlayers,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      note: note ?? this.note,
      date: date ?? this.date,
      isHost: isHost ?? this.isHost,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostUsername: hostUsername ?? this.hostUsername,
      hostPhotoUrl: hostPhotoUrl ?? this.hostPhotoUrl,
      venueName: venueName ?? this.venueName,
      venueLocation: venueLocation ?? this.venueLocation,
      venueConfirmed: venueConfirmed ?? this.venueConfirmed,
      players: players ?? this.players,
      participantIds: participantIds ?? this.participantIds,
      isInviteOnly: isInviteOnly ?? this.isInviteOnly,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      equipment: equipment ?? this.equipment,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
    );
  }
}

class PlayerModel {
  final String id;
  final String name;
  final String role; // 'HOST' or 'MEMBER'
  final String skill; // 'Intermediate', 'Advanced', 'Beginner'
  final String? avatarAsset;
  final String? avatarUrl;
  final Color avatarBgColor;
  final bool isHost;
  final String? subtitle;
  final bool isInvited;

  const PlayerModel({
    required this.id,
    required this.name,
    this.role = 'MEMBER',
    this.skill = 'Intermediate',
    this.avatarAsset,
    this.avatarUrl,
    this.avatarBgColor = const Color(0xFF0D47A1),
    this.isHost = false,
    this.subtitle,
    this.isInvited = false,
  });

  factory PlayerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return PlayerModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Player',
      role: data['role'] as String? ?? 'MEMBER',
      skill: data['skill'] as String? ?? 'Intermediate',
      avatarUrl: data['avatarUrl'] as String?,
      isHost: data['isHost'] as bool? ?? (data['role'] == 'HOST'),
      subtitle: data['subtitle'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'skill': skill,
      'avatarUrl': avatarUrl,
      'isHost': isHost,
      'subtitle': subtitle,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  PlayerModel copyWith({
    String? id,
    String? name,
    String? role,
    String? skill,
    String? avatarAsset,
    String? avatarUrl,
    Color? avatarBgColor,
    bool? isHost,
    String? subtitle,
    bool? isInvited,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      skill: skill ?? this.skill,
      avatarAsset: avatarAsset ?? this.avatarAsset,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBgColor: avatarBgColor ?? this.avatarBgColor,
      isHost: isHost ?? this.isHost,
      subtitle: subtitle ?? this.subtitle,
      isInvited: isInvited ?? this.isInvited,
    );
  }
}

class DateItemModel {
  final String dayName;
  final String dayNumber;
  final DateTime date;
  final bool isSelected;

  const DateItemModel({
    required this.dayName,
    required this.dayNumber,
    required this.date,
    this.isSelected = false,
  });

  DateItemModel copyWith({
    String? dayName,
    String? dayNumber,
    DateTime? date,
    bool? isSelected,
  }) {
    return DateItemModel(
      dayName: dayName ?? this.dayName,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class FilterChipModel {
  final String id;
  final String label;
  final IconData icon;
  final bool isSelected;

  const FilterChipModel({
    required this.id,
    required this.label,
    required this.icon,
    this.isSelected = false,
  });

  FilterChipModel copyWith({
    String? id,
    String? label,
    IconData? icon,
    bool? isSelected,
  }) {
    return FilterChipModel(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
