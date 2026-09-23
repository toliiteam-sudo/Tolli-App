import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../views/notifications_screen.dart';
import '../views/profile_screen.dart';

class ToliHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarInitial;
  final Color avatarColor;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final bool showNotification;
  final bool showAvatar;
  final bool? hasUnreadNotification;
  final Widget? customAction;

  const ToliHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.avatarInitial,
    this.avatarColor = AppColors.avatarGreen,
    this.onNotificationTap,
    this.onAvatarTap,
    this.showNotification = true,
    this.showAvatar = true,
    this.hasUnreadNotification,
    this.customAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthController.instance,
        NotificationController.instance,
      ]),
      builder: (context, _) {
        final effectiveHasUnread =
            hasUnreadNotification ?? NotificationController.instance.hasUnread;
        final authState = AuthController.instance.state;
        final userDisplayName = authState.displayName;
        final userFirstName = authState.firstName.isNotEmpty
            ? authState.firstName
            : (userDisplayName.split(' ').first.isNotEmpty
                ? userDisplayName.split(' ').first
                : 'User');

        String effectiveTitle = title;
        if (title == 'Hey Vatsal!' || title.startsWith('Hey ')) {
          effectiveTitle = 'Hey $userFirstName!';
        }

        final initialChar = (avatarInitial != null && avatarInitial!.isNotEmpty)
            ? avatarInitial![0].toUpperCase()
            : (userDisplayName.isNotEmpty ? userDisplayName[0].toUpperCase() : 'U');

        final localImagePath = authState.profileImagePath;
        final networkAvatarUrl = authState.effectiveAvatarUrl;

        Widget avatarWidget;
        if (localImagePath != null &&
            localImagePath.isNotEmpty &&
            File(localImagePath).existsSync()) {
          avatarWidget = Image.file(
            File(localImagePath),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          );
        } else if (networkAvatarUrl != null &&
            networkAvatarUrl.isNotEmpty &&
            networkAvatarUrl.startsWith('http')) {
          avatarWidget = Image.network(
            networkAvatarUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildInitialsAvatar(initialChar),
          );
        } else {
          avatarWidget = _buildInitialsAvatar(initialChar);
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title & Subtitle Group
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    effectiveTitle,
                    style: AppTypography.headline.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySubtitle.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Action Buttons Group (Notification Bell & Profile Avatar)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (customAction != null) ...[
                  customAction!,
                  const SizedBox(width: 10),
                ],

                // Notification Bell Button
                if (showNotification)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onNotificationTap != null) {
                        onNotificationTap!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      }
                    },
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                size: 26,
                                color: AppColors.primary,
                              ),
                              if (effectiveHasUnread)
                                Positioned(
                                  top: 0,
                                  right: 1,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (showNotification && showAvatar) const SizedBox(width: 14),

                // Profile Avatar Button
                if (showAvatar)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onAvatarTap != null) {
                        onAvatarTap!();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: ClipOval(child: avatarWidget),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInitialsAvatar(String initialChar) {
    return Center(
      child: Text(
        initialChar,
        style: AppTypography.titleMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }
}
