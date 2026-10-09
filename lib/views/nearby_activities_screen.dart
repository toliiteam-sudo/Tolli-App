import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/date_selector_strip.dart';
import '../widgets/date_picker_bottom_sheet.dart';
import '../widgets/filter_chips_bar.dart';
import '../widgets/filters_bottom_sheet.dart';
import '../widgets/toli_empty_state.dart';
import '../widgets/toli_header.dart';
import '../widgets/toli_refresh_indicator.dart';
import 'create_activity_screen.dart';
import 'profile_screen.dart';

class NearbyActivitiesScreen extends StatefulWidget {
  const NearbyActivitiesScreen({super.key});

  @override
  State<NearbyActivitiesScreen> createState() => _NearbyActivitiesScreenState();
}

class _NearbyActivitiesScreenState extends State<NearbyActivitiesScreen> {
  late final ActivitiesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivitiesController();
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _openDatePicker() async {
    final selectedDate = _controller.dates.isNotEmpty &&
            _controller.selectedDateIndex < _controller.dates.length
        ? _controller.dates[_controller.selectedDateIndex].date
        : DateTime.now();

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerBottomSheet(initialDate: selectedDate),
    );

    if (result != null && result['date'] != null && result['date'] is DateTime) {
      final DateTime chosen = result['date'];
      _controller.selectDateByDateTime(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Fixed Top Header Bar
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: _buildHeader(),
            ),

            // 2. Fixed Date Selector Bar (directly beneath Header)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: DateSelectorStrip(
                dates: _controller.dates,
                selectedIndex: _controller.selectedDateIndex,
                onDateSelected: _controller.selectDate,
                onMonthTap: _openDatePicker,
              ),
            ),

            // 3. Fixed Filter Chips Bar (directly beneath Date Selector Bar)
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilterChipsBar(
                filters: _controller.filters,
                onFilterSelected: _controller.toggleFilter,
                onTunePressed: () {
                  FiltersBottomSheet.show(context);
                },
              ),
            ),

            // 4. Scrollable Content Area starting below Filter Chips Bar
            Expanded(
              child: ToliRefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 1000));
                  if (mounted) {
                    setState(() {
                      _controller.reset();
                    });
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header: Nearby activities
                      _buildSectionHeader(),
                      const SizedBox(height: 14),

                      // Activity Cards List or Premium Empty State
                      if (_controller.activities.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _controller.activities.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final activity = _controller.activities[index];
                            return ActivityCard(
                              activity: activity,
                            );
                          },
                        )
                      else
                        ToliEmptyState.explore(
                          onCreateActivity: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateActivityScreen(),
                              ),
                            );
                          },
                          onRefresh: () {
                            _controller.reset();
                          },
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final authState = AuthController.instance.state;
        final firstName = authState.firstName.trim();
        final dispName = authState.displayName.trim();
        final name = firstName.isNotEmpty
            ? firstName
            : (dispName.isNotEmpty
                ? dispName.split(' ').first
                : 'User');

        return ToliHeader(
          title: 'Hey $name!',
          subtitle: _controller.selectedLocation,
          onAvatarTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Text(
      'Nearby activities',
      style: AppTypography.headline.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 19,
        color: AppColors.textDark,
        letterSpacing: -0.3,
      ),
    );
  }
}
