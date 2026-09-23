import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_step_progress.dart';
import '../widgets/custom_button.dart';
import '../widgets/otp_pin_input.dart';
import 'email_screen.dart';
import 'location_screen.dart';

class OtpScreen extends StatefulWidget {
  final AuthController authController;

  const OtpScreen({
    super.key,
    required this.authController,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.authController;
  }

  Future<void> _handleVerify() async {
    FocusScope.of(context).unfocus();

    final success = await _controller.verifyOtp();
    if (success && mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              LocationScreen(
            authController: _controller,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const EmailScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF0F172A),
              size: 22,
            ),
            onPressed: _handleBackNavigation,
          ),
        ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final state = _controller.state;
                final targetDestination = state.authMode == 'email'
                    ? state.email
                    : (state.phoneNumber.isNotEmpty
                        ? state.phoneNumber
                        : state.rawPhoneNumber);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top 2 of 5 Header Section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                            child: AuthStepProgress(
                              currentStep: 2,
                              totalSteps: 5,
                              title: 'Check your messages',
                              subtitle:
                                  'We sent a 6-digit code to $targetDestination.',
                            ),
                          ),

                          const Spacer(),

                          // Bottom White Card
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x0C000000),
                                  blurRadius: 20,
                                  offset: Offset(0, -6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon Badge Container (LocationScreen style)
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.mark_email_read_outlined,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Heading
                                Text(
                                  "You're Almost There!",
                                  style: AppTypography.headline.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                  // Subhead Row: "Enter OTP" on Left & Phone/Email on Right
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Enter OTP',
                                        style:
                                            AppTypography.inputLabel.copyWith(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        targetDestination,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // 6-Digit OTP Boxes with inline error
                                  OtpPinInput(
                                    length: 6,
                                    errorText: state.otpError,
                                    onChanged: (otp) {
                                      _controller.updateOtp(otp);
                                    },
                                    onCompleted: (otp) {
                                      _controller.updateOtp(otp);
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Verify Button
                                  CustomButton(
                                    text: 'Verify',
                                    isLoading: state.isLoading,
                                    onPressed: _handleVerify,
                                  ),
                                  const SizedBox(height: 16),

                                  // Resend OTP Countdown / Action Text
                                  Center(
                                    child: _controller.canResend
                                        ? GestureDetector(
                                            onTap: () =>
                                                _controller.resendOtp(),
                                            child: Text(
                                              'Resend OTP',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Resend OTP in ${_controller.formattedCountdown}',
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
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
                  );
              },
            );
          },
        ),
      ),
    ),
  );
}
}
