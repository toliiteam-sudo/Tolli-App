import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_step_progress.dart';
import '../widgets/custom_button.dart';
import 'home_screen.dart';
import 'interests_screen.dart';
import 'location_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  final AuthController authController;

  const CreateProfileScreen({
    super.key,
    required this.authController,
  });

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  late AuthController _controller;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  String? _selectedGender;
  String? _profileImagePath;
  bool _isGenderDropdownOpen = false;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _controller = widget.authController;

    final state = _controller.state;
    _firstNameController = TextEditingController(text: state.firstName);
    _lastNameController = TextEditingController(text: state.lastName);
    _emailController = TextEditingController(text: state.email);
    _phoneController = TextEditingController(text: state.phoneNumber);
    _selectedGender = state.gender;
    _profileImagePath = state.profileImagePath;
  }

  Future<void> _pickProfileImage() async {
    HapticFeedback.lightImpact();
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _profileImagePath = image.path;
        });
        _controller.updateProfileImagePath(image.path);
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateProfile() async {
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Please enter your first name', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    _controller.updateProfileNames(
      firstName: firstName,
      lastName: _lastNameController.text.trim(),
    );
    _controller.updateGender(_selectedGender);

    final success = await _controller.createProfile();
    if (!mounted) return;

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curvedAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
        (route) => false,
      );
    } else if (_controller.state.usernameError != null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.state.usernameError!),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showAddInterestsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Activities',
                style: AppTypography.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final allActivities = [
                    'Box Cricket', 'Football', 'Badminton', 'Pickleball',
                    'Table Tennis', 'Basketball', 'Running', 'Cycling',
                    'Gaming', 'Hiking', 'Yoga', 'Dance', 'Gym',
                    'Shopping', 'Photography', 'Volleyball', 'Movies',
                    'Walking', 'Hangouts', 'Cafe Hangouts',
                  ];
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: allActivities.map((act) {
                        final isSel = _controller.isInterestSelected(act);
                        return FilterChip(
                          label: Text(act),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                          ),
                          checkmarkColor: Colors.white,
                          onSelected: (_) {
                            _controller.toggleInterest(act);
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            CustomButton(
              text: 'Done',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    _controller.updateProfileNames(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );
    _controller.updateGender(_selectedGender);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              InterestsScreen(authController: _controller),
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: _handleBackNavigation,
          ),
          title: Text(
            'Create Your Profile',
            style: AppTypography.headline.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final state = _controller.state;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 5 Header
                    AuthStepProgress(
                      currentStep: 5,
                      totalSteps: 5,
                      title: 'Almost Done!',
                      subtitle: 'Set up your details to complete your profile.',
                    ),
                    const SizedBox(height: 20),

                    // Profile Avatar Section
                    Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: AppColors.primaryLight,
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: (_profileImagePath != null &&
                                          _profileImagePath!.isNotEmpty &&
                                          File(_profileImagePath!).existsSync())
                                      ? Image.file(
                                          File(_profileImagePath!),
                                          width: 86,
                                          height: 86,
                                          fit: BoxFit.cover,
                                        )
                                      : (state.effectiveAvatarUrl != null &&
                                              state.effectiveAvatarUrl!.startsWith('http'))
                                          ? Image.network(
                                              state.effectiveAvatarUrl!,
                                              width: 86,
                                              height: 86,
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, stack) => const Icon(
                                                Icons.person_outline_rounded,
                                                size: 48,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_outline_rounded,
                                              size: 48,
                                              color: AppColors.primary,
                                            ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Text(
                            (_profileImagePath != null &&
                                    _profileImagePath!.isNotEmpty &&
                                    File(_profileImagePath!).existsSync())
                                ? 'Change Profile Picture'
                                : 'Add Profile Picture',
                            style: AppTypography.linkText.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // First Name & Last Name (2 columns)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('First Name'),
                            const SizedBox(height: 6),
                            _buildTextInput(
                              controller: _firstNameController,
                              hint: 'First Name',
                              maxLength: 40,
                              onChanged: (val) {
                                _controller.updateProfileNames(
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Last Name'),
                            const SizedBox(height: 6),
                            _buildTextInput(
                              controller: _lastNameController,
                              hint: 'Last Name',
                              maxLength: 40,
                              onChanged: (val) {
                                _controller.updateProfileNames(
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Read-Only Username Preview Field
                  _buildFieldLabel('Username'),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _controller.previewUsername.isNotEmpty
                          ? '@${_controller.previewUsername}'
                          : '@username',
                      style: AppTypography.inputText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatically generated from your name',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Email
                  _buildFieldLabel('Email'),
                  const SizedBox(height: 6),
                  _buildTextInput(
                    controller: _emailController,
                    hint: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 18),

                  // Phone with Verified Badge
                  _buildFieldLabel('Phone'),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            style: AppTypography.inputText.copyWith(
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter 10-digit mobile number',
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_phoneController.text.trim().isNotEmpty && state.authMode == 'phone') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Verified',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.successGreen,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Location (with edit pencil icon)
                  _buildFieldLabel('Location'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LocationScreen(
                            authController: _controller,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.locationSummary.isNotEmpty
                                  ? state.locationSummary
                                  : 'Bhavnagar, India',
                              style: AppTypography.inputText.copyWith(
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Activities I'm Interested In
                  _buildFieldLabel('Activities I\'m Interested In'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...state.selectedInterests.map((activity) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            activity,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _showAddInterestsSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.borderLight,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            '+ Add More',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Gender Field
                  _buildGenderSelector(),
                  const SizedBox(height: 32),

                  // Create Profile Button
                  CustomButton(
                    text: 'Create Profile',
                    isLoading: state.isLoading,
                    onPressed: _handleCreateProfile,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Gender'),
        const SizedBox(height: 6),

        // Gender Input Box
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isGenderDropdownOpen = !_isGenderDropdownOpen;
            });
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isGenderDropdownOpen ? AppColors.primary : AppColors.borderLight,
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedGender ?? 'Select gender',
                  style: AppTypography.inputText.copyWith(
                    color: _selectedGender != null ? AppColors.textDark : AppColors.textTertiary,
                    fontSize: 14,
                    fontWeight: _selectedGender != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                Icon(
                  _isGenderDropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        // Custom TOLII Dropdown Menu Anchored Directly to Field
        if (_isGenderDropdownOpen) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _genderOptions.map((gender) {
                final bool isSelected = _selectedGender == gender;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedGender = gender;
                      _isGenderDropdownOpen = false;
                    });
                    _controller.updateGender(gender);
                  },
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gender,
                          style: AppTypography.inputText.copyWith(
                            color: isSelected ? AppColors.primary : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTypography.inputLabel.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderLight,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: AppTypography.inputText.copyWith(
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 14,
          ),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
