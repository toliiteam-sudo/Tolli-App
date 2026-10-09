import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_assets.dart';

class HealthConnectCard extends StatefulWidget {
  final bool isCompact;
  const HealthConnectCard({super.key, this.isCompact = false});

  @override
  State<HealthConnectCard> createState() => _HealthConnectCardState();
}

class _HealthConnectCardState extends State<HealthConnectCard> with WidgetsBindingObserver {
  final HealthService _healthService = HealthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _healthService.addListener(_onHealthServiceUpdate);
    _healthService.initAndCheckState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthService.removeListener(_onHealthServiceUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verify actual permissions whenever the user returns to TOLI
      _healthService.initAndCheckState();
    }
  }

  void _onHealthServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openHealthSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HealthSheetContent(
        healthService: _healthService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _healthService.state;
    final steps = _healthService.todaySteps;
    final isConnected = state == HealthConnectionState.connected;

    String title;
    String subtitle;
    Color iconBgColor;
    IconData iconData;
    Color iconColor;

    switch (state) {
      case HealthConnectionState.connected:
        title = 'Health & Fitness';
        subtitle = 'Connected ✓ • Today: ${steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps';
        iconBgColor = const Color(0xFFDCFCE7);
        iconData = Icons.check_circle_rounded;
        iconColor = const Color(0xFF16A34A);
        break;
      case HealthConnectionState.permissionRevoked:
        title = 'Connect Health & Fitness';
        subtitle = 'Health access needs to be reconnected';
        iconBgColor = const Color(0xFFFEF2F2);
        iconData = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      case HealthConnectionState.needsUpdate:
        title = 'Connect Health & Fitness';
        subtitle = 'Health Connect requires an update on your device';
        iconBgColor = const Color(0xFFFEF3C7);
        iconData = Icons.system_update_rounded;
        iconColor = const Color(0xFFD97706);
        break;
      case HealthConnectionState.unavailable:
        title = 'Connect Health & Fitness';
        subtitle = 'Health Connect isn\'t available on this device';
        iconBgColor = const Color(0xFFF1F5F9);
        iconData = Icons.health_and_safety_outlined;
        iconColor = const Color(0xFF64748B);
        break;
      case HealthConnectionState.notConnected:
        title = 'Connect Health & Fitness';
        subtitle = 'Connect through Health Connect to track your steps automatically';
        iconBgColor = const Color(0xFFFFF7ED);
        iconData = Icons.local_fire_department_rounded;
        iconColor = const Color(0xFFF97316);
        break;
    }

    return GestureDetector(
      onTap: _openHealthSheet,
      child: Container(
        padding: EdgeInsets.all(widget.isCompact ? 14 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isConnected ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
            width: isConnected ? 1.2 : 1.0,
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
              width: widget.isCompact ? 40 : 44,
              height: widget.isCompact ? 40 : 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: isConnected
                  ? Icon(iconData, color: iconColor, size: 24)
                  : Image.asset(
                      AppAssets.firePng,
                      width: 26,
                      height: 26,
                      errorBuilder: (_, _, _) => Icon(iconData, color: iconColor, size: 24),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            fontSize: widget.isCompact ? 14 : 14.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isConnected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      height: 1.3,
                      color: isConnected ? const Color(0xFF166534) : const Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSheetContent extends StatefulWidget {
  final HealthService healthService;
  const _HealthSheetContent({required this.healthService});

  @override
  State<_HealthSheetContent> createState() => _HealthSheetContentState();
}

class _HealthSheetContentState extends State<_HealthSheetContent> {
  bool _isLoading = false;

  Future<void> _handleConnect() async {
    setState(() {
      _isLoading = true;
    });

    final success = await widget.healthService.connectHealth();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    if (success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Health Connect linked! Today: ${widget.healthService.todaySteps} steps',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      final msg = widget.healthService.errorMessage ??
          'Health data access wasn\'t granted. You can connect it anytime from Settings.';
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF334155),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.healthService.state;
    final steps = widget.healthService.todaySteps;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: state == HealthConnectionState.connected
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state == HealthConnectionState.connected
                        ? Icons.favorite_rounded
                        : Icons.health_and_safety_rounded,
                    color: state == HealthConnectionState.connected
                        ? const Color(0xFF16A34A)
                        : AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state == HealthConnectionState.connected
                            ? 'Health & Fitness Connected ✓'
                            : 'Connect Health & Fitness',
                        style: AppTypography.headline.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Powered by Android Health Connect',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Description Body
            if (state == HealthConnectionState.connected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Today\'s Activity Steps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${steps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Synced from Health Connect',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'TOLI automatically syncs your daily step count to track match intensity and active minutes.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF475569),
                ),
              ),
            ] else if (state == HealthConnectionState.unavailable) ...[
              Text(
                'Health Connect is not supported or currently available on this Android device. Please check system settings or install Health Connect from Google Play Store.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ] else if (state == HealthConnectionState.needsUpdate) ...[
              Text(
                'Health Connect needs to be updated on your device before TOLI can read your steps.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ] else ...[
              Text(
                'Connecting Health Connect allows TOLI to automatically read your daily step count, active minutes, and fitness stats across your sports activities.\n\nWe only ask for Step Count permission (READ_STEPS). Your health data is processed locally and kept private.',
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 13.5,
                  height: 1.5,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Buttons
            if (state == HealthConnectionState.connected) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await widget.healthService.refreshSteps();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ] else if (state == HealthConnectionState.needsUpdate) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await widget.healthService.installHealthConnect();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ] else if (state == HealthConnectionState.unavailable) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Not Now', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleConnect,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              state == HealthConnectionState.permissionRevoked ? 'Reconnect' : 'Connect',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
