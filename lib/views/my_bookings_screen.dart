import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../models/booking_model.dart';
import '../repositories/booking_repository.dart';
import '../utils/app_transitions.dart';
import '../utils/booking_time_utils.dart';
import '../widgets/toli_empty_state.dart';
import '../widgets/toli_refresh_indicator.dart';
import 'booking_detail_screen.dart';
import 'create_activity_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookingRepository _bookingRepo = BookingRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBookingDetail(BookingModel booking) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        BookingDetailScreen(booking: booking),
      ),
    );
  }

  void _openCreateGame(BookingModel booking) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        CreateActivityScreen(prefilledBooking: booking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthController.instance.state.uid;

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
          'My Bookings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTypography.caption.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<BookingModel>>(
          stream: _bookingRepo.streamUserBookings(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final allBookings = snapshot.data ?? [];
            final nowMs = DateTime.now().millisecondsSinceEpoch;

            final upcomingBookings = allBookings.where((b) {
              return (b.bookingStatus == BookingStatus.confirmed ||
                      b.bookingStatus == BookingStatus.held) &&
                  b.endTimestamp >= nowMs;
            }).toList();

            final pastBookings = allBookings.where((b) {
              return b.bookingStatus == BookingStatus.completed ||
                  (b.bookingStatus == BookingStatus.confirmed &&
                      b.endTimestamp < nowMs);
            }).toList();

            final cancelledBookings = allBookings.where((b) {
              return b.bookingStatus == BookingStatus.cancelled ||
                  b.bookingStatus == BookingStatus.refundPending ||
                  b.bookingStatus == BookingStatus.refunded;
            }).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(upcomingBookings, 'No Upcoming Bookings', 'Book a court slot to get started.'),
                _buildBookingsList(pastBookings, 'No Past Bookings', 'Your completed venue reservations will show here.'),
                _buildBookingsList(cancelledBookings, 'No Cancelled Bookings', 'You have no cancelled venue reservations.'),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingsList(
    List<BookingModel> bookings,
    String emptyTitle,
    String emptySubtitle,
  ) {
    if (bookings.isEmpty) {
      return ToliEmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        mainIcon: Icons.confirmation_number_outlined,
      );
    }

    return ToliRefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) setState(() {});
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
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

    return GestureDetector(
      onTap: () => _openBookingDetail(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
            // Top Row: Venue Name + Status Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.venueName,
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Court & Sport
            Text(
              '${booking.courtName} · ${booking.sportName}',
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Date & Time + Price Row
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.bookingDate} • ${booking.startTime} – ${booking.endTime} (${BookingTimeUtils.formatDuration(booking.durationMinutes)})',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${booking.finalAmountRupees.toInt()}',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Actions Row
            Row(
              children: [
                // View Details Button
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openBookingDetail(booking),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'View Details',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // If Confirmed, offer Create Game button
                if (booking.bookingStatus == BookingStatus.confirmed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openCreateGame(booking),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Create Game',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
