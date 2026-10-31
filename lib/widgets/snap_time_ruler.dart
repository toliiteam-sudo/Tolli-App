import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../utils/booking_time_utils.dart';

/// A premium, fixed-selection-marker horizontal time ruler matching TOLII's reference designs.
/// Features:
/// - Fixed pixels-per-minute scale across all durations (30m, 60m, 120m, 300m).
/// - Clean triangular markers (▲──────▲) without cluttered START/END text labels.
/// - Red highlighting on the timeline axis for unavailable/occupied intervals.
/// - Taller, elegant selected-time summary with sun/moon icon and soft localized day/night gradient.
/// - Anchored start marker with smooth snapping, tap-to-select, and restrained haptic feedback.
class SnapTimeRuler extends StatefulWidget {
  final List<String> startTimes;
  final Set<String> unavailableStartTimes;
  final String selectedStartTime;
  final int durationMinutes;
  final int minDurationMinutes;
  final int maxDurationMinutes;
  final int closeMinutes;
  final ValueChanged<String> onStartTimeChanged;
  final ValueChanged<int> onDurationChanged;
  final String intervalStatus;

  /// Fixed width in pixels for each 30-minute interval (56.0 px per whole hour).
  /// Ensures standard and multi-hour durations (up to 300+ minutes) fit cleanly.
  static const double stepWidth = 28.0;

  const SnapTimeRuler({
    super.key,
    required this.startTimes,
    this.unavailableStartTimes = const {},
    required this.selectedStartTime,
    required this.durationMinutes,
    required this.minDurationMinutes,
    this.maxDurationMinutes = 360,
    required this.closeMinutes,
    required this.onStartTimeChanged,
    required this.onDurationChanged,
    required this.intervalStatus,
  });

  @override
  State<SnapTimeRuler> createState() => _SnapTimeRulerState();
}

