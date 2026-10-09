import 'package:flutter/material.dart';
import '../services/google_fit_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_assets.dart';

class HomeGoogleFitCard extends StatefulWidget {
  const HomeGoogleFitCard({super.key});

  @override
  State<HomeGoogleFitCard> createState() => _HomeGoogleFitCardState();
}

class _HomeGoogleFitCardState extends State<HomeGoogleFitCard> with WidgetsBindingObserver {
  final GoogleFitService _googleFitService = GoogleFitService();

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

    if (!success && _googleFitService.errorMessage != null) {
      // Show non-blocking hint if needed
      debugPrint('Google Fit OAuth result: ${_googleFitService.errorMessage}');
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConnected ? const Color(0xFFCBD5E1) : AppColors.borderLight,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: isConnected
          ? Row(
              children: [
                // Flame icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Compact Connected Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Google Fit connected',
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$stepsStr steps • $calsStr cal • $distStr',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                // Flame icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    AppAssets.firePng,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFF97316),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link your Google Fit',
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track your steps, calories & distance',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Button
                GestureDetector(
                  onTap: (isChecking || isFetching) ? null : _handleConnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
