import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/booking_model.dart';
import '../services/booking_backend_service.dart';
import '../utils/app_transitions.dart';
import '../utils/booking_time_utils.dart';
import 'create_activity_screen.dart';
import 'home_screen.dart';
import 'my_bookings_screen.dart';

enum BookingStatusDisplayType {
  processing,
  success,
  pending,
  failure,
  slotUnavailable,
}

class BookingStatusScreen extends StatefulWidget {
  final BookingStatusDisplayType statusType;
  final String bookingId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? customMessage;

  const BookingStatusScreen({
    super.key,
    required this.statusType,
    required this.bookingId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.customMessage,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  late BookingStatusDisplayType _currentStatus;
  BookingModel? _confirmedBooking;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.statusType;
    _statusMessage = widget.customMessage;

    if (_currentStatus == BookingStatusDisplayType.processing) {
      _verifyPaymentWithBackend();
    }
  }

  Future<void> _verifyPaymentWithBackend() async {
    final res = await BookingBackendService().verifyPayment(
      bookingId: widget.bookingId,
      razorpayOrderId: widget.razorpayOrderId ?? '',
      razorpayPaymentId: widget.razorpayPaymentId ?? '',
      razorpaySignature: widget.razorpaySignature ?? '',
    );

    if (!mounted) return;

    if (res.success) {
      setState(() {
        _currentStatus = BookingStatusDisplayType.success;
        _confirmedBooking = res.booking;
        _statusMessage = res.message;
      });
    } else {
      setState(() {
        _currentStatus = BookingStatusDisplayType.pending;
        _statusMessage = res.message;
      });
    }
  }

  void _openMyBookings() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(const MyBookingsScreen()),
    );
  }

  void _openCreateGame() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        CreateActivityScreen(
          prefilledBooking: _confirmedBooking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Status Icon Badge
              _buildStatusIcon(),
              const SizedBox(height: 24),

              // Title
              Text(
                _getStatusTitle(),
                style: AppTypography.headline.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle / Description Message
              Text(
                _statusMessage ?? _getStatusSubtitle(),
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Confirmed Booking Details Summary Card
              if (_currentStatus == BookingStatusDisplayType.success &&
                  _confirmedBooking != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSummaryLine('Booking Reference', _confirmedBooking!.bookingId),
                      const SizedBox(height: 8),
                      _buildSummaryLine('Venue', _confirmedBooking!.venueName),
                      const SizedBox(height: 8),
                      _buildSummaryLine('Court', _confirmedBooking!.courtName),
                      const SizedBox(height: 8),
                      _buildSummaryLine(
                        'Date & Time',
                        '${_confirmedBooking!.bookingDate} · ${_confirmedBooking!.startTime} – ${_confirmedBooking!.endTime}',
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryLine(
                        'Duration',
                        BookingTimeUtils.formatDuration(_confirmedBooking!.durationMinutes),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryLine(
                        'Amount Paid',
                        '₹${_confirmedBooking!.finalAmountRupees.toInt()}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Spacer(),

              // Action Buttons Stack
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_currentStatus) {
      case BookingStatusDisplayType.processing:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFEEF4FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3.5,
            ),
          ),
        );
      case BookingStatusDisplayType.success:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFE6F7F0),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: Color(0xFF10B981),
          ),
        );
      case BookingStatusDisplayType.pending:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBEB),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.hourglass_top_rounded,
            size: 48,
            color: Color(0xFFF59E0B),
          ),
        );
      case BookingStatusDisplayType.failure:
      case BookingStatusDisplayType.slotUnavailable:
        return Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFFFEF2F2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.cancel_rounded,
            size: 52,
            color: Color(0xFFDC2626),
          ),
        );
    }
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case BookingStatusDisplayType.processing:
        return 'Verifying Your Payment...';
      case BookingStatusDisplayType.success:
        return 'Booking Confirmed!';
      case BookingStatusDisplayType.pending:
        return 'Confirming Payment';
      case BookingStatusDisplayType.failure:
        return 'Payment Not Completed';
      case BookingStatusDisplayType.slotUnavailable:
        return 'Slot No Longer Available';
    }
  }

  String _getStatusSubtitle() {
    switch (_currentStatus) {
      case BookingStatusDisplayType.processing:
        return 'Please wait while we verify your transaction with the bank and lock your slot.';
      case BookingStatusDisplayType.success:
        return 'Your court reservation is locked and ready. See you at the venue!';
      case BookingStatusDisplayType.pending:
        return 'We are verifying your transaction. If money was debited, your booking will be confirmed shortly.';
      case BookingStatusDisplayType.failure:
        return 'The payment attempt was not completed. You can safely try booking again.';
      case BookingStatusDisplayType.slotUnavailable:
        return 'Another user just booked this slot. Please select a different time.';
    }
  }

  Widget _buildSummaryLine(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          val,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_currentStatus == BookingStatusDisplayType.processing) {
      return const SizedBox.shrink();
    }

    if (_currentStatus == BookingStatusDisplayType.success) {
      return Column(
        children: [
          // Create Game optional button (Flow C)
          GestureDetector(
            onTap: _openCreateGame,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Find Players for This Booking',
                    style: AppTypography.buttonText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Primary View My Bookings Button
          GestureDetector(
            onTap: _openMyBookings,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30063E9E),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'View My Bookings',
                style: AppTypography.buttonText.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Default return to home button for failure / pending
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          'Return to Venues',
          style: AppTypography.buttonText.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
