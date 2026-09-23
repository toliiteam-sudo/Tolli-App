import 'package:flutter/material.dart';
import '../services/google_fit_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class ProfileFitnessCard extends StatefulWidget {
  const ProfileFitnessCard({super.key});

  @override
  State<ProfileFitnessCard> createState() => _ProfileFitnessCardState();
}

class _ProfileFitnessCardState extends State<ProfileFitnessCard> with WidgetsBindingObserver {
  final GoogleFitService _googleFitService = GoogleFitService();
  bool _didUserDeny = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _googleFitService.addListener(_onServiceUpdate);
    _googleFitService.initAndCheckState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleFitService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _googleFitService.initAndCheckState();
    }
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleConnect() async {
    final success = await _googleFitService.connect();
    if (!mounted) return;

    if (success) {
      setState(() {
        _didUserDeny = false;
      });
    } else {
      setState(() {
        _didUserDeny = true;
      });
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDistance(double km) {
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _googleFitService.isConnected;
    final isFetching = _googleFitService.isFetchingData;
    final isChecking = _googleFitService.isChecking;

    final stepsStr = isFetching ? '— — —' : _formatNumber(_googleFitService.todaySteps);
    final calsStr = isFetching ? '— — —' : _formatNumber(_googleFitService.todayCalories);
    final distStr = isFetching ? '— — —' : _formatDistance(_googleFitService.todayDistanceKm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Fitness',
          style: AppTypography.headline.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        // Single Unified Fitness Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: isConnected
              ? Column(
                  children: [
                    // 3 Balanced Fitness Metrics
                    Row(
                      children: [
                        // Steps Metric
                        Expanded(
                          child: _buildMetricColumn(
                            icon: Icons.directions_walk_rounded,
                            value: stepsStr,
                            label: 'Steps',
                          ),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: const Color(0xFFF1F5F9),
                        ),
                        // Calories Metric
                        Expanded(
                          child: _buildMetricColumn(
                            icon: Icons.local_fire_department_rounded,
                            value: calsStr,
                            label: 'Calories',
                          ),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: const Color(0xFFF1F5F9),
                        ),
                        // Distance Metric
                        Expanded(
                          child: _buildMetricColumn(
                            icon: Icons.place_rounded,
                            value: distStr,
                            label: 'Distance',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Subtle Connected Indicator Footer (TOLI blue #063E9E with check)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Google Fit connected',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect your fitness activity to see your steps, calories and distance in TOLI.',
                      style: AppTypography.bodySubtitle.copyWith(
                        fontSize: 13.5,
                        height: 1.45,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: (isChecking || isFetching) ? null : _handleConnect,
                        child: isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Connect Google Fit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_didUserDeny) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Google Fit access is required to show your fitness activity.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTypography.headline.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
