import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/activity_model.dart';

class DateSelectorStrip extends StatefulWidget {
  final List<DateItemModel> dates;
  final int selectedIndex;
  final ValueChanged<int> onDateSelected;
  final VoidCallback? onMonthTap;
  final String? monthText;

  const DateSelectorStrip({
    super.key,
    required this.dates,
    required this.selectedIndex,
    required this.onDateSelected,
    this.onMonthTap,
    this.monthText,
  });

  @override
  State<DateSelectorStrip> createState() => _DateSelectorStripState();
}

class _DateSelectorStripState extends State<DateSelectorStrip> {
  late final ScrollController _scrollController;
  int _visibleMonthIndex = 0;

  static const List<String> _monthAbbr = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC'
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _updateVisibleMonth();
  }

  @override
  void didUpdateWidget(covariant DateSelectorStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToIndex(widget.selectedIndex);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    const itemWidth = 48.0; // 44 width + 4 separator
    final offset = _scrollController.offset;
    final index = (offset / itemWidth).round().clamp(0, widget.dates.length - 1);
    if (index != _visibleMonthIndex) {
      setState(() {
        _visibleMonthIndex = index;
      });
    }
  }

  void _updateVisibleMonth() {
    if (widget.dates.isNotEmpty && widget.selectedIndex < widget.dates.length) {
      _visibleMonthIndex = widget.selectedIndex;
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients || !_scrollController.position.hasContentDimensions) return;
    const itemWidth = 48.0;
    final targetOffset = (index * itemWidth) - 96.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _currentMonthLabel() {
    if (widget.monthText != null && widget.monthText!.isNotEmpty) {
      return widget.monthText!;
    }
    if (widget.dates.isEmpty) return 'AUG';
    final idx = _visibleMonthIndex.clamp(0, widget.dates.length - 1);
    final monthNumber = widget.dates[idx].date.month;
    return _monthAbbr[(monthNumber - 1) % 12];
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _currentMonthLabel();

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Month Badge (AUG/SEP/OCT rotated 90 degrees counter-clockwise, clickable)
          GestureDetector(
            onTap: widget.onMonthTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEF8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  currentMonth,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Date Pills List
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.dates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final dateItem = widget.dates[index];
                final isSelected = index == widget.selectedIndex;

                return GestureDetector(
                  onTap: () => widget.onDateSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateItem.dayName,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            dateItem.dayNumber,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 14.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
