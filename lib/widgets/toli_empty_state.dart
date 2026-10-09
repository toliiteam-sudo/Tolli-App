import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../widgets/custom_button.dart';

class ToliEmptyState extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? primaryCtaText;
  final VoidCallback? onPrimaryCtaPressed;
  final String? secondaryCtaText;
  final VoidCallback? onSecondaryCtaPressed;
  final IconData mainIcon;
  final IconData? badgeIcon1;
  final IconData? badgeIcon2;

  const ToliEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryCtaText,
    this.onPrimaryCtaPressed,
    this.secondaryCtaText,
    this.onSecondaryCtaPressed,
    this.mainIcon = Icons.sports_basketball_rounded,
    this.badgeIcon1 = Icons.location_on_rounded,
    this.badgeIcon2 = Icons.star_rounded,
  });

  /// Factory for Explore / Nearby Activities screen when no activities exist
  factory ToliEmptyState.explore({
    Key? key,
    VoidCallback? onCreateActivity,
    VoidCallback? onRefresh,
  }) {
    return ToliEmptyState(
      key: key,
      title: 'Nothing happening nearby yet',
      subtitle: 'Find a game, activity, or group around you — or be the one who starts it.',
      primaryCtaText: 'Create an Activity',
      onPrimaryCtaPressed: onCreateActivity,
      secondaryCtaText: 'Refresh',
      onSecondaryCtaPressed: onRefresh,
      mainIcon: Icons.explore_rounded,
      badgeIcon1: Icons.sports_cricket_rounded,
      badgeIcon2: Icons.groups_rounded,
    );
  }

  /// Factory for Upcoming Games tab
  factory ToliEmptyState.upcoming({
    Key? key,
    VoidCallback? onCreateActivity,
    VoidCallback? onExplore,
  }) {
    return ToliEmptyState(
      key: key,
      title: 'No upcoming games',
      subtitle: 'Join a game or create one to get started.',
      primaryCtaText: 'Create Activity',
      onPrimaryCtaPressed: onCreateActivity,
      secondaryCtaText: 'Explore Activities',
      onSecondaryCtaPressed: onExplore,
      mainIcon: Icons.calendar_today_rounded,
      badgeIcon1: Icons.sports_tennis_rounded,
      badgeIcon2: Icons.add_circle_outline_rounded,
    );
  }

  /// Factory for Joined Games tab
  factory ToliEmptyState.joined({
    Key? key,
    VoidCallback? onExplore,
  }) {
    return ToliEmptyState(
      key: key,
      title: 'No joined games yet',
      subtitle: 'Find something you want to play and join in.',
      primaryCtaText: 'Explore Activities',
      onPrimaryCtaPressed: onExplore,
      mainIcon: Icons.groups_rounded,
      badgeIcon1: Icons.sports_soccer_rounded,
      badgeIcon2: Icons.near_me_rounded,
    );
  }

  /// Factory for Hosted Games tab
  factory ToliEmptyState.hosted({
    Key? key,
    VoidCallback? onCreateActivity,
  }) {
    return ToliEmptyState(
      key: key,
      title: "You haven't hosted a game yet",
      subtitle: 'Create your first activity and bring people together.',
      primaryCtaText: 'Create Activity',
      onPrimaryCtaPressed: onCreateActivity,
      mainIcon: Icons.workspace_premium_rounded,
      badgeIcon1: Icons.sports_cricket_rounded,
      badgeIcon2: Icons.people_outline_rounded,
    );
  }

  @override
  State<ToliEmptyState> createState() => _ToliEmptyStateState();
}

class _ToliEmptyStateState extends State<ToliEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Subtle Animated TOLI Vector Illustration
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer soft pulsing aura ring
                      Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      // Inner soft ring
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                      // Central White Card Badge
                      Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDBEAFE),
                              width: 2.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10063E9E),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.mainIcon,
                            color: AppColors.primary,
                            size: 38,
                          ),
                        ),
                      ),

                      // Orbiting Floating Badge 1 (Top Left)
                      if (widget.badgeIcon1 != null)
                        Positioned(
                          top: 14 + _floatAnim.value * 0.8,
                          left: 12,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              widget.badgeIcon1,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ),

                      // Orbiting Floating Badge 2 (Bottom Right)
                      if (widget.badgeIcon2 != null)
                        Positioned(
                          bottom: 14 - _floatAnim.value * 0.8,
                          right: 12,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF4FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              widget.badgeIcon2,
                              color: AppColors.primary,
                              size: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            // 2. Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 8),

            // 3. Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 26),

            // 4. Primary CTA Button
            if (widget.primaryCtaText != null && widget.onPrimaryCtaPressed != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: CustomButton(
                  text: widget.primaryCtaText!,
                  height: 48,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onPrimaryCtaPressed!();
                  },
                ),
              ),

            // 5. Secondary CTA Button
            if (widget.secondaryCtaText != null && widget.onSecondaryCtaPressed != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onSecondaryCtaPressed!();
                },
                child: Text(
                  widget.secondaryCtaText!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
