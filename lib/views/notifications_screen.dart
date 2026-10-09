import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../controllers/notification_controller.dart';
import '../models/activity_request_model.dart';
import '../models/notification_model.dart';
import '../repositories/activity_repository.dart';
import '../utils/app_transitions.dart';
import '../widgets/toli_empty_state.dart';
import '../widgets/toli_refresh_indicator.dart';
import 'activity_detail_screen.dart';

class NotificationItemModel {
  final String id;
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isUnread;
  final String? activityId;
  final bool isJoinRequest;
  final String? requestStatus; // 'PENDING', 'APPROVED', 'DECLINED'
  final String? requesterName;

  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.isUnread = true,
    this.activityId,
    this.isJoinRequest = false,
    this.requestStatus,
    this.requesterName,
  });

  NotificationItemModel copyWith({
    bool? isUnread,
    String? requestStatus,
  }) {
    return NotificationItemModel(
      id: id,
      title: title,
      body: body,
      time: time,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      isUnread: isUnread ?? this.isUnread,
      activityId: activityId,
      isJoinRequest: isJoinRequest,
      requestStatus: requestStatus ?? this.requestStatus,
      requesterName: requesterName,
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _markAllAsRead(BuildContext context) async {
    HapticFeedback.lightImpact();
    await NotificationController.instance.markAllAsRead();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications marked as read.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _approveRequest(BuildContext context, NotificationModel item) async {
    HapticFeedback.lightImpact();
    if (item.relatedActivityId != null && item.senderId != null) {
      await ActivityRepository().respondToJoinRequest(
        activityId: item.relatedActivityId!,
        request: ActivityRequestModel(
          uid: item.senderId!,
          activityId: item.relatedActivityId!,
          userName: item.senderName ?? 'Player',
          userUsername: '',
        ),
        accept: true,
      );
    }
    await NotificationController.instance.markAsRead(item.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved ${item.senderName ?? 'player'}\'s request!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _declineRequest(BuildContext context, NotificationModel item) async {
    HapticFeedback.lightImpact();
    if (item.relatedActivityId != null && item.senderId != null) {
      await ActivityRepository().respondToJoinRequest(
        activityId: item.relatedActivityId!,
        request: ActivityRequestModel(
          uid: item.senderId!,
          activityId: item.relatedActivityId!,
          userName: item.senderName ?? 'Player',
          userUsername: '',
        ),
        accept: false,
      );
    }
    await NotificationController.instance.markAsRead(item.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Declined ${item.senderName ?? 'player'}\'s request'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _onNotificationTap(BuildContext context, NotificationModel item) async {
    HapticFeedback.lightImpact();
    await NotificationController.instance.markAsRead(item.id);

    if (item.relatedActivityId != null && context.mounted) {
      final controller = ActivitiesController();
      final all = [...controller.userActivities, ...controller.activities];
      final matches = all.where((a) => a.id == item.relatedActivityId).toList();

      if (matches.isNotEmpty) {
        Navigator.of(context).push(
          AppTransitions.slidePageRoute(
            ActivityDetailScreen(activity: matches.first),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'join_request':
        return Icons.person_add_rounded;
      case 'request_accepted':
        return Icons.check_circle_rounded;
      case 'request_rejected':
        return Icons.cancel_rounded;
      case 'new_activity':
        return Icons.sports_cricket_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'join_request':
        return const Color(0xFF0284C7);
      case 'request_accepted':
        return const Color(0xFF16A34A);
      case 'request_rejected':
        return const Color(0xFFDC2626);
      case 'new_activity':
        return const Color(0xFFD97706);
      default:
        return AppColors.primary;
    }
  }

  Color _getIconBgColor(String type) {
    switch (type) {
      case 'join_request':
        return const Color(0xFFE0F2FE);
      case 'request_accepted':
        return const Color(0xFFDCFCE7);
      case 'request_rejected':
        return const Color(0xFFFEE2E2);
      case 'new_activity':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFEEF4FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationController.instance,
      builder: (context, _) {
        final notifications = NotificationController.instance.notifications;
        final hasUnread = NotificationController.instance.hasUnread;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                // Top Nav Bar
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
                          'Notifications',
                          style: AppTypography.headline.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (hasUnread)
                        GestureDetector(
                          onTap: () => _markAllAsRead(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF4FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Read all',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 38),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),

                // Notifications List
                Expanded(
                  child: ToliRefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: notifications.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: ToliEmptyState(
                              title: 'No notifications yet',
                              subtitle: "You're all caught up! Updates about your activities and join requests will appear here.",
                              mainIcon: Icons.notifications_none_rounded,
                            ),
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            itemCount: notifications.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
                            itemBuilder: (ctx, idx) {
                              final item = notifications[idx];
                              final isUnread = !item.isRead;
                              final isJoinRequest = item.type == 'join_request';
                              final status = item.requestStatus ?? 'PENDING';

                              return GestureDetector(
                                onTap: () => _onNotificationTap(context, item),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isUnread ? const Color(0xFFBDD0F8) : const Color(0xFFE2E8F0),
                                      width: isUnread ? 1.4 : 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isUnread ? 0.04 : 0.01),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Icon
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _getIconBgColor(item.type),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          _getIconForType(item.type),
                                          color: _getIconColor(item.type),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Text Content & Action Buttons
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.title,
                                                    style: AppTypography.titleMedium.copyWith(
                                                      fontSize: 14.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatTime(item.createdAt),
                                                  style: AppTypography.caption.copyWith(
                                                    fontSize: 11.5,
                                                    color: isUnread ? AppColors.primary : const Color(0xFF94A3B8),
                                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.body,
                                              style: AppTypography.caption.copyWith(
                                                fontSize: 12.5,
                                                height: 1.35,
                                                color: const Color(0xFF475569),
                                              ),
                                            ),

                                            // Inline Action Buttons for Join Requests
                                            if (isJoinRequest) ...[
                                              if (status == 'PENDING') ...[
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () => _approveRequest(context, item),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.primary,
                                                          borderRadius: BorderRadius.circular(10),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: AppColors.primary.withValues(alpha: 0.25),
                                                              blurRadius: 6,
                                                              offset: const Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Approve',
                                                              style: AppTypography.buttonText.copyWith(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w800,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),

                                                    GestureDetector(
                                                      onTap: () => _declineRequest(context, item),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                                        ),
                                                        child: Text(
                                                          'Decline',
                                                          style: AppTypography.buttonText.copyWith(
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFF475569),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ] else if (status == 'APPROVED') ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Approved',
                                                        style: AppTypography.caption.copyWith(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF16A34A),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else if (status == 'DECLINED') ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.cancel_rounded, size: 14, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Declined',
                                                        style: AppTypography.caption.copyWith(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Unread Blue Dot
                                      if (isUnread && !isJoinRequest) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
