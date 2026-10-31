import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../models/coupon_model.dart';
import '../models/venue_model.dart';
import '../services/booking_backend_service.dart';
import '../utils/app_transitions.dart';
import '../utils/booking_time_utils.dart';
import 'booking_status_screen.dart';
import 'coupon_screen.dart';

class BookingReviewScreen extends StatefulWidget {
  final VenueModel venue;
  final CourtModel court;
  final VenueSlotModel slot;

  const BookingReviewScreen({
    super.key,
    required this.venue,
    required this.court,
    required this.slot,
  });

  @override
  State<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends State<BookingReviewScreen> {
  late Razorpay _razorpay;
  bool _isLoading = false;
  String? _errorMessage;

  String? _activeBookingId;
  String? _activeRazorpayOrderId;

  CouponModel? _appliedCoupon;
  int _discountPaise = 0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('[RAZORPAY SUCCESS] Payment ID: ${response.paymentId}, Order ID: ${response.orderId}');
    if (!mounted) return;

    final bookingId = _activeBookingId;
    final orderId = response.orderId ?? _activeRazorpayOrderId;
    final paymentId = response.paymentId;
    final signature = response.signature;

    if (bookingId == null || orderId == null || paymentId == null || signature == null || signature.isEmpty) {
      _showStatusScreen(
        statusType: BookingStatusDisplayType.failure,
        message: 'Missing payment confirmation tokens or signature from gateway.',
      );
      return;
    }

    // Navigate to status screen in PROCESSING state
    Navigator.of(context).pushReplacement(
      AppTransitions.slidePageRoute(
        BookingStatusScreen(
          statusType: BookingStatusDisplayType.processing,
          bookingId: bookingId,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        ),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('[RAZORPAY ERROR] Code: ${response.code}, Message: ${response.message}');
    if (!mounted) return;
    final failedBookingId = _activeBookingId;
    if (failedBookingId != null) {
      BookingBackendService().releaseHold(bookingId: failedBookingId);
    }
    setState(() {
      _isLoading = false;
      _errorMessage = response.message != null && response.message!.isNotEmpty
          ? response.message!
          : 'Payment was cancelled or failed (Code ${response.code}).';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('[RAZORPAY WALLET] Wallet Name: ${response.walletName}');
  }

  void _showStatusScreen({
    required BookingStatusDisplayType statusType,
    required String message,
  }) {
    Navigator.of(context).pushReplacement(
      AppTransitions.slidePageRoute(
        BookingStatusScreen(
          statusType: statusType,
          bookingId: _activeBookingId ?? '',
          customMessage: message,
        ),
      ),
    );
  }

  Future<void> _openCouponScreen() async {
    HapticFeedback.lightImpact();
    final authState = AuthController.instance.state;
    final userId = authState.uid.isNotEmpty ? authState.uid : 'anonymous_user';

    final result = await Navigator.of(context).push<CouponScreenResult>(
      AppTransitions.slidePageRoute(
        CouponScreen(
          userId: userId,
          venueId: widget.venue.id,
          sportId: widget.court.sportId,
          courtPricePaise: widget.slot.pricePaise,
          bookingDate: widget.slot.date,
          currentlyAppliedCoupon: _appliedCoupon,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      if (result.isRemoved) {
        _appliedCoupon = null;
        _discountPaise = 0;
      } else if (result.appliedCoupon != null) {
        _appliedCoupon = result.appliedCoupon;
        _discountPaise = result.discountPaise;
      }
    });
  }

  void _removeAppliedCoupon() {
    HapticFeedback.lightImpact();
    setState(() {
      _appliedCoupon = null;
      _discountPaise = 0;
    });
  }

  Future<void> _startCheckout() async {
    if (_isLoading) return;
    HapticFeedback.heavyImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authState = AuthController.instance.state;
    final userId = authState.uid.isNotEmpty ? authState.uid : 'anonymous_user';
    final userName = authState.displayName.isNotEmpty ? authState.displayName : 'Tolii User';
    final userEmail = authState.email.isNotEmpty ? authState.email : 'user@tolii.app';
    final rawPhone = authState.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final userPhone = rawPhone.length > 10 && rawPhone.startsWith('91')
        ? rawPhone.substring(2)
        : (rawPhone.isNotEmpty ? rawPhone : '9999999999');

    // 1. Call Backend to place slot hold & create Razorpay Order with coupon discount applied
    final prepRes = await BookingBackendService().preparePayment(
      userId: userId,
      venue: widget.venue,
      court: widget.court,
      slot: widget.slot,
      sportId: widget.court.sportId,
      sportName: widget.court.sportId,
      couponCode: _appliedCoupon?.code,
    );

    if (!prepRes.success || prepRes.bookingId == null || prepRes.razorpayOrderId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = prepRes.message;
      });
      return;
    }

    _activeBookingId = prepRes.bookingId;
    _activeRazorpayOrderId = prepRes.razorpayOrderId;

    // 2. Validate Gateway Key from server
    final razorpayKey = prepRes.keyId;
    if (razorpayKey == null || razorpayKey.isEmpty || razorpayKey == 'rzp_test_UNCONFIGURED') {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Payment gateway key is not configured on the server. Please configure RAZORPAY_KEY_ID in server environment.';
      });
      return;
    }

    // 3. Open Razorpay Checkout Modal with exact server-calculated amount
    final finalPayablePaise = prepRes.amountPaise ?? (widget.slot.pricePaise - _discountPaise);
    final options = {
      'key': razorpayKey,
      'amount': finalPayablePaise,
      'name': 'TOLII Venues',
      'description': '${widget.venue.name} - ${widget.court.name}',
      'order_id': prepRes.razorpayOrderId,
      'timeout': 300, // 5 minutes
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'theme': {
        'color': '#063E9E',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('[Razorpay Checkout Error]: $e');
      if (!mounted) return;
      final failedBookingId = _activeBookingId;
      if (failedBookingId != null) {
        BookingBackendService().releaseHold(bookingId: failedBookingId);
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not launch payment gateway ($e). Razorpay Checkout is supported on mobile devices (Android/iOS).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final courtPriceRupees = (widget.slot.pricePaise / 100).toInt();
    final discountRupees = (_discountPaise / 100).toInt();
    final totalRupees = (courtPriceRupees - discountRupees).clamp(0, 999999);

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
          'Checkout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Notice Banner if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Card 1: Venue & Location
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              widget.venue.imageAssets.isNotEmpty
                                  ? widget.venue.imageAssets.first
                                  : '',
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 68,
                                height: 68,
                                color: const Color(0xFFEEF4FF),
                                child: const Icon(
                                  Icons.sports_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.venue.name,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        widget.venue.address,
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 12.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 2: Selected Court & Slot Schedule
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'BOOKING DETAILS',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          const SizedBox(height: 14),

                          _buildDetailRow(
                            icon: Icons.stadium_outlined,
                            label: 'Court / Arena',
                            value: widget.court.name,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.sports_cricket_outlined,
                            label: 'Sport',
                            value: widget.court.sportId,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.event_available_rounded,
                            label: 'Date',
                            value: widget.slot.date,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Time Interval',
                            value: '${widget.slot.startTime} – ${widget.slot.endTime}',
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: BookingTimeUtils.formatDuration(widget.slot.durationMinutes),
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.currency_rupee_rounded,
                            label: 'Court Rate',
                            value: '₹${(widget.court.hourlyRatePaise / 100).toInt()}/hour',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 3: Apply Coupon Section
                    GestureDetector(
                      onTap: _openCouponScreen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _appliedCoupon != null ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _appliedCoupon != null ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _appliedCoupon != null ? const Color(0xFFDCFCE7) : const Color(0xFFEEF4FF),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _appliedCoupon != null ? Icons.check_circle_rounded : Icons.local_offer_outlined,
                                color: _appliedCoupon != null ? const Color(0xFF16A34A) : AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _appliedCoupon != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_appliedCoupon!.code} Applied',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF14532D),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'You saved ₹$discountRupees with this coupon',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Apply Coupon / Promo Code',
                                          style: AppTypography.titleMedium.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Select from eligible discounts',
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            if (_appliedCoupon != null)
                              GestureDetector(
                                onTap: _removeAppliedCoupon,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Card 4: Payment Breakdown
                    Text(
                      'PAYMENT BREAKDOWN',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildPriceLine(
                            'Court Price (${BookingTimeUtils.formatDuration(widget.slot.durationMinutes)})',
                            '₹$courtPriceRupees',
                          ),
                          const SizedBox(height: 8),
                          _buildPriceLine('Convenience Charges & Taxes', '₹0', isSubdued: true),
                          if (_discountPaise > 0) ...[
                            const SizedBox(height: 8),
                            _buildPriceLine(
                              'Coupon Discount (${_appliedCoupon?.code ?? 'PROMO'})',
                              '- ₹$discountRupees',
                              highlightGreen: true,
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Amount Payable',
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '₹$totalRupees',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 5: Cancellation & Rescheduling Policy
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.venue.cancellationPolicy.isNotEmpty
                                  ? widget.venue.cancellationPolicy
                                  : 'Free cancellation up to 24 hours before your slot time. 100% refund guarantee.',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Payment Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: _isLoading ? null : _startCheckout,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _isLoading ? const Color(0xFF94A3B8) : AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isLoading
                        ? []
                        : const [
                            BoxShadow(
                              color: Color(0x35063E9E),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pay ₹$totalRupees via Razorpay',
                          style: AppTypography.buttonText.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
          value,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(
    String label,
    String value, {
    bool isSubdued = false,
    bool highlightGreen = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 13.5,
            color: highlightGreen
                ? const Color(0xFF16A34A)
                : (isSubdued ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontWeight: highlightGreen ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: highlightGreen
                ? FontWeight.w800
                : (isSubdued ? FontWeight.w500 : FontWeight.w700),
            color: highlightGreen
                ? const Color(0xFF16A34A)
                : (isSubdued ? const Color(0xFF94A3B8) : AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
