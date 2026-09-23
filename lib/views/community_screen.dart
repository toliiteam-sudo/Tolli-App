import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../repositories/community_repository.dart';
import '../utils/app_transitions.dart';
import 'community_chat_screen.dart';
import '../widgets/toli_header.dart';
import '../widgets/toli_refresh_indicator.dart';

class CommunityModel {
  final String id;
  final String title;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String avatarInitials;
  final String membersCount;
  final String description;

  const CommunityModel({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.avatarInitials,
    this.membersCount = '120+ members',
    this.description = 'Connect with local players, share match updates, and organize games in Bhavnagar!',
  });
}

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<CommunityModel> _communities = [];
  late List<CommunityModel> _discoverCommunities;
  StreamSubscription<List<String>>? _joinedSubscription;

  static final Map<String, CommunityModel> _catalogMap = {
    'comm_1': const CommunityModel(
      id: 'comm_1',
      title: 'Box Cricket Bhavnagar',
      lastMessage: 'Tap to view live chat',
      time: '',
      unreadCount: 0,
      icon: Icons.sports_cricket_rounded,
      iconColor: Color(0xFF0284C7),
      iconBgColor: Color(0xFFE0F2FE),
      avatarInitials: 'BC',
      membersCount: 'Local Group',
    ),
    'comm_2': const CommunityModel(
      id: 'comm_2',
      title: 'Weekend Cyclists 🚴',
      lastMessage: 'Tap to view live chat',
      time: '',
      unreadCount: 0,
      icon: Icons.directions_bike_rounded,
      iconColor: Color(0xFF16A34A),
      iconBgColor: Color(0xFFDCFCE7),
      avatarInitials: 'WC',
      membersCount: 'Local Group',
    ),
    'comm_3': const CommunityModel(
      id: 'comm_3',
      title: 'Pickleball Players',
      lastMessage: 'Tap to view live chat',
      time: '',
      unreadCount: 0,
      icon: Icons.sports_tennis_rounded,
      iconColor: Color(0xFFD97706),
      iconBgColor: Color(0xFFFEF3C7),
      avatarInitials: 'PB',
      membersCount: 'Local Group',
    ),
    'comm_4': const CommunityModel(
      id: 'comm_4',
      title: 'Bhavnagar Football',
      lastMessage: 'Tap to view live chat',
      time: '',
      unreadCount: 0,
      icon: Icons.sports_soccer_rounded,
      iconColor: Color(0xFF7C3AED),
      iconBgColor: Color(0xFFF3E8FF),
      avatarInitials: 'BF',
      membersCount: 'Local Group',
    ),
    'disc_1': const CommunityModel(
      id: 'disc_1',
      title: 'Sports & Games',
      lastMessage: 'Tap to join group chat',
      time: '',
      icon: Icons.sports_cricket_rounded,
      iconColor: Color(0xFF0284C7),
      iconBgColor: Color(0xFFE8F0FE),
      avatarInitials: 'SG',
      membersCount: 'Open Community',
      description: 'Connect with local sports players in your city. Find players for cricket, football, badminton, and more.',
    ),
    'disc_2': const CommunityModel(
      id: 'disc_2',
      title: 'Cycling Crew',
      lastMessage: 'Morning rides planned!',
      time: 'Just now',
      icon: Icons.directions_bike_rounded,
      iconColor: Color(0xFF16A34A),
      iconBgColor: Color(0xFFE6F7ED),
      avatarInitials: 'CC',
      membersCount: '95+ members',
      description: 'Explore scenic routes around Bhavnagar with fellow cycling enthusiasts every weekend!',
    ),
    'disc_3': const CommunityModel(
      id: 'disc_3',
      title: 'Weekend Out',
      lastMessage: 'Takhteshwar hike coming up!',
      time: 'Just now',
      icon: Icons.hiking_rounded,
      iconColor: Color(0xFFEA580C),
      iconBgColor: Color(0xFFFFF1E8),
      avatarInitials: 'WO',
      membersCount: '110+ members',
      description: 'Outdoor meetups, nature walks, hikes, and weekend getaways with fun active groups!',
    ),
  };

  @override
  void initState() {
    super.initState();
    _communities = [];
    _discoverCommunities = [
      _catalogMap['disc_1']!,
      _catalogMap['disc_2']!,
      _catalogMap['disc_3']!,
    ];

    AuthController.instance.addListener(_onAuthChanged);
    _initJoinedSubscription();
  }

  void _onAuthChanged() {
    if (mounted) {
      _initJoinedSubscription();
    }
  }

  void _initJoinedSubscription() {
    _joinedSubscription?.cancel();
    String uid = '';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {}
    if (uid.isNotEmpty) {
      _joinedSubscription = CommunityRepository()
          .watchJoinedCommunityIds(uid)
          .listen((joinedIds) {
        if (mounted) {
          setState(() {
            _communities = joinedIds
                .map((id) => _catalogMap[id] ?? CommunityModel(
                      id: id,
                      title: id,
                      lastMessage: 'Tap to view live chat',
                      time: '',
                      icon: Icons.groups_rounded,
                      iconColor: AppColors.primary,
                      iconBgColor: const Color(0xFFE0F2FE),
                      avatarInitials: id.length >= 2 ? id.substring(0, 2).toUpperCase() : 'CM',
                    ))
                .toList();
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _communities = [];
        });
      }
    }
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
    _joinedSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(CommunityModel community) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        CommunityChatScreen(
          communityId: community.id,
          title: community.title,
          membersCount: community.membersCount,
          avatarInitials: community.avatarInitials,
          onLeaveGroup: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            if (uid.isNotEmpty) {
              await CommunityRepository().leaveCommunity(
                communityId: community.id,
                uid: uid,
              );
            }
          },
        ),
      ),
    );
  }

  void _showJoinCommunityDialog(CommunityModel community) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: community.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  community.icon,
                  color: community.iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                community.title,
                textAlign: TextAlign.center,
                style: AppTypography.headline.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),

              // Members Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  community.membersCount,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                community.description,
                textAlign: TextAlign.center,
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTypography.buttonText.copyWith(
                          color: const Color(0xFF475569),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx); // Close popup
                        _joinCommunity(community);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Join Group',
                        style: AppTypography.buttonText.copyWith(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinCommunity(CommunityModel community) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final name = AuthController.instance.state.displayName.isNotEmpty
        ? AuthController.instance.state.displayName
        : 'Sports Player';

    if (uid.isNotEmpty) {
      await CommunityRepository().joinCommunity(
        communityId: community.id,
        uid: uid,
        userName: name,
        userPhotoUrl: AuthController.instance.state.avatarUrl,
        communityTitle: community.title,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined ${community.title}!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _openChat(community);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Fixed Top Header Bar
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: const ToliHeader(
                title: 'Hey!',
                subtitle: 'Bhavnagar',
              ),
            ),

            // 2. Fixed Search Bar (Pins directly beneath Header)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        maxLength: 100,
                        style: AppTypography.bodySubtitle.copyWith(
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search activities, people or places',
                          hintStyle: AppTypography.caption.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Scrollable Community Content Area
            Expanded(
              child: ToliRefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 1000));
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Your Communities" Section
                      Text(
                        'Your Communities',
                        style: AppTypography.headline.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 14),

              // Communities Card List
              if (_communities.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.groups_outlined, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        'No joined communities yet',
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Join a community below to start chatting!',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _communities.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final comm = entry.value;
                      final isLast = idx == _communities.length - 1;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () => _openChat(comm),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(idx == 0 ? 18 : 0),
                              bottom: Radius.circular(isLast ? 18 : 0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: comm.iconBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      comm.icon,
                                      color: comm.iconColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comm.title,
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          comm.lastMessage,
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 12.5,
                                            color: const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        comm.time,
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: comm.unreadCount > 0
                                              ? AppColors.primary
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (comm.unreadCount > 0)
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${comm.unreadCount}',
                                            style: AppTypography.caption.copyWith(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 20),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                              color: Color(0xFFF1F5F9),
                              height: 1,
                              indent: 74,
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 26),

              // 4. "Discover Communities" Section
              Text(
                'Discover Communities',
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: _discoverCommunities.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final comm = entry.value;
                  final isLast = idx == _discoverCommunities.length - 1;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 10),
                      child: _buildDiscoverCard(
                        icon: comm.icon,
                        iconColor: comm.iconColor,
                        cardBg: comm.iconBgColor,
                        title: comm.title,
                        onTap: () => _showJoinCommunityDialog(comm),
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
            ],
          ),
        ),
      ),
    ),
  ],
),
),
),
);
}

  Widget _buildDiscoverCard({
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
