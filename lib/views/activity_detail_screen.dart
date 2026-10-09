import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'community_chat_screen.dart';
import 'edit_activity_screen.dart';
import 'joined_screen.dart';
import 'players_screen.dart';

class ActivityDetailScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late ActivityModel _activity;
  ActivityMembershipStatus _membershipStatus = ActivityMembershipStatus.loading;
  bool _isActionInProgress = false;

  StreamSubscription<ActivityModel?>? _activitySubscription;
  StreamSubscription<List<PlayerModel>>? _participantsSubscription;
  StreamSubscription<ActivityMembershipStatus>? _membershipSubscription;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _activitySubscription = ActivityRepository()
        .watchActivityDetail(_activity.id, currentUid: currentUid)
        .listen((liveActivity) {
      if (liveActivity != null && mounted) {
        setState(() {
          _activity = liveActivity;
        });
      }
    });

    _participantsSubscription = ActivityRepository()
        .watchActivityParticipants(_activity.id)
        .listen((participants) {
      if (mounted) {
        setState(() {
          _activity = _activity.copyWith(players: participants);
        });
      }
    });

    if (currentUid.isNotEmpty) {
      _membershipSubscription = ActivityRepository()
          .watchActivityMembershipStatus(_activity.id, currentUid)
          .listen((status) {
        if (mounted) {
          setState(() {
            _membershipStatus = status;
          });
        }
      });
    } else {
      _membershipStatus = ActivityMembershipStatus.notJoined;
    }
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _participantsSubscription?.cancel();
    _membershipSubscription?.cancel();
    super.dispose();
  }

  void _openEditActivity() async {
    HapticFeedback.lightImpact();
    final updated = await Navigator.of(context).push<ActivityModel>(
      MaterialPageRoute(
        builder: (_) => EditActivityScreen(activity: _activity),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _activity = updated;
      });
    }
  }

  void _showDeleteConfirmationModal() {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Delete Activity?',
                      style: AppTypography.headline.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to delete "${_activity.title}"? This action cannot be undone and will notify all participants.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Cancel',
                        style: AppTypography.buttonText.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await ActivitiesController().deleteActivity(_activity.id);

                        if (mounted) {
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Activity deleted successfully',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF0F172A),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Delete',
                        style: AppTypography.buttonText.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  void _shareActivity() {
    HapticFeedback.lightImpact();
    final location = _activity.venueLocation ?? _activity.venueName ?? 'Bhavnagar';
    Clipboard.setData(ClipboardData(
      text: 'Join me for ${_activity.title} at $location! Open TOLII to join.',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activity details copied to clipboard! Share with friends.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF0F172A),
      ),
    );
  }

  void _openInMaps() {
    HapticFeedback.lightImpact();
    final location = _activity.venueLocation ?? _activity.venueName ?? _activity.title;
    Clipboard.setData(ClipboardData(text: '$location, ${_activity.city}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location copied: $location, ${_activity.city}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  void _showLeaveConfirmationModal(BuildContext context, ActivityModel activity) {
    HapticFeedback.mediumImpact();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isEmpty) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.exit_to_app_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Leave ${activity.title}?',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'You will lose your spot in this activity. You can join again later if spots are available.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        'Keep Me Joined',
                        style: AppTypography.buttonText.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await _handleLeaveActivity(activity.id, currentUid);
                      },
                      child: Text(
                        'Leave Activity',
                        style: AppTypography.buttonText.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

  Future<void> _handleLeaveActivity(String activityId, String currentUid) async {
    setState(() {
      _isActionInProgress = true;
    });

    final success = await ActivityRepository().leaveActivity(activityId, currentUid);

    if (mounted) {
      setState(() {
        _isActionInProgress = false;
        if (success) {
          _membershipStatus = ActivityMembershipStatus.notJoined;
        }
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You've left ${_activity.title}"),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to leave activity. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final parts = activity.subtitle.split(' · ');
    final timeStr = parts.length > 1 ? parts[1] : '8:00 PM';
    final dateStr = parts.isNotEmpty ? parts[0] : 'Today';
    final spotsLeft = activity.totalPlayers - activity.joinedPlayers;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // ── Scrollable body ──
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── 1. Blue Header with Overlapping Venue Card (ss1) ──
                SliverToBoxAdapter(
                  child: _buildHeaderWithVenueOverlay(activity, dateStr, timeStr, spotsLeft),
                ),

                // ── 2. Stats Row ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildStatsRow(activity, timeStr, dateStr, spotsLeft),
                  ),
                ),

                // ── 3. Court Photo (all activities use Pickleball court photo) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildCourtPhoto(activity),
                  ),
                ),

                // ── 4. Players Section (Screenshot 1: Vertical card with + Add & Manage) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _buildPlayersSection(activity),
                  ),
                ),

                // ── 5. Questions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _buildQuestions(),
                  ),
                ),

                // ── 7. About ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _buildAbout(activity),
                  ),
                ),

                // ── 8. Where you'll play (Map) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: _buildWhereYouPlay(),
                  ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // ── Sticky Bottom CTA ──
          _buildBottomCTA(context, activity, spotsLeft),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 1. BLUE HEADER WITH OVERLAPPING VENUE CARD (ss1)
  // ─────────────────────────────────────────
  Widget _buildHeaderWithVenueOverlay(
    ActivityModel activity,
    String dateStr,
    String timeStr,
    int spotsLeft,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Blue background extending behind the top half of the venue card
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 50,
          child: Container(
            color: AppColors.primary,
          ),
        ),

        // Foreground content: Header details + Overlapping Venue Card
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar: back + share
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _shareActivity,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.ios_share_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Title + players badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: AppTypography.headline.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFECCC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${activity.joinedPlayers}/${activity.totalPlayers} Players',
                            style: AppTypography.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Subtitle: date · time · location
                    Text(
                      '$dateStr · $timeStr · Bhavnagar',
                      style: AppTypography.bodySubtitle.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Venue card overlapping the blue boundary
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: _buildVenueCard(),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // 2. VENUE CARD
  // ─────────────────────────────────────────
  Widget _buildVenueCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bhavnagar Pickleball Arena',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bhavnagar · 2.1 km away',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(
                'Venue confirmed',
                style: AppTypography.caption.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 3. STATS ROW (4 columns)
  // ─────────────────────────────────────────
  Widget _buildStatsRow(ActivityModel activity, String timeStr, String dateStr, int spotsLeft) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          // Time
          Expanded(
            child: _statCell(
              icon: AppAssets.iconClock,
              value: timeStr,
              label: dateStr,
              labelColor: AppColors.textSecondary,
            ),
          ),
          _verticalDivider(),
          // Players
          Expanded(
            child: _statCell(
              icon: AppAssets.iconUsers,
              value: '${activity.joinedPlayers}/${activity.totalPlayers} players',
              label: '$spotsLeft spots left',
              labelColor: const Color(0xFFEA580C),
            ),
          ),
          _verticalDivider(),
          // Skill
          Expanded(
            child: _statCell(
              icon: AppAssets.iconAward,
              value: activity.skillLevel.label,
              label: 'Friendly',
              labelColor: AppColors.textSecondary,
            ),
          ),
          _verticalDivider(),
          // Price
          Expanded(
            child: _statCell(
              icon: AppAssets.iconCreditCard,
              value: activity.pricePerPerson == 0 ? 'Free' : '₹${activity.pricePerPerson}',
              label: 'per person',
              labelColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String icon,
    required String value,
    required String label,
    required Color labelColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(icon, width: 22, height: 22, color: AppColors.primary),
        const SizedBox(height: 7),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 44,
      color: const Color(0xFFEFF2F6),
    );
  }

  // ─────────────────────────────────────────
  // 4. COURT PHOTO (All activities use Pickleball Court photo)
  // ─────────────────────────────────────────
  Widget _buildCourtPhoto(ActivityModel activity) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        AppAssets.pickleballCourtsPng,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
      ),
    );
  }

  // ─────────────────────────────────────────
  // 5. PLAYERS SECTION (Screenshots 1 & 2: Real Firestore players + Host Manage button)
  // ─────────────────────────────────────────
  Widget _buildPlayersSection(ActivityModel activity) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isHostUser = _membershipStatus == ActivityMembershipStatus.host || activity.hostId == currentUid;

    final players = (activity.players != null && activity.players!.isNotEmpty)
        ? activity.players!
        : [
            PlayerModel(
              id: activity.hostId ?? 'host_1',
              name: activity.hostName?.isNotEmpty == true ? activity.hostName! : 'Host',
              role: 'HOST',
              skill: activity.skillLevel.label,
              isHost: true,
              avatarBgColor: const Color(0xFF475569),
            ),
          ];

    final displayPlayers = players.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title: "Players (8)" & "Invite Only"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Players (${activity.joinedPlayers})',
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            Row(
              children: [
                Icon(
                  activity.isInviteOnly ? Icons.lock_outline_rounded : Icons.public_rounded,
                  size: 14,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  activity.isInviteOnly ? 'Invite Only' : 'Open to All',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vertical List Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEFF2F6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              ...displayPlayers.asMap().entries.map((entry) {
                final idx = entry.key;
                final player = entry.value;
                final isLast = idx == displayPlayers.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: player.avatarBgColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              player.name.isNotEmpty ? player.name[0].toUpperCase() : 'P',
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name & Skill
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.name,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  player.skill,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // HOST Badge
                          if (player.isHost)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'HOST',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // "View all players ->" link below the list card
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayersScreen(
                  activity: activity,
                  isHostManagement: isHostUser,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Text(
                'View all players',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ],
          ),
        ),

        // "Manage players" button (HOST ONLY)
        if (isHostUser) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayersScreen(
                    activity: activity,
                    isHostManagement: true,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBDD0F8), width: 1.2),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Manage players',
                    style: AppTypography.buttonText.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }


  // ─────────────────────────────────────────
  // 7. QUESTIONS
  // ─────────────────────────────────────────
  Widget _buildQuestions() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isApprovedOrHost = _membershipStatus == ActivityMembershipStatus.host ||
        _membershipStatus == ActivityMembershipStatus.joined ||
        _activity.hostId == currentUid ||
        (_activity.participantIds != null && _activity.participantIds!.contains(currentUid));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questions',
          style: AppTypography.headline.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEFF2F6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Have a question for the group?',
                  style: AppTypography.bodySubtitle.copyWith(
                    fontSize: 13.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!isApprovedOrHost) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only host and joined participants can access the activity chat.'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF0F172A),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CommunityChatScreen(
                        communityId: _activity.id,
                        title: _activity.title,
                        membersCount: '${_activity.joinedPlayers} players',
                        avatarInitials: _activity.title.isNotEmpty ? _activity.title.substring(0, 1).toUpperCase() : 'A',
                        isActivityGroup: true,
                        onLeaveGroup: null,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Ask the group',
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // 8. ABOUT THIS ACTIVITY
  // ─────────────────────────────────────────
  Widget _buildAbout(ActivityModel activity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this activity',
          style: AppTypography.headline.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Casual ${activity.title.toLowerCase()} game for players of all levels. Come meet new people, have fun and get a game going.',
          style: AppTypography.bodySubtitle.copyWith(
            fontSize: 13.5,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        _bulletRow('Equipment:', activity.equipment.isNotEmpty ? activity.equipment : 'None'),
        const SizedBox(height: 6),
        _bulletRow('Skill level:', '${activity.skillLevel.label} friendly'),
        const SizedBox(height: 6),
        _bulletRow('Duration:', activity.durationMinutes > 0 ? '${activity.durationMinutes} min' : '~1 hour'),
        const SizedBox(height: 6),
        _bulletRow(
          'Players needed:',
          '${activity.totalPlayers - activity.joinedPlayers}',
        ),
      ],
    );
  }

  Widget _bulletRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 5, right: 10),
          decoration: const BoxDecoration(
            color: AppColors.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              TextSpan(
                text: value,
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // 9. WHERE YOU'LL PLAY
  // ─────────────────────────────────────────
  Widget _buildWhereYouPlay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where you\'ll play',
          style: AppTypography.headline.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 14),

        // Map image
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            AppAssets.mapImage,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),

        // Venue row + open in maps
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bhavnagar Pickleball Arena',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '2.1 km from you',
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _openInMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBDD0F8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Open in Maps',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // STICKY BOTTOM CTA
  // ─────────────────────────────────────────
  Widget _buildBottomCTA(BuildContext context, ActivityModel activity, int spotsLeft) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isHostUser = _membershipStatus == ActivityMembershipStatus.host || activity.hostId == currentUid;

    // HOST CTA BAR (Screenshot 1: Edit & Delete buttons)
    if (isHostUser) {
      return Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEFF2F6), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Outlined Edit Button
            Expanded(
              child: GestureDetector(
                onTap: _openEditActivity,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary, width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Edit',
                    style: AppTypography.buttonText.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Solid Red Delete Button
            Expanded(
              child: GestureDetector(
                onTap: _showDeleteConfirmationModal,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Delete',
                    style: AppTypography.buttonText.copyWith(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // NON-HOST CTA BAR (Screenshot 2 / Joined / Pending / Loading)
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEFF2F6), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price + spots
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    activity.pricePerPerson == 0 ? 'Free' : '₹${activity.pricePerPerson}',
                    style: AppTypography.headline.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (activity.pricePerPerson > 0)
                    Text(
                      ' / person',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (spotsLeft > 0)
                Text(
                  '$spotsLeft spots left',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEA580C),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Action Button depending on membership status
          Expanded(
            child: _buildActionButton(context, activity, currentUid),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ActivityModel activity, String currentUid) {
    if (_isActionInProgress) {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    switch (_membershipStatus) {
      case ActivityMembershipStatus.loading:
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            'Checking status...',
            style: AppTypography.buttonText.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        );

      case ActivityMembershipStatus.host:
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayersScreen(
                  activity: activity,
                  isHostManagement: true,
                ),
              ),
            );
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Manage Host Activity',
                  style: AppTypography.buttonText.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),
        );

      case ActivityMembershipStatus.joined:
        return GestureDetector(
          onTap: () => _showLeaveConfirmationModal(context, activity),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.exit_to_app_rounded, color: Color(0xFF475569), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Leave Activity',
                  style: AppTypography.buttonText.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );

      case ActivityMembershipStatus.pending:
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 6),
              Text(
                'Request Pending',
                style: AppTypography.buttonText.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        );

      case ActivityMembershipStatus.notJoined:
        final buttonLabel = activity.isInviteOnly ? 'Request to Join' : 'Join Game';
        return GestureDetector(
          onTap: () async {
            if (currentUid.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please log in to join activities.')),
              );
              return;
            }

            final messenger = ScaffoldMessenger.of(context);
            final nav = Navigator.of(context);

            setState(() {
              _isActionInProgress = true;
            });

            final authState = AuthController.instance.state;
            final userName = authState.displayName.isNotEmpty ? authState.displayName : 'User';
            final userUsername = authState.username.isNotEmpty ? authState.username : 'user';
            final userPhotoUrl = authState.photoUrl;

            if (activity.isInviteOnly) {
              final success = await ActivityRepository().requestToJoinActivity(
                activityId: activity.id,
                uid: currentUid,
                userName: userName,
                userUsername: userUsername,
                userPhotoUrl: userPhotoUrl,
              );

              if (mounted) {
                setState(() {
                  _isActionInProgress = false;
                });
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Join request sent to host successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Color(0xFF0F172A),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to submit join request. Please try again.'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                }
              }
            } else {
              final success = await ActivityRepository().joinActivityDirectly(
                activityId: activity.id,
                uid: currentUid,
                userName: userName,
                userUsername: userUsername,
                userPhotoUrl: userPhotoUrl,
              );

              if (mounted) {
                setState(() {
                  _isActionInProgress = false;
                });
                if (success) {
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => JoinedScreen(activity: activity),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to join activity. Please try again.'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                }
              }
            }
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonLabel,
                  style: AppTypography.buttonText.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        );
    }
  }
}
