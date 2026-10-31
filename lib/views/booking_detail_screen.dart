import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/booking_model.dart';
import '../services/booking_backend_service.dart';
import '../utils/app_transitions.dart';
import '../utils/booking_time_utils.dart';
import '../widgets/toli_confirmation_dialog.dart';
import 'create_activity_screen.dart';
import 'location_map_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late BookingModel _currentBooking;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
  }

  void _openDirections() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationMapScreen(
          venueName: _currentBooking.venueName,
          address: _currentBooking.venueAddress,
          latitude: 21.7645,
          longitude: 72.1519,
        ),
      ),
    );
  }

  void _openCreateGame() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        CreateActivityScreen(prefilledBooking: _currentBooking),
      ),
    );
  }

  void _confirmCancellation() {
    HapticFeedback.heavyImpact();

    // Calculate server time refund estimate preview
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursRemaining = (_currentBooking.startTimestamp - now) / (1000 * 60 * 60);

    String refundEstimateText = 'Full refund (100%) will be processed to your original payment method.';
    if (hoursRemaining < 24 && hoursRemaining >= 12) {
      refundEstimateText = '50% refund (₹${(_currentBooking.finalAmountRupees * 0.5).toInt()}) will be processed according to cancellation policy.';
    } else if (hoursRemaining < 12) {
      refundEstimateText = 'No refund is eligible as cancellation is within 12 hours of the slot start time.';
    }

    ToliConfirmationDialog.show(
      context,
      icon: Icons.cancel_outlined,
      title: 'Cancel Booking',
      message: 'Are you sure you want to cancel your reservation for ${_currentBooking.venueName}?\n\n$refundEstimateText',
      confirmText: 'Confirm Cancellation',
      isDestructive: true,
      onConfirm: _processCancellation,
    );
  }

  Future<void> _processCancellation() async {
    setState(() {
      _isCancelling = true;
    });

    final res = await BookingBackendService().cancelBooking(
      bookingId: _currentBooking.bookingId,
      userId: _currentBooking.userId,
    );

    if (!mounted) return;

    setState(() {
      _isCancelling = false;
    });

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _currentBooking;

    Color statusBg = const Color(0xFFE6F7F0);
    Color statusText = const Color(0xFF10B981);
    String statusLabel = 'CONFIRMED';

    switch (booking.bookingStatus) {
      case BookingStatus.confirmed:
        statusBg = const Color(0xFFE6F7F0);
        statusText = const Color(0xFF10B981);
        statusLabel = 'CONFIRMED';
        break;
      case BookingStatus.held:
        statusBg = const Color(0xFFFFFBEB);
        statusText = const Color(0xFFD97706);
        statusLabel = 'HELD';
        break;
      case BookingStatus.completed:
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF64748B);
        statusLabel = 'COMPLETED';
        break;
      case BookingStatus.cancelled:
      case BookingStatus.refundPending:
      case BookingStatus.refunded:
        statusBg = const Color(0xFFFEF2F2);
        statusText = const Color(0xFFDC2626);
        statusLabel = 'CANCELLED';
        break;
      case BookingStatus.pending:
        statusBg = const Color(0xFFEFF6FF);
        statusText = const Color(0xFF2563EB);
        statusLabel = 'PENDING';
        break;
    }

    final isUpcoming = booking.bookingStatus == BookingStatus.confirmed &&
        booking.startTimestamp > DateTime.now().millisecondsSinceEpoch;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textDark,
            ),
          ),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Ref Header Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BOOKING REFERENCE',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          booking.bookingId,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: statusText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Venue Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.stadium_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.venueName,
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                booking.venueAddress,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 12.5,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _openDirections,
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Get Directions on Map',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Slot Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRow(Icons.stadium_outlined, 'Court', booking.courtName),
                    const SizedBox(height: 10),
                    _buildRow(Icons.sports_cricket_outlined, 'Sport', booking.sportName),
                    const SizedBox(height: 10),
                    _buildRow(Icons.calendar_today_rounded, 'Date', booking.bookingDate),
                    const SizedBox(height: 10),
                    _buildRow(Icons.access_time_rounded, 'Time', '${booking.startTime} – ${booking.endTime}'),
                    const SizedBox(height: 10),
                    _buildRow(Icons.timer_outlined, 'Duration', BookingTimeUtils.formatDuration(booking.durationMinutes)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Breakdown Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYMENT DETAILS',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPriceRow('Amount Paid', '₹${booking.finalAmountRupees.toInt()}'),
                    const SizedBox(height: 6),
                    _buildPriceRow('Payment Status', booking.paymentStatus, isSubdued: true),
                    if (booking.razorpayPaymentId != null) ...[
                      const SizedBox(height: 6),
                      _buildPriceRow('Razorpay Txn ID', booking.razorpayPaymentId!, isSubdued: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions: Create Game & Cancel Booking
              if (booking.bookingStatus == BookingStatus.confirmed) ...[
                GestureDetector(
                  onTap: _openCreateGame,
                  child: Container(
                    width: double.infinity,
                    height: 50,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Game from Booking',
                          style: AppTypography.buttonText.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (isUpcoming) ...[
                GestureDetector(
                  onTap: _isCancelling ? null : _confirmCancellation,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    alignment: Alignment.center,
                    child: _isCancelling
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Color(0xFFDC2626),
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Cancel Booking',
                            style: AppTypography.buttonText.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
        const Spacer(),
        Text(
          val,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String val, {bool isSubdued = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            color: isSubdued ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          val,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: isSubdued ? FontWeight.w500 : FontWeight.w700,
            color: isSubdued ? const Color(0xFF64748B) : AppColors.primary,
          ),
        ),
      ],
    );
  }
}
