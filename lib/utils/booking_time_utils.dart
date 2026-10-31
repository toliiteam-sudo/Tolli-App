/// Time and duration utility functions for TOLII booking system.
/// Supports 30-minute slot intervals, multi-hour durations, operating hours validation,
/// and trusted price calculation in integer paise.
class BookingTimeUtils {
  BookingTimeUtils._();

  /// Parse time string (e.g., "06:00 AM", "6:30 AM", "10:30 PM", "11:00 PM")
  /// into minutes from midnight (0 .. 1439).
  static int parseTimeToMinutes(String timeStr) {
    final cleaned = timeStr.trim().toUpperCase();
    final parts = cleaned.split(' ');
    if (parts.isEmpty) return 0;

    final timeParts = parts[0].split(':');
    int hour = int.tryParse(timeParts[0]) ?? 0;
    int minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;

    if (parts.length > 1) {
      final period = parts[1];
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
    }

    return hour * 60 + minute;
  }

  /// Format minutes from midnight (e.g. 630 -> "10:30 AM")
  static String formatMinutesToTime(int minutes) {
    int totalMinutes = minutes % (24 * 60);
    if (totalMinutes < 0) totalMinutes += 24 * 60;

    int hour24 = totalMinutes ~/ 60;
    int minute = totalMinutes % 60;

    String period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr $period';
  }

  /// Calculate end time string given start time and duration in minutes
  static String calculateEndTime(String startTime, int durationMinutes) {
    final startMin = parseTimeToMinutes(startTime);
    final endMin = startMin + durationMinutes;
    return formatMinutesToTime(endMin);
  }

  /// Parse venue operating hours (e.g., "06:00 AM - 11:00 PM")
  /// Returns a record with openMinutes and closeMinutes
  static ({int openMinutes, int closeMinutes}) parseOperatingHours(String operatingHoursStr) {
    try {
      final parts = operatingHoursStr.split('-');
      if (parts.length == 2) {
        final open = parseTimeToMinutes(parts[0].trim());
        final close = parseTimeToMinutes(parts[1].trim());
        return (openMinutes: open, closeMinutes: close);
      }
    } catch (_) {}
    // Default operating hours: 06:00 AM to 11:00 PM
    return (openMinutes: 360, closeMinutes: 1380);
  }

  /// Format duration for display (e.g. 30 -> "30 mins", 60 -> "1 hour", 90 -> "1.5 hours", 120 -> "2 hours")
  static String formatDuration(int durationMinutes) {
    if (durationMinutes < 60) {
      return '$durationMinutes mins';
    }
    final hours = durationMinutes / 60.0;
    if (hours == hours.truncateToDouble()) {
      final h = hours.toInt();
      return h == 1 ? '1 hour' : '$h hours';
    }
    return '${hours.toStringAsFixed(1)} hours';
  }

  /// Format duration compact (e.g. 30 -> "30 min", 60 -> "1 hr", 90 -> "1.5 hr", 120 -> "2 hr")
  static String formatDurationCompact(int durationMinutes) {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes / 60.0;
    if (hours == hours.truncateToDouble()) {
      final h = hours.toInt();
      return '$h hr';
    }
    return '${hours.toStringAsFixed(1)} hr';
  }

  /// Check if interval [startMin, endMin) fits within operating hours [openMin, closeMin]
  /// Note: Ending exactly at closeMin is VALID.
  static bool isIntervalWithinOperatingHours({
    required int startMinutes,
    required int durationMinutes,
    required int openMinutes,
    required int closeMinutes,
  }) {
    if (durationMinutes <= 0) return false;
    final endMinutes = startMinutes + durationMinutes;
    return startMinutes >= openMinutes && endMinutes <= closeMinutes;
  }

  /// Check if two time intervals overlap: [startA, endA) and [startB, endB)
  static bool doIntervalsOverlap(int startA, int endA, int startB, int endB) {
    return startA < endB && startB < endA;
  }

  /// Calculate trusted court price in integer paise
  static int calculateCourtPricePaise({
    required int hourlyRatePaise,
    required int durationMinutes,
  }) {
    if (durationMinutes <= 0 || hourlyRatePaise <= 0) return 0;
    return ((hourlyRatePaise * durationMinutes) / 60.0).round();
  }

  /// Generate start times in 30-minute intervals between openMinutes and closeMinutes
  static List<String> generateStartTimes({
    required int openMinutes,
    required int closeMinutes,
    int intervalMinutes = 30,
    int minDurationMinutes = 30,
  }) {
    final List<String> times = [];
    // Start times can go up to closeMinutes - minDurationMinutes
    for (int m = openMinutes; m <= (closeMinutes - minDurationMinutes); m += intervalMinutes) {
      times.add(formatMinutesToTime(m));
    }
    return times;
  }

  /// Generate DateTime epoch ms from dateStr ("YYYY-MM-DD") and minutes from midnight
  static int getTimestampMs(String dateStr, int minutesFromMidnight) {
    try {
      final parts = dateStr.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      final hours = minutesFromMidnight ~/ 60;
      final mins = minutesFromMidnight % 60;
      return DateTime(y, m, d, hours, mins).millisecondsSinceEpoch;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch;
    }
  }

  /// Determine the daytime / nighttime theme based on the booking start time minutes
  /// - Morning/day: 06:00 AM (360m) to 04:59 PM (1019m)
  /// - Evening: 05:00 PM (1020m) to 07:59 PM (1199m)
  /// - Night: 08:00 PM (1200m) to 05:59 AM (359m)
  static BookingTimeThemePeriod getTimeThemePeriod(int minutesFromMidnight) {
    final normalized = (minutesFromMidnight % (24 * 60) + (24 * 60)) % (24 * 60);
    if (normalized >= 360 && normalized < 1020) {
      return BookingTimeThemePeriod.morningDay;
    } else if (normalized >= 1020 && normalized < 1200) {
      return BookingTimeThemePeriod.evening;
    } else {
      return BookingTimeThemePeriod.night;
    }
  }

  /// Map an arbitrary scroll offset to the nearest discrete minute index
  static int snapOffsetToTickIndex({
    required double scrollOffset,
    required double stepWidth,
    required int maxIndex,
    double horizontalPadding = 0.0,
  }) {
    if (stepWidth <= 0 || maxIndex <= 0) return 0;
    final unpadded = scrollOffset - horizontalPadding;
    final nearest = (unpadded / stepWidth).round();
    return nearest.clamp(0, maxIndex);
  }

  /// Can duration be increased without exceeding closing time or max duration limit?
  static bool canIncreaseDuration({
    required int currentDurationMinutes,
    required int startMinutes,
    required int closeMinutes,
    int stepMinutes = 30,
    int maxDurationMinutes = 360,
  }) {
    final nextDuration = currentDurationMinutes + stepMinutes;
    if (nextDuration > maxDurationMinutes) return false;
    return (startMinutes + nextDuration) <= closeMinutes;
  }

  /// Can duration be decreased without going below minimum booking duration?
  static bool canDecreaseDuration({
    required int currentDurationMinutes,
    required int minDurationMinutes,
    int stepMinutes = 30,
  }) {
    final prevDuration = currentDurationMinutes - stepMinutes;
    return prevDuration >= minDurationMinutes && prevDuration > 0;
  }
}

/// Day / Night theme classification for the time ruler panel
enum BookingTimeThemePeriod {
  morningDay,
  evening,
  night,
}
