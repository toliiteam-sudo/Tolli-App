import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../models/activity_model.dart';
import '../models/activity_request_model.dart';
import '../repositories/activity_repository.dart';
import '../widgets/toli_confirmation_dialog.dart';
import '../widgets/invite_players_sheet.dart';

class PlayersScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool isHostManagement;

  const PlayersScreen({
    super.key,
    required this.activity,
    this.isHostManagement = false,
  });

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late List<PlayerModel> _playersList;
  List<ActivityRequestModel> _pendingRequests = [];
  bool _isRemoveMode = false;

  StreamSubscription<List<PlayerModel>>? _participantsSub;
  StreamSubscription<List<ActivityRequestModel>>? _requestsSub;

  @override
  void initState() {
    super.initState();
    _playersList = widget.activity.players?.isNotEmpty == true
        ? widget.activity.players!
        : _getDefaultPlayers();

    _participantsSub = ActivityRepository()
        .watchActivityParticipants(widget.activity.id)
        .listen((realParticipants) {
      if (mounted) {
        setState(() {
          _playersList = realParticipants.isNotEmpty
              ? realParticipants
              : _getDefaultPlayers();
        });
      }
    });

    _requestsSub = ActivityRepository()
        .watchActivityRequests(widget.activity.id)
        .listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests = requests.where((r) => r.status == 'pending').toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }

  List<PlayerModel> _getDefaultPlayers() {
    final hostName = widget.activity.hostName ??
        (widget.activity.hostUsername != null ? '@${widget.activity.hostUsername}' : 'Host');
    return [
      PlayerModel(
        id: widget.activity.hostId ?? 'host',
        name: hostName,
        role: 'HOST',
        skill: 'Host',
        isHost: true,
        avatarBgColor: const Color(0xFF063E9E),
      ),
    ];
  }

  void _openInviteSheet() {
    HapticFeedback.lightImpact();
    InvitePlayersBottomSheet.show(context, activity: widget.activity);
  }

  Future<void> _approveJoinRequest(ActivityRequestModel req) async {
    final bool isHost = widget.activity.isHost || widget.isHostManagement;
    if (!isHost) return;

    HapticFeedback.lightImpact();
    await ActivityRepository().respondToJoinRequest(
      activityId: widget.activity.id,
      request: req,
      accept: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Approved ${req.userName} for this game!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _declineJoinRequest(ActivityRequestModel req) async {
    final bool isHost = widget.activity.isHost || widget.isHostManagement;
    if (!isHost) return;

    HapticFeedback.lightImpact();
    await ActivityRepository().respondToJoinRequest(
      activityId: widget.activity.id,
      request: req,
      accept: false,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Declined ${req.userName}\'s request'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleRemoveMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRemoveMode = !_isRemoveMode;
    });

    if (_isRemoveMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tap on any member to remove them from the activity'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmRemovePlayer(PlayerModel player) {
    if (player.isHost) return; // Cannot remove host

    HapticFeedback.lightImpact();
    ToliConfirmationDialog.show(
      context,
      icon: Icons.person_remove_rounded,
      title: 'Remove Player',
      message: 'Are you sure you want to remove ${player.name} from this activity?',
      confirmText: 'Remove',
      isDestructive: true,
      onConfirm: () {
        setState(() {
          _playersList.removeWhere((p) => p.id == player.id);
        });
        ActivitiesController().removePlayerFromActivity(widget.activity.id, player.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${player.name} removed from activity'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spotsLeft = (widget.activity.totalPlayers - _playersList.length).clamp(0, widget.activity.totalPlayers);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Players',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 38), // Balance for back button
                ],
              ),
            ),
            const Divider(color: Color(0xFFF1F5F9), height: 1),

            // ── Roster List Content ──
            Expanded(
              child: Builder(
                builder: (context) {
                  final bool isHost = widget.activity.isHost || widget.isHostManagement;
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // 1. PENDING JOIN REQUESTS SECTION (Host Only)
                      if (isHost && _pendingRequests.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PENDING JOIN REQUESTS (${_pendingRequests.length})',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Text(
                            'Requires Approval',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pendingRequests.map((req) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBDD0F8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0284C7),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    req.userName.isNotEmpty ? req.userName[0].toUpperCase() : 'P',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        req.userName,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        req.userUsername.isNotEmpty
                                            ? '@${req.userUsername} · Wants to join'
                                            : 'Wants to join',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Decline Button
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _declineJoinRequest(req),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Decline',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Approve Button
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approveJoinRequest(req),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      'Approve',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 16),
                  ],

                  // 2. Subheader: "8 Players · 6 Open Spots" & "🔒 Invite Only"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${_playersList.length} Players',
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: '  ·  $spotsLeft Open Spots',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Invite Only',
                            style: AppTypography.caption.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Player Cards List
                  ..._playersList.map((player) {
                    final isHost = player.isHost;

                    return GestureDetector(
                      onTap: _isRemoveMode && !isHost ? () => _confirmRemovePlayer(player) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isHost ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: isHost ? 1.6 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Remove indicator icon when in remove mode
                            if (_isRemoveMode && !isHost) ...[
                              Container(
                                width: 26,
                                height: 26,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEE2E2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.remove_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                              ),
                            ],

                            // Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: player.avatarBgColor,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                player.name.isNotEmpty ? player.name[0] : 'P',
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 17,
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    player.skill,
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12.5,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isHost
                                    ? const Color(0xFFEEF4FF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                player.role,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: isHost
                                      ? AppColors.primary
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                    ],
                  );
                },
              ),
            ),

            // ── Sticky Bottom Action Bar (ONLY when Host is managing) ──
            if (widget.activity.isHost && widget.isHostManagement)
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Add Players (Outlined Blue)
                    Expanded(
                      child: GestureDetector(
                        onTap: _openInviteSheet,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Add Players',
                            style: AppTypography.buttonText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Remove (Solid Red)
                    Expanded(
                      child: GestureDetector(
                        onTap: _toggleRemoveMode,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isRemoveMode ? const Color(0xFF991B1B) : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _isRemoveMode ? 'Done' : 'Remove',
                            style: AppTypography.buttonText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