class _SnapTimeRulerState extends State<SnapTimeRuler> {
  late ScrollController _scrollController;
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.startTimes.indexOf(widget.selectedStartTime);
    final initialOffset = (initialIndex >= 0 ? initialIndex : 0) * SnapTimeRuler.stepWidth;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignRulerToSelectedIndex(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant SnapTimeRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isProgrammaticScroll &&
        (oldWidget.selectedStartTime != widget.selectedStartTime ||
            oldWidget.durationMinutes != widget.durationMinutes)) {
      _alignRulerToSelectedIndex(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final idx = widget.startTimes.indexOf(widget.selectedStartTime);
    return idx >= 0 ? idx : 0;
  }

  int get _startMinutes => BookingTimeUtils.parseTimeToMinutes(widget.selectedStartTime);

  String get _endTime => BookingTimeUtils.calculateEndTime(widget.selectedStartTime, widget.durationMinutes);

  int get _durationSteps => (widget.durationMinutes / 30).round();

  double _calculateStartMarkerX(double viewportWidth) {
    final durationSteps = (widget.durationMinutes / 30).round();
    final intervalWidth = durationSteps * SnapTimeRuler.stepWidth;
    final defaultAnchor = (viewportWidth * 0.26).clamp(24.0, 95.0);

    if (defaultAnchor + intervalWidth > viewportWidth - 20.0) {
      return (viewportWidth - intervalWidth - 20.0).clamp(16.0, defaultAnchor);
    }
    return defaultAnchor;
  }

  void _alignRulerToSelectedIndex({bool animate = true}) {
    if (!_scrollController.hasClients || widget.startTimes.isEmpty) return;
    final targetOffset = _selectedIndex * SnapTimeRuler.stepWidth;
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    if (animate) {
      _isProgrammaticScroll = true;
      _scrollController
          .animateTo(
            clamped,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _isProgrammaticScroll = false);
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  void _snapToNearestTick() {
    if (!_scrollController.hasClients || widget.startTimes.isEmpty) return;

    final currentOffset = _scrollController.offset;
    final maxIndex = widget.startTimes.length - 1;
    final targetIndex = (currentOffset / SnapTimeRuler.stepWidth).round().clamp(0, maxIndex);
    final targetOffset = targetIndex * SnapTimeRuler.stepWidth;
    final clamped = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    final newStartTime = widget.startTimes[targetIndex];
    if (newStartTime != widget.selectedStartTime) {
      HapticFeedback.lightImpact();
      widget.onStartTimeChanged(newStartTime);
    }

    if ((currentOffset - clamped).abs() > 0.5) {
      _isProgrammaticScroll = true;
      _scrollController
          .animateTo(
            clamped,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _isProgrammaticScroll = false);
    }
  }

  void _onRulerTap(double localX, double startMarkerX) {
    if (!_scrollController.hasClients || widget.startTimes.isEmpty) return;

    final currentOffset = _scrollController.offset;
    final scrollX = currentOffset + localX;
    final maxIndex = widget.startTimes.length - 1;
    final tappedIndex = ((scrollX - startMarkerX) / SnapTimeRuler.stepWidth).round().clamp(0, maxIndex);

    final targetOffset = (tappedIndex * SnapTimeRuler.stepWidth).clamp(0.0, _scrollController.position.maxScrollExtent);
    _isProgrammaticScroll = true;
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _isProgrammaticScroll = false);

    final newStartTime = widget.startTimes[tappedIndex];
    if (newStartTime != widget.selectedStartTime) {
      HapticFeedback.lightImpact();
      widget.onStartTimeChanged(newStartTime);
    }
  }

  void _increaseDuration() {
    if (!BookingTimeUtils.canIncreaseDuration(
      currentDurationMinutes: widget.durationMinutes,
      startMinutes: _startMinutes,
      closeMinutes: widget.closeMinutes,
      maxDurationMinutes: widget.maxDurationMinutes,
    )) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onDurationChanged(widget.durationMinutes + 30);
  }

  void _decreaseDuration() {
    if (!BookingTimeUtils.canDecreaseDuration(
      currentDurationMinutes: widget.durationMinutes,
      minDurationMinutes: widget.minDurationMinutes,
    )) {
      return;
    }
    HapticFeedback.selectionClick();
    widget.onDurationChanged(widget.durationMinutes - 30);
  }

  @override
  Widget build(BuildContext context) {
    final themePeriod = BookingTimeUtils.getTimeThemePeriod(_startMinutes);
    final themeColors = _getThemeColors(themePeriod);
    final isIntervalAvailable = widget.intervalStatus == 'AVAILABLE';

    final canIncrease = BookingTimeUtils.canIncreaseDuration(
      currentDurationMinutes: widget.durationMinutes,
      startMinutes: _startMinutes,
      closeMinutes: widget.closeMinutes,
      maxDurationMinutes: widget.maxDurationMinutes,
    );

    final canDecrease = BookingTimeUtils.canDecreaseDuration(
      currentDurationMinutes: widget.durationMinutes,
      minDurationMinutes: widget.minDurationMinutes,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Taller, Elegant Selected-Time Summary (Left) + Duration Stepper (Right)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Localized Time Summary Badge with soft day/night gradient & sun/moon icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: themeColors.gradient,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: themeColors.borderColor, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            themePeriod == BookingTimeThemePeriod.night
                                ? Icons.nightlight_round
                                : (themePeriod == BookingTimeThemePeriod.evening
                                    ? Icons.wb_twilight_rounded
                                    : Icons.wb_sunny_rounded),
                            size: 14,
                            color: themeColors.primaryTextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.selectedStartTime} – $_endTime',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: themeColors.primaryTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_getPeriodLabel(themePeriod)} · ${BookingTimeUtils.formatDuration(widget.durationMinutes)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: themeColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Compact Duration Stepper: (-) 60 Mins (+)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minus Button
                    GestureDetector(
                      onTap: canDecrease ? _decreaseDuration : null,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: canDecrease ? 1.0 : 0.35,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Duration Label: e.g. "60 Mins", "120 Mins", "300 Mins"
                    Text(
                      '${widget.durationMinutes} Mins',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Plus Button
                    GestureDetector(
                      onTap: canIncrease ? _increaseDuration : null,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 140),
                        opacity: canIncrease ? 1.0 : 0.35,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Timeline with Fixed Selection Markers & Red Unavailable Segments
          ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth;
                final startMarkerX = _calculateStartMarkerX(viewportWidth);
                final endMarkerX = startMarkerX + (_durationSteps * SnapTimeRuler.stepWidth);
                const baselineY = 28.0;

                final leadingPadding = startMarkerX;
                final trailingPadding = (viewportWidth - startMarkerX).clamp(0.0, viewportWidth);
                final totalScrollWidth = leadingPadding +
                    (widget.startTimes.length * SnapTimeRuler.stepWidth) +
                    trailingPadding;

                return SizedBox(
                  height: 66,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Layer A: Horizontally Scrolling Timeline Axis (Ticks, Whole-hour labels, Red/Green baseline)
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification && notification.dragDetails != null) {
                            _isProgrammaticScroll = false;
                          } else if (notification is UserScrollNotification &&
                              notification.direction == ScrollDirection.idle) {
                            if (!_isProgrammaticScroll) {
                              _snapToNearestTick();
                            }
                          } else if (notification is ScrollEndNotification) {
                            if (!_isProgrammaticScroll) {
                              _snapToNearestTick();
                            }
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: GestureDetector(
                            onTapUp: (details) => _onRulerTap(details.localPosition.dx, startMarkerX),
                            behavior: HitTestBehavior.opaque,
                            child: CustomPaint(
                              size: Size(totalScrollWidth, 66),
                              painter: _RulerAxisPainter(
                                startTimes: widget.startTimes,
                                unavailableStartTimes: widget.unavailableStartTimes,
                                closeMinutes: widget.closeMinutes,
                                stepWidth: SnapTimeRuler.stepWidth,
                                leadingPadding: leadingPadding,
                                baselineY: baselineY,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Layer B: Fixed Selection Marker Overlay (▲───────▲)
                      // Clean triangular markers without START/END text labels matching Screenshot 3
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            size: Size(viewportWidth, 66),
                            painter: _FixedMarkerOverlayPainter(
                              startX: startMarkerX,
                              endX: endMarkerX,
                              baselineY: baselineY,
                              isAvailable: isIntervalAvailable,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getPeriodLabel(BookingTimeThemePeriod period) {
    switch (period) {
      case BookingTimeThemePeriod.morningDay:
        return 'Daytime';
      case BookingTimeThemePeriod.evening:
        return 'Evening';
      case BookingTimeThemePeriod.night:
        return 'Night';
    }
  }

  _TimePillThemeColors _getThemeColors(BookingTimeThemePeriod period) {
    switch (period) {
      case BookingTimeThemePeriod.morningDay:
        return const _TimePillThemeColors(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F2FE), Color(0xFFF4F9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: Color(0xFFD0E4FC),
          primaryTextColor: Color(0xFF0F172A),
          secondaryTextColor: Color(0xFF475569),
        );
      case BookingTimeThemePeriod.evening:
        return const _TimePillThemeColors(
          gradient: LinearGradient(
            colors: [Color(0xFFEFE9FB), Color(0xFFF8F5FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: Color(0xFFE0D4F7),
          primaryTextColor: Color(0xFF2E1A47),
          secondaryTextColor: Color(0xFF6B5880),
        );
      case BookingTimeThemePeriod.night:
        return const _TimePillThemeColors(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderColor: Color(0xFF334155),
          primaryTextColor: Colors.white,
          secondaryTextColor: Color(0xFFCBD5E1),
        );
    }
  }
}

class _TimePillThemeColors {
  final LinearGradient gradient;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const _TimePillThemeColors({
    required this.gradient,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
  });
}

/// Custom painter for the horizontally scrollable timeline axis.
/// Colors available segments in green (#00A859) and occupied/unavailable intervals in RED (#EF4444).
class _RulerAxisPainter extends CustomPainter {
  final List<String> startTimes;
  final Set<String> unavailableStartTimes;
  final int closeMinutes;
  final double stepWidth;
  final double leadingPadding;
  final double baselineY;

  static const Color baselineGreen = Color(0xFF00A859);
  static const Color baselineRed = Color(0xFFEF4444);

  _RulerAxisPainter({
    required this.startTimes,
    required this.unavailableStartTimes,
    required this.closeMinutes,
    required this.stepWidth,
    required this.leadingPadding,
    required this.baselineY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Axis Segments: RED for occupied/unavailable intervals, GREEN for available
    for (int i = 0; i < startTimes.length; i++) {
      final x1 = leadingPadding + (i * stepWidth);
      final x2 = leadingPadding + ((i + 1) * stepWidth);
      final isSlotUnavailable = unavailableStartTimes.contains(startTimes[i]);

      final segmentPaint = Paint()
        ..color = isSlotUnavailable ? baselineRed : baselineGreen
        ..strokeWidth = isSlotUnavailable ? 2.4 : 2.0;

      canvas.drawLine(
        Offset(x1, baselineY),
        Offset(x2, baselineY),
        segmentPaint,
      );
    }

    // Baseline extension before the first slot
    final leadPaint = Paint()
      ..color = baselineGreen
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(leadingPadding, baselineY),
      leadPaint,
    );

    // 2. Draw Time Labels and Vertical Ticks
    for (int i = 0; i < startTimes.length; i++) {
      final x = leadingPadding + (i * stepWidth);
      final timeStr = startTimes[i];
      final isWholeHour = timeStr.contains(':00');
      final isSlotUnavailable = unavailableStartTimes.contains(timeStr);

      if (isWholeHour) {
        // Whole Hour Label (e.g. "8:00 PM", "9:00 PM", "10:00 PM")
        final textPainter = TextPainter(
          text: TextSpan(
            text: timeStr,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isSlotUnavailable ? const Color(0xFFDC2626) : const Color(0xFF475569),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(x - (textPainter.width / 2), baselineY - 20),
        );

        // Whole Hour Tick Mark on baseline
        final tickPaint = Paint()
          ..color = isSlotUnavailable ? const Color(0xFFEF4444) : const Color(0xFF64748B)
          ..strokeWidth = 1.3;
        canvas.drawLine(
          Offset(x, baselineY - 5),
          Offset(x, baselineY),
          tickPaint,
        );
      } else {
        // Half-Hour Tick Mark
        final halfTickPaint = Paint()
          ..color = isSlotUnavailable ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1)
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(x, baselineY - 3.5),
          Offset(x, baselineY),
          halfTickPaint,
        );
      }
    }

    // 3. Draw Closing Tick and Label at end of operating hours
    if (startTimes.isNotEmpty) {
      final closingX = leadingPadding + (startTimes.length * stepWidth);
      final closeTimeStr = BookingTimeUtils.formatMinutesToTime(closeMinutes);
      final isCloseWholeHour = closeTimeStr.contains(':00');

      final closeTickPaint = Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = isCloseWholeHour ? 1.3 : 1.0;
      canvas.drawLine(
        Offset(closingX, isCloseWholeHour ? baselineY - 5 : baselineY - 3.5),
        Offset(closingX, baselineY),
        closeTickPaint,
      );

      if (isCloseWholeHour) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: closeTimeStr,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(closingX - (textPainter.width / 2), baselineY - 20),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerAxisPainter oldDelegate) {
    return oldDelegate.startTimes != startTimes ||
        oldDelegate.unavailableStartTimes != unavailableStartTimes ||
        oldDelegate.stepWidth != stepWidth ||
        oldDelegate.leadingPadding != leadingPadding ||
        oldDelegate.baselineY != baselineY ||
        oldDelegate.closeMinutes != closeMinutes;
  }
}

/// Custom painter for the fixed-position selection markers overlay (▲───────▲).
/// Draws clean upward triangle markers without START/END text labels matching Screenshot 3.
class _FixedMarkerOverlayPainter extends CustomPainter {
  final double startX;
  final double endX;
  final double baselineY;
  final bool isAvailable;

  static const Color markerDark = Color(0xFF1E293B);
  static const Color markerUnavailable = Color(0xFFDC2626);

  _FixedMarkerOverlayPainter({
    required this.startX,
    required this.endX,
    required this.baselineY,
    required this.isAvailable,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activeColor = isAvailable ? markerDark : markerUnavailable;

    // 1. Highlight Active Interval on the Baseline
    final activeBaselinePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.4;
    canvas.drawLine(
      Offset(startX, baselineY),
      Offset(endX, baselineY),
      activeBaselinePaint,
    );

    // 2. Horizontal Bar connecting the bases of the two triangles
    final barPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(startX, baselineY + 11),
      Offset(endX, baselineY + 11),
      barPaint,
    );

    // 3. Start Triangle (▲) pointing upward to baseline
    _drawUpwardTriangle(
      canvas: canvas,
      x: startX,
      apexY: baselineY + 2.5,
      baseY: baselineY + 11,
      color: activeColor,
    );

    // 4. End Triangle (▲) pointing upward to baseline
    _drawUpwardTriangle(
      canvas: canvas,
      x: endX,
      apexY: baselineY + 2.5,
      baseY: baselineY + 11,
      color: activeColor,
    );
  }

  void _drawUpwardTriangle({
    required Canvas canvas,
    required double x,
    required double apexY,
    required double baseY,
    required Color color,
  }) {
    final path = Path()
      ..moveTo(x, apexY)
      ..lineTo(x - 5.0, baseY)
      ..lineTo(x + 5.0, baseY)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FixedMarkerOverlayPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.baselineY != baselineY ||
        oldDelegate.isAvailable != isAvailable;
  }
}
