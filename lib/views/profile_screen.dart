import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/activity_model.dart';
import '../widgets/toli_confirmation_dialog.dart';
import '../widgets/toli_header.dart';
import '../widgets/toli_refresh_indicator.dart';
import '../utils/app_transitions.dart';
import 'activity_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'my_games_screen.dart';
import 'welcome_screen.dart';
import '../widgets/profile_fitness_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _openEditProfile() async {
    HapticFeedback.lightImpact();
    final state = AuthController.instance.state;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      AppTransitions.slidePageRoute(
        EditProfileScreen(
          initialFirstName: state.firstName,
          initialLastName: state.lastName,
          initialUsername: state.username,
          initialEmail: state.email,
          initialPhone: state.phoneNumber,
          initialLocation: state.selectedCity.isNotEmpty ? state.selectedCity : 'Bhavnagar, India',
          initialGender: state.gender ?? 'Male',
          initialProfileImagePath: state.profileImagePath,
          initialInterestedActivities: state.selectedInterests,
        ),
      ),
    );

    if (result != null && mounted) {
      await AuthController.instance.saveProfile(
        firstName: result['firstName'],
        lastName: result['lastName'],
        email: result['email'],
        phone: result['phone'],
        location: result['location'],
        gender: result['gender'],
        profileImagePath: result['profileImagePath'],
        interestedActivities: result['interestedActivities'] != null
            ? List<String>.from(result['interestedActivities'])
            : null,
      );
      setState(() {});
    }
  }

  void _openActivityDetail(ActivityModel activity) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        ActivityDetailScreen(activity: activity),
      ),
    );
  }

  void _showLogoutDialog() {
    HapticFeedback.heavyImpact();
    ToliConfirmationDialog.show(
      context,
      icon: Icons.logout_rounded,
      title: 'Log Out',
      message: 'Are you sure you want to log out of Tolii?',
      confirmText: 'Log Out',
      isDestructive: true,
      onConfirm: () async {
        await AuthController.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ActivitiesController();

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
        child: ListenableBuilder(
          listenable: AuthController.instance,
          builder: (context, _) {
            final authState = AuthController.instance.state;
            final fullName = authState.displayName;
            final username = authState.username.isNotEmpty ? authState.username : 'user';
            final location = authState.selectedCity.isNotEmpty ? authState.selectedCity : 'Bhavnagar, India';
            final localPath = authState.profileImagePath;
            final networkUrl = authState.effectiveAvatarUrl;
            final interestedActivities = authState.selectedInterests;

            Widget avatarWidget;
            if (localPath != null && localPath.isNotEmpty && File(localPath).existsSync()) {
              avatarWidget = Image.file(
                File(localPath),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              );
            } else if (networkUrl != null && networkUrl.isNotEmpty && networkUrl.startsWith('http')) {
              avatarWidget = Image.network(
                networkUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: AppTypography.headline.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              );
            } else {
              avatarWidget = Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                style: AppTypography.headline.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              );
            }

            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final userGames = controller.userActivities;

                return ToliRefreshIndicator(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Top Header Bar (Using global ToliHeader)
                        ToliHeader(
                          title: 'My Profile',
                          subtitle: location.split(',').first.trim(),
                          showAvatar: false,
                          customAction: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openEditProfile,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.settings_outlined,
                                size: 22,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. User Identity Card (Screenshot 1: Soft Light Blue Background Card)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              // Avatar Circle
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2563EB),
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: ClipOval(child: avatarWidget),
                              ),
                              const SizedBox(width: 14),

                              // User Info (Name, Handle, Location)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: AppTypography.titleLarge.copyWith(
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 13,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          size: 14,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          location,
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. MY SPORTS Section (Screenshot 1)
                        Text(
                          'MY SPORTS',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: interestedActivities.map((sport) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                                ),
                                child: Text(
                                  sport,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: 20),

                  // 4. Active Level Card (Screenshot 1)
                  Container(
                    padding: const EdgeInsets.all(16),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Level',
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActiveLevelItem(
                              icon: Icons.local_fire_department_outlined,
                              label: 'Warming up',
                              isActive: false,
                            ),
                            _buildActiveLevelItem(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Active',
                              isActive: true,
                            ),
                            _buildActiveLevelItem(
                              icon: Icons.local_fire_department_outlined,
                              label: 'Super Active',
                              isActive: false,
                            ),
                            _buildActiveLevelItem(
                              icon: Icons.local_fire_department_outlined,
                              label: 'On fire',
                              isActive: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Indicator Bar
                        Stack(
                          children: [
                            Container(
                              height: 5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2F6),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: 0.45,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Fitness Section
                  const ProfileFitnessCard(),
                  const SizedBox(height: 20),

                  // 6. Upcoming Games (Screenshot 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Games',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MyGamesScreen()),
                          );
                        },
                        child: Text(
                          'See all',
                          style: AppTypography.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Games List Cards
                  ...userGames.map((game) {
                    final parts = game.subtitle.split(' · ');
                    final timeText = parts.length > 1 ? '${parts[0]} · ${parts[1]}' : game.subtitle;
                    final venueText = game.venueName ?? (parts.length > 2 ? parts[2] : 'Bhavnagar Arena');
                    final progress = game.progress;

                    return GestureDetector(
                      onTap: () => _openActivityDetail(game),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Sport Icon Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF4FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Image.asset(
                                    game.iconAsset,
                                    fit: BoxFit.contain,
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.sports_cricket_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Title & Time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        game.title,
                                        style: AppTypography.titleMedium.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        timeText,
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
                            const SizedBox(height: 10),

                            // Venue Row
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  venueText,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            const SizedBox(height: 10),

                            // Players & Progress
                            Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 20,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF94A3B8),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Positioned(
                                        left: 10,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${game.joinedPlayers}/${game.totalPlayers} players',
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),

                                Container(
                                  width: 80,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2F6),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progress.clamp(0.05, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),

                  // 7. Recent Activity (Screenshot 1)
                  Text(
                    'Recent Activity',
                    style: AppTypography.headline.copyWith(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentActivityItem(
                    icon: Icons.emoji_events_outlined,
                    iconBgColor: const Color(0xFFE6F7F0),
                    iconColor: const Color(0xFF10B981),
                    title: 'Won a Football match',
                    subtitle: '3 days ago',
                  ),
                  const SizedBox(height: 10),
                  _buildRecentActivityItem(
                    icon: Icons.groups_outlined,
                    iconBgColor: const Color(0xFFEEF4FF),
                    iconColor: const Color(0xFF2563EB),
                    title: 'Joined Pickleball group',
                    subtitle: '1 week ago',
                  ),
                  const SizedBox(height: 28),

                  // 8. Solid Red Log Out Button (Screenshot 1)
                  GestureDetector(
                    onTap: _showLogoutDialog,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Log Out',
                        style: AppTypography.buttonText.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                ],
              ),
            ),
          );
        },
      );
    },
  ),
),
),
);
}

  Widget _buildActiveLevelItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : const Color(0xFF94A3B8),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.primary : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }
}
