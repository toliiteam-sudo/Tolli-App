import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_step_progress.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';
import 'location_screen.dart';
import 'otp_screen.dart';
import 'welcome_screen.dart';

class EmailScreen extends StatefulWidget {
  final AuthController? authController;

  const EmailScreen({
    super.key,
    this.authController,
  });

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  late final AuthController _authController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController.instance;
    _authController.setAuthMode('email');
    _textController = TextEditingController(
      text: _authController.state.email,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();

    if (_authController.state.authMode == 'email') {
      if (!_authController.validateEmail(_textController.text)) {
        return;
      }
    } else {
      if (!_authController.validatePhone(_textController.text)) {
        return;
      }
    }

    final success = await _authController.sendOtp();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => OtpScreen(
            authController: _authController,
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
    } else {
      final errorMsg = _authController.state.authMode == 'email'
          ? (_authController.state.emailError ?? 'Failed to send OTP')
          : (_authController.state.phoneError ?? 'Failed to send OTP');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    FocusScope.of(context).unfocus();

    final success = await _authController.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      final targetScreen = _authController.state.isProfileComplete
          ? const HomeScreen()
          : LocationScreen(authController: _authController);

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
        (route) => false,
      );
    } else if (_authController.state.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authController.state.authError!),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
              const WelcomeScreen(),
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
              animation: _authController,
              builder: (context, child) {
                final state = _authController.state;

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Step 1 of 5 Header Section
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
                            child: AuthStepProgress(
                              currentStep: 1,
                              totalSteps: 5,
                              title: "Let's get you started",
                              subtitle:
                                  'Enter your phone number to join activities and meet people nearby.',
                            ),
                          ),

                          const Spacer(),

                          // Bottom Card Sheet
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(32)),
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
                                // Icon Badge & Mode Toggle Container
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        state.authMode == 'email'
                                            ? Icons.mail_outline_rounded
                                            : Icons.phone_android_rounded,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              _authController.setAuthMode('email');
                                              _textController.text = state.email;
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: state.authMode == 'email' ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: state.authMode == 'email'
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.05),
                                                          blurRadius: 3,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                'Email',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: state.authMode == 'email'
                                                      ? AppColors.primary
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              _authController.setAuthMode('phone');
                                              _textController.text = state.rawPhoneNumber;
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: state.authMode == 'phone' ? Colors.white : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: state.authMode == 'phone'
                                                    ? [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.05),
                                                          blurRadius: 3,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: Text(
                                                'Phone',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: state.authMode == 'phone'
                                                      ? AppColors.primary
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                const SizedBox(height: 18),

                                // Label & Input
                                Text(
                                  state.authMode == 'email'
                                      ? 'Enter Email Address'
                                      : 'Enter Mobile Number',
                                  style: AppTypography.inputLabel.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (state.authMode == 'email'
                                              ? state.emailError != null
                                              : state.phoneError != null)
                                          ? AppColors.borderError
                                          : AppColors.borderLight,
                                      width: (state.authMode == 'email'
                                              ? state.emailError != null
                                              : state.phoneError != null)
                                          ? 1.4
                                          : 1.0,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(
                                    children: [
                                      if (state.authMode == 'phone') ...[
                                        Text(
                                          '+91  |',
                                          style: AppTypography.inputText.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ] else ...[
                                        const Icon(
                                          Icons.alternate_email_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: TextField(
                                          controller: _textController,
                                          keyboardType: state.authMode == 'email'
                                              ? TextInputType.emailAddress
                                              : TextInputType.phone,
                                          textInputAction: TextInputAction.done,
                                          maxLength: state.authMode == 'email' ? 50 : 15,
                                          style: AppTypography.inputText,
                                          decoration: InputDecoration(
                                            hintText: state.authMode == 'email'
                                                ? 'name@example.com'
                                                : 'Enter mobile number',
                                            hintStyle: const TextStyle(
                                              color: AppColors.textTertiary,
                                              fontSize: 15,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            counterText: '',
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (value) {
                                            if (state.authMode == 'email') {
                                              state.email = value;
                                              _authController.clearEmailError();
                                            } else {
                                              state.rawPhoneNumber = value;
                                              state.phoneNumber = '+91 $value';
                                              _authController.clearPhoneError();
                                            }
                                          },
                                          onSubmitted: (_) => _handleSendOtp(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (state.authMode == 'email' && state.emailError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    state.emailError!,
                                    style: AppTypography.errorText,
                                  ),
                                ] else if (state.authMode == 'phone' && state.phoneError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    state.phoneError!,
                                    style: AppTypography.errorText,
                                  ),
                                ],
                                const SizedBox(height: 18),

                                // Send OTP Button
                                CustomButton(
                                  text: 'Send OTP',
                                  height: 48,
                                  isLoading: state.isLoading && state.authMode != 'google',
                                  onPressed: _handleSendOtp,
                                ),
                                const SizedBox(height: 18),

                                // Terms & Privacy Notice
                                Center(
                                  child: Text(
                                    'By signing up, you agree to the\nTerms Of Service and Privacy Policy',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // "Or" Divider
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                        color: AppColors.borderLight,
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        'Or',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                        color: AppColors.borderLight,
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Full-Width Google Authentication Button
                                _GoogleAuthButton(
                                  height: 48,
                                  isLoading: state.isLoading && state.authMode == 'google',
                                  onTap: _handleGoogleSignIn,
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

class _GoogleAuthButton extends StatelessWidget {
  final double height;
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleAuthButton({
    this.height = 48,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.googleLogoPng,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: AppTypography.titleMedium.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
