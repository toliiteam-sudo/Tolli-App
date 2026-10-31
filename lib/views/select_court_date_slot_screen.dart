import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/activity_model.dart';
import '../models/venue_model.dart';
import '../repositories/venue_repository.dart';
import '../utils/app_transitions.dart';
import '../utils/booking_time_utils.dart';
import '../widgets/date_picker_bottom_sheet.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/toli_empty_state.dart';
import 'booking_review_screen.dart';

/// TOLII — Minimal, Premium, and Logically Perfect Venue Booking Screen.
/// Follows the 5-section hierarchy:
/// A. Compact Date Selector
/// B. Court Selection
/// C. Booking Duration
/// D. Available Start Times (Clean 3-column Grid)
/// E. Sticky Booking Summary ("Continue")
class SelectCourtDateSlotScreen extends StatefulWidget {
  final VenueModel venue;

  const SelectCourtDateSlotScreen({
    super.key,
    required this.venue,
  });

  @override
  State<SelectCourtDateSlotScreen> createState() => _SelectCourtDateSlotScreenState();
}

class _SelectCourtDateSlotScreenState extends State<SelectCourtDateSlotScreen> {
  final VenueRepository _venueRepo = VenueRepository();

  late CourtModel _selectedCourt;
  late DateTime _selectedDate;
  int _selectedDurationMinutes = 60;
  String? _selectedStartTime;
  VenueSlotModel? _selectedSlot;
  List<VenueSlotModel>? _latestSlots;

  late List<DateTime> _availableDates;
  late Stream<List<VenueSlotModel>> _slotsStream;

  @override
  void initState() {
    super.initState();
    _selectedCourt = widget.venue.courts.isNotEmpty
        ? widget.venue.courts.first
        : const CourtModel(
            id: 'default_court',
            name: 'Court 1',
            sportId: 'Sports',
            capacity: 10,
            surfaceType: 'Turf',
            hourlyRatePaise: 60000,
          );

    final minMin = _selectedCourt.minBookingMinutes > 0 ? _selectedCourt.minBookingMinutes : 30;
    _selectedDurationMinutes = minMin > 30 ? minMin : 60;

    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _availableDates = List.generate(14, (i) => _selectedDate.add(Duration(days: i)));
    _updateSlotsStream();
  }

  void _updateSlotsStream() {
    _slotsStream = _venueRepo.streamSlots(
      venueId: widget.venue.id,
      court: _selectedCourt,
      dateStr: _formatDateString(_selectedDate),
      operatingHours: widget.venue.operatingHours,
    ).map((slots) {
      _latestSlots = slots;
      _revalidateSelectedStartTime();
      return slots;
    });
  }

  String _formatDateString(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<DateItemModel> _buildDateItems() {
    const dayAbbrs = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return _availableDates.map((d) {
      final dayName = dayAbbrs[(d.weekday - 1) % 7];
      final isSelected = d.year == _selectedDate.year &&
          d.month == _selectedDate.month &&
          d.day == _selectedDate.day;
      return DateItemModel(
        dayName: dayName,
        dayNumber: '${d.day}',
        date: d,
        isSelected: isSelected,
      );
    }).toList();
  }

  int get _selectedDateIndex {
    final idx = _availableDates.indexWhere((d) =>
        d.year == _selectedDate.year &&
        d.month == _selectedDate.month &&
        d.day == _selectedDate.day);
    return idx >= 0 ? idx : 0;
  }

  List<int> _getSupportedDurations() {
    final minMin = _selectedCourt.minBookingMinutes > 0 ? _selectedCourt.minBookingMinutes : 30;
    final opHours = BookingTimeUtils.parseOperatingHours(widget.venue.operatingHours);
    final totalWindow = opHours.closeMinutes - opHours.openMinutes;

    final List<int> candidates = [30, 60, 90, 120, 180];
    return candidates.where((d) => d >= minMin && d <= totalWindow).toList();
  }

  String _formatDurationLabel(int minutes) {
    if (minutes == 30) return '30 min';
    if (minutes == 60) return '1 hour';
    if (minutes == 90) return '1.5 hours';
    if (minutes == 120) return '2 hours';
    if (minutes == 150) return '2.5 hours';
    if (minutes == 180) return '3 hours';
    return BookingTimeUtils.formatDuration(minutes);
  }

  Future<void> _openDatePicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerBottomSheet(initialDate: _selectedDate),
    );

