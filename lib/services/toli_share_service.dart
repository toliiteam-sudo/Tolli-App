import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/activity_model.dart';

/// Centralized Reusable Sharing Service for TOLII App
class ToliShareService {
  ToliShareService._();

  /// Gets appropriate emoji for sport/activity title
  static String _getSportEmoji(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('pickleball')) return '🏸';
    if (lower.contains('cricket')) return '🏏';
    if (lower.contains('badminton')) return '🏸';
    if (lower.contains('football') || lower.contains('soccer')) return '⚽';
    if (lower.contains('cycling') || lower.contains('bike')) return '🚴';
    if (lower.contains('basketball')) return '🏀';
    if (lower.contains('running') || lower.contains('marathon')) return '🏃';
    if (lower.contains('café') || lower.contains('cafe')) return '☕';
    return '⚽';
  }

  /// 1. Share Activity
  static Future<void> shareActivity(BuildContext context, ActivityModel activity) async {
    HapticFeedback.lightImpact();
    final parts = activity.subtitle.split(' · ');
    final dateStr = parts.isNotEmpty ? parts[0] : 'Today';
    final timeStr = parts.length > 1 ? parts[1] : '6:30 PM';
    final venue = activity.venueName ?? 'Bhavnagar Arena';
    final location = activity.venueLocation ?? 'Bhavnagar';
    final emoji = _getSportEmoji(activity.title);

    final shareText = '''Join me for ${activity.title} on TOLII $emoji

${activity.title}
$dateStr · $timeStr
$venue, $location

Join the activity on TOLII:
https://tolii.app/activity/${activity.id}''';

    await shareTextRaw(
      context,
      text: shareText,
      subject: 'Join me for ${activity.title} on TOLII',
    );
  }

  /// 2. Invite Players to Activity
  static Future<void> invitePlayers(BuildContext context, ActivityModel? activity) async {
    HapticFeedback.lightImpact();
    final title = activity?.title ?? 'Sports Match';
    final parts = (activity?.subtitle ?? 'Today · 6:30 PM').split(' · ');
    final dateStr = parts.isNotEmpty ? parts[0] : 'Today';
    final timeStr = parts.length > 1 ? parts[1] : '6:30 PM';
    final venue = activity?.venueName ?? 'Local Venue';
    final location = activity?.venueLocation ?? 'Bhavnagar';
    final actId = activity?.id ?? '123';
    final emoji = _getSportEmoji(title);

    final inviteText = '''You're invited to join my $title on TOLII! $emoji

$dateStr · $timeStr
$venue, $location

Join here:
https://tolii.app/activity/$actId''';

    await shareTextRaw(
      context,
      text: inviteText,
      subject: 'You\'re invited to $title on TOLII',
    );
  }

  /// 3. Share Profile
  static Future<void> shareProfile(
    BuildContext context, {
    required String name,
    required String username,
    String? location,
  }) async {
    HapticFeedback.lightImpact();
    final userLoc = location ?? 'Bhavnagar, India';

    final shareText = '''Check out $name on TOLII! 👤

@$username
$userLoc

Connect on TOLII:
https://tolii.app/user/$username''';

    await shareTextRaw(
      context,
      text: shareText,
      subject: 'Connect with $name on TOLII',
    );
  }

  /// 4. Share Community / Squad
  static Future<void> shareCommunity(
    BuildContext context, {
    required String name,
    required String description,
    String? handle,
  }) async {
    HapticFeedback.lightImpact();
    final communityHandle = (handle ?? name.toLowerCase().replaceAll(' ', '-')).replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '');

    final shareText = '''Join $name on TOLII! 👥

$description

Join the squad:
https://tolii.app/community/$communityHandle''';

    await shareTextRaw(
      context,
      text: shareText,
      subject: 'Join $name on TOLII',
    );
  }

  /// 5. Share Venue / Location
  static Future<void> shareVenue(
    BuildContext context, {
    required String name,
    required String address,
    double? rating,
    String? venueId,
  }) async {
    HapticFeedback.lightImpact();
    final id = venueId ?? name.toLowerCase().replaceAll(' ', '-');
    final ratingStr = rating != null ? 'Rating: ⭐ $rating\n' : '';

    final shareText = '''Check out $name on TOLII! 🏟️

Location: $address
$ratingStr
View venue on TOLII:
https://tolii.app/venue/$id''';

    await shareTextRaw(
      context,
      text: shareText,
      subject: 'Check out $name on TOLII',
    );
  }

  /// 6. Copy Link to Clipboard with subtle SnackBar feedback
  static Future<void> copyLink(
    BuildContext context, {
    required String url,
    String message = 'Link copied',
  }) async {
    HapticFeedback.lightImpact();
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        showSnackBar(context, message: message);
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, message: 'Could not copy link');
      }
    }
  }

  /// 7. Generic Raw Text Share Helper via Native System Share Sheet
  static Future<void> shareTextRaw(
    BuildContext context, {
    required String text,
    String? subject,
  }) async {
    try {
      // ignore: deprecated_member_use
      final result = await Share.share(
        text,
        subject: subject,
      );

      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        showSnackBar(context, message: "Couldn't open sharing");
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, message: "Couldn't open sharing");
      }
    }
  }

  /// Helper for displaying premium TOLII SnackBars
  static void showSnackBar(BuildContext context, {required String message}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