    if (result != null && result['date'] != null && result['date'] is DateTime) {
      final DateTime chosen = result['date'];
      setState(() {
        _selectedDate = DateTime(chosen.year, chosen.month, chosen.day);
        if (!_availableDates.any((d) =>
            d.year == _selectedDate.year &&
            d.month == _selectedDate.month &&
            d.day == _selectedDate.day)) {
          _availableDates.insert(0, _selectedDate);
        }
        _selectedStartTime = null;
        _selectedSlot = null;
        _updateSlotsStream();
      });
    }
  }

  void _onDateSelected(DateTime date) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDate = date;
      _selectedStartTime = null;
      _selectedSlot = null;
      _updateSlotsStream();
    });
  }

  void _onCourtSelected(CourtModel court) {
    if (_selectedCourt.id == court.id) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCourt = court;
      _selectedStartTime = null;
      _selectedSlot = null;
      final supported = _getSupportedDurations();
      if (!supported.contains(_selectedDurationMinutes)) {
        _selectedDurationMinutes = supported.isNotEmpty ? supported.first : 60;
      }
      _updateSlotsStream();
    });
  }

  void _onDurationSelected(int duration) {
    if (_selectedDurationMinutes == duration) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDurationMinutes = duration;
      _revalidateSelectedStartTime();
    });
  }

  void _revalidateSelectedStartTime() {
    if (_selectedStartTime == null || _latestSlots == null) {
      _selectedSlot = null;
      return;
    }
    final opHours = BookingTimeUtils.parseOperatingHours(widget.venue.operatingHours);
    final status = VenueRepository.evaluateIntervalStatus(
      granularSlots: _latestSlots!,
      startTime: _selectedStartTime!,
      durationMinutes: _selectedDurationMinutes,
      closeMinutes: opHours.closeMinutes,
    );
    if (status == 'AVAILABLE') {
      _selectedSlot = VenueRepository.createCompositeSlot(
        court: _selectedCourt,
        venueId: widget.venue.id,
        dateStr: _formatDateString(_selectedDate),
        startTime: _selectedStartTime!,
        durationMinutes: _selectedDurationMinutes,
      );
    } else {
      // Clear previously selected start time if it is no longer valid for the updated duration
      _selectedStartTime = null;
      _selectedSlot = null;
    }
  }

  void _onStartTimeSelected(String time, bool isAvailable, String status) {
    if (!isAvailable) {
      HapticFeedback.lightImpact();
      String message = 'This time slot is unavailable.';
      if (status == 'BOOKED') {
        message = 'This time is already booked for ${_formatDurationLabel(_selectedDurationMinutes)}.';
      } else if (status == 'HELD') {
        message = 'This time is currently on hold. Please choose another slot.';
      } else if (status == 'EXCEEDS_CLOSING') {
        final op = BookingTimeUtils.parseOperatingHours(widget.venue.operatingHours);
        message = 'Exceeds venue closing time (${BookingTimeUtils.formatMinutesToTime(op.closeMinutes)}).';
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _selectedStartTime = time;
      _selectedSlot = VenueRepository.createCompositeSlot(
        court: _selectedCourt,
        venueId: widget.venue.id,
        dateStr: _formatDateString(_selectedDate),
        startTime: time,
        durationMinutes: _selectedDurationMinutes,
      );
    });
  }

  void _proceedToReview() async {
    if (_selectedSlot == null) return;
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        BookingReviewScreen(
          venue: widget.venue,
          court: _selectedCourt,
          slot: _selectedSlot!,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _updateSlotsStream();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
          ),
          leading: Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          title: const Text(
            'Select Date & Time',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Stack(
        children: [
          // Main Scrollable Booking Content
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 110 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section A: Compact Date Selector
                  _buildDateSelectorSection(),
                  const Divider(height: 28, thickness: 1, color: Color(0xFFF1F5F9)),

                  // Section B: Court Selection
                  _buildCourtSelectionSection(),
                  const Divider(height: 28, thickness: 1, color: Color(0xFFF1F5F9)),

                  // Section C: Booking Duration
                  _buildDurationSection(),
                  const Divider(height: 28, thickness: 1, color: Color(0xFFF1F5F9)),

                  // Section D: Available Start Times (3-Column Grid)
                  StreamBuilder<List<VenueSlotModel>>(
                    stream: _slotsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return ToliEmptyState(
                          title: 'Unable to Load Slots',
                          subtitle: 'Could not fetch slot availability. Please try again.',
                          mainIcon: Icons.wifi_off_rounded,
                          primaryCtaText: 'Retry',
                          onPrimaryCtaPressed: () {
                            setState(() {
                              _updateSlotsStream();
                            });
                          },
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }

                      final slots = snapshot.data ?? [];
                      _latestSlots = slots;
                      return _buildStartTimeGridSection(slots);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Section E: Sticky Booking Summary ("Continue")
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyFooter(bottomInset),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ==========================================
  // SECTION A: COMPACT DATE SELECTOR
  // ==========================================
  Widget _buildDateSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'SELECT DATE',
          trailing: GestureDetector(
            onTap: _openDatePicker,
            behavior: HitTestBehavior.opaque,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DateSelectorStrip(
          dates: _buildDateItems(),
          selectedIndex: _selectedDateIndex,
          onDateSelected: (index) => _onDateSelected(_availableDates[index]),
          onMonthTap: _openDatePicker,
        ),
      ],
    );
  }

  // ==========================================
  // SECTION B: COURT SELECTION
  // ==========================================
  Widget _buildCourtSelectionSection() {
    final courts = widget.venue.courts;
    if (courts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'COURT SELECTION',
          trailing: Text(
            courts.length == 1 ? '1 court' : '${courts.length} courts',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (courts.length == 1)
          _buildSingleCourtCard(courts.first)
        else
          _buildMultiCourtHorizontalList(courts),
      ],
    );
  }

  Widget _buildSingleCourtCard(CourtModel court) {
    final hourlyRupees = (court.hourlyRatePaise / 100).toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x4D063E9E), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.stadium_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  court.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${court.sportId} · ${court.surfaceType}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$hourlyRupees/hr',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Standard rate',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiCourtHorizontalList(List<CourtModel> courts) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: courts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final court = courts[index];
          final isSelected = court.id == _selectedCourt.id;
          final hourlyRupees = (court.hourlyRatePaise / 100).toInt();

          return GestureDetector(
            onTap: () => _onCourtSelected(court),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 154,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.6 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? const Color(0x14063E9E) : const Color(0x06000000),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.stadium_outlined,
                          size: 16,
                          color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        court.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${court.sportId} · ${court.surfaceType}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Text(
                    '₹$hourlyRupees/hr',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // SECTION C: BOOKING DURATION
  // ==========================================
  Widget _buildDurationSection() {
    final durations = _getSupportedDurations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'BOOKING DURATION',
          trailing: Text(
            _formatDurationLabel(_selectedDurationMinutes),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: durations.map((duration) {
            final isSelected = duration == _selectedDurationMinutes;
            final label = _formatDurationLabel(duration);

            return GestureDetector(
              onTap: () => _onDurationSelected(duration),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    if (isSelected)
                      const BoxShadow(
                        color: Color(0x10063E9E),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : const Color(0xFF334155),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==========================================
  // SECTION D: AVAILABLE START TIMES (3-COLUMN GRID)
  // ==========================================
  Widget _buildStartTimeGridSection(List<VenueSlotModel> slots) {
    if (slots.isEmpty) {
      return ToliEmptyState(
        title: 'No Slots Available',
        subtitle: 'No slots found for this date. Please choose another date or court.',
        mainIcon: Icons.event_busy_rounded,
        primaryCtaText: 'Select Another Date',
        onPrimaryCtaPressed: _openDatePicker,
      );
    }

    final opHours = BookingTimeUtils.parseOperatingHours(widget.venue.operatingHours);

    // Evaluate interval availability for each start time based on the active duration
    final List<({VenueSlotModel slot, bool isAvailable, String status})> evaluatedSlots = [];
    int availableCount = 0;

    for (final s in slots) {
      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: s.startTime,
        durationMinutes: _selectedDurationMinutes,
        closeMinutes: opHours.closeMinutes,
      );
      final isAvailable = status == 'AVAILABLE';
      if (isAvailable) availableCount++;
      evaluatedSlots.add((slot: s, isAvailable: isAvailable, status: status));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'AVAILABLE START TIMES',
          trailing: Text(
            availableCount > 0 ? '$availableCount available' : 'None available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: availableCount > 0 ? const Color(0xFF64748B) : const Color(0xFFEF4444),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedStartTime == null
              ? 'Select a start time for your ${_formatDurationLabel(_selectedDurationMinutes)} session'
              : 'Selected: $_selectedStartTime – ${BookingTimeUtils.calculateEndTime(_selectedStartTime!, _selectedDurationMinutes)} (${BookingTimeUtils.formatDurationCompact(_selectedDurationMinutes)})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: _selectedStartTime != null ? FontWeight.w600 : FontWeight.w500,
            color: _selectedStartTime != null ? AppColors.primary : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),

        if (availableCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Column(
              children: [
                const Icon(Icons.schedule_outlined, size: 28, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No available slots for ${_formatDurationLabel(_selectedDurationMinutes)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Try choosing a shorter duration, a different court, or another date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: evaluatedSlots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 44,
            ),
            itemBuilder: (context, index) {
              final item = evaluatedSlots[index];
              final time = item.slot.startTime;
              final isSelected = time == _selectedStartTime;
              final isAvailable = item.isAvailable;

              return _buildStartTimeButton(
                time: time,
                isSelected: isSelected,
                isAvailable: isAvailable,
                status: item.status,
              );
            },
          ),
      ],
    );
  }

  Widget _buildStartTimeButton({
    required String time,
    required bool isSelected,
    required bool isAvailable,
    required String status,
  }) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    FontWeight fontWeight;
    List<BoxShadow> shadows = [];

    if (isSelected) {
      backgroundColor = AppColors.primary;
      borderColor = AppColors.primary;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
      shadows = const [
        BoxShadow(
          color: Color(0x28063E9E),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];
    } else if (isAvailable) {
      backgroundColor = Colors.white;
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF0F172A);
      fontWeight = FontWeight.w600;
    } else {
      backgroundColor = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFE2E8F0);
      textColor = const Color(0xFF94A3B8);
      fontWeight = FontWeight.w500;
    }

    return GestureDetector(
      onTap: () => _onStartTimeSelected(time, isAvailable, status),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1.0),
          boxShadow: shadows,
        ),
        child: Text(
          time,
          style: TextStyle(
            fontSize: 13,
            fontWeight: fontWeight,
            color: textColor,
            letterSpacing: -0.2,
            decoration: (!isAvailable && !isSelected) ? TextDecoration.lineThrough : null,
            decorationColor: const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SECTION E: STICKY BOOKING SUMMARY ("Continue")
  // ==========================================
  Widget _buildStickyFooter(double bottomInset) {
    final hasSelection = _selectedSlot != null;
    final displayStart = _selectedSlot?.startTime;
    final displayEnd = _selectedSlot?.endTime;
    final totalPaise = BookingTimeUtils.calculateCourtPricePaise(
      hourlyRatePaise: _selectedCourt.hourlyRatePaise,
      durationMinutes: _selectedDurationMinutes,
    );
    final totalRupees = (totalPaise / 100).toInt();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Booking details summary & price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasSelection) ...[
                  const Text(
                    'Select a start time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDurationLabel(_selectedDurationMinutes)} · ₹$totalRupees · ${_selectedCourt.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '$displayStart – $displayEnd',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${BookingTimeUtils.formatDurationCompact(_selectedDurationMinutes)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹$totalRupees',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '· ${_selectedCourt.name}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right: Primary "Continue" Action
          GestureDetector(
            onTap: hasSelection ? _proceedToReview : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: BoxDecoration(
                color: hasSelection ? AppColors.primary : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: hasSelection ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
