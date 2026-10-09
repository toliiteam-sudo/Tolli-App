import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../widgets/toli_confirmation_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialFirstName;
  final String initialLastName;
  final String initialUsername;
  final String initialEmail;
  final String initialPhone;
  final String initialLocation;
  final String initialGender;
  final String? initialProfileImagePath;
  final List<String> initialInterestedActivities;

  const EditProfileScreen({
    super.key,
    this.initialFirstName = '',
    this.initialLastName = '',
    this.initialUsername = '',
    this.initialEmail = '',
    this.initialPhone = '',
    this.initialLocation = 'Bhavnagar, India',
    this.initialGender = 'Male',
    this.initialProfileImagePath,
    this.initialInterestedActivities = const ['Badminton', 'Running', 'Gaming', 'Photography'],
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;

  late String _selectedGender;
  bool _isGenderDropdownOpen = false;
  String? _profileImagePath;
  late List<String> _interestedActivities;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _availableSports = [
    'Cricket',
    'Badminton',
    'Football',
    'Pickleball',
    'Basketball',
    'Tennis',
    'Swimming',
    'Running',
    'Gaming',
    'Photography',
    'Cycling',
    'Yoga',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.initialFirstName);
    _lastNameController = TextEditingController(text: widget.initialLastName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _locationController = TextEditingController(text: widget.initialLocation);
    _selectedGender = _genders.contains(widget.initialGender) ? widget.initialGender : 'Male';
    _profileImagePath = widget.initialProfileImagePath;
    _interestedActivities = List<String>.from(widget.initialInterestedActivities);
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
      }
    } catch (e) {
      debugPrint('Error picking profile image in EditProfileScreen: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    HapticFeedback.mediumImpact();
    final updatedData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'gender': _selectedGender,
      'profileImagePath': _profileImagePath,
      'interestedActivities': _interestedActivities,
    };

    Navigator.of(context).pop(updatedData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Profile updated successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    HapticFeedback.heavyImpact();
    ToliConfirmationDialog.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete Account?',
      message:
          'Are you sure you want to delete your TOLII account? All your game data, matches, and stats will be permanently removed. This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      onConfirm: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account deletion request submitted.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  void _openAddInterestSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Select Activities',
                style: AppTypography.headline.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSports.map((sport) {
                  final isSelected = _interestedActivities.contains(sport);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (isSelected) {
                          _interestedActivities.remove(sport);
                        } else {
                          _interestedActivities.add(sport);
                        }
                      });
                      (ctx as Element).markNeedsBuild();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        sport,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4FF),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Edit Your Profile',
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 38), // Balance for back button
                ],
              ),
            ),

            // ── Scrollable Form Body ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Picture Avatar with Camera Badge
                    Center(
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEEF4FF),
                                border: Border.all(
                                  color: const Color(0xFF2563EB),
                                  width: 2.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: (_profileImagePath != null &&
                                        _profileImagePath!.isNotEmpty &&
                                        File(_profileImagePath!).existsSync())
                                    ? Image.file(
                                        File(_profileImagePath!),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_outline_rounded,
                                        size: 50,
                                        color: Color(0xFF2563EB),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // "Add Profile Picture" / "Change Profile Picture" link
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Text(
                        (_profileImagePath != null &&
                                _profileImagePath!.isNotEmpty &&
                                File(_profileImagePath!).existsSync())
                            ? 'Change Profile Picture'
                            : 'Add Profile Picture',
                        style: AppTypography.caption.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── First Name & Last Name (Side by Side in 1 Row) ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildLabeledInput(
                            label: 'First Name',
                            child: _buildInputField(
                              controller: _firstNameController,
                              hintText: 'First Name',
                              showEditIcon: true,
                              maxLength: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildLabeledInput(
                            label: 'Last Name',
                            child: _buildInputField(
                              controller: _lastNameController,
                              hintText: 'Last Name',
                              showEditIcon: true,
                              maxLength: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Read-Only Username Field ──
                    _buildLabeledInput(
                      label: 'Username',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _usernameController.text.startsWith('@')
                                  ? _usernameController.text
                                  : '@${_usernameController.text}',
                              style: AppTypography.titleMedium.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'This username cannot be changed.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Email Field ──
                    _buildLabeledInput(
                      label: 'Email',
                      child: _buildInputField(
                        controller: _emailController,
                        hintText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        showEditIcon: true,
                        maxLength: 80,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Phone Field with Verified Badge ──
                    _buildLabeledInput(
                      label: 'Phone',
                      child: _buildInputField(
                        controller: _phoneController,
                        hintText: 'Phone',
                        keyboardType: TextInputType.phone,
                        maxLength: 15,
                        rightWidget: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: Color(0xFF059669),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Location Field ──
                    _buildLabeledInput(
                      label: 'Location',
                      child: _buildInputField(
                        controller: _locationController,
                        hintText: 'Location',
                        showEditIcon: true,
                        maxLength: 150,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Activities I'm Interested In ──
                    _buildLabeledInput(
                      label: "Activities I'm Interested In",
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._interestedActivities.map((sport) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                sport,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: _openAddInterestSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF2563EB),
                                  width: 1.2,
                                ),
                              ),
                              child: const Text(
                                '+ Add More',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Gender Dropdown ──
                    _buildLabeledInput(
                      label: 'Gender',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _isGenderDropdownOpen = !_isGenderDropdownOpen;
                              });
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _isGenderDropdownOpen ? AppColors.primary : const Color(0xFFE2E8F0),
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedGender,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
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
                                children: _genders.map((g) {
                                  final isSel = _selectedGender == g;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _selectedGender = g;
                                        _isGenderDropdownOpen = false;
                                      });
                                    },
                                    child: Container(
                                      height: 46,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSel ? const Color(0xFFEFF6FF) : Colors.white,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            g,
                                            style: AppTypography.titleMedium.copyWith(
                                              fontSize: 14,
                                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                              color: isSel ? AppColors.primary : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (isSel)
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
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Save Button (Solid Blue) ──
                    GestureDetector(
                      onTap: _saveProfile,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Save',
                          style: AppTypography.buttonText.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Delete Account Button (Solid Red) ──
                    GestureDetector(
                      onTap: _showDeleteAccountDialog,
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Delete Account',
                          style: AppTypography.buttonText.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledInput({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool showEditIcon = false,
    Widget? rightWidget,
    int? maxLength,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              style: AppTypography.titleMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.caption.copyWith(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (rightWidget != null) ...[
            const SizedBox(width: 8),
            rightWidget,
          ],
          if (showEditIcon && rightWidget == null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.edit_outlined,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ],
        ],
      ),
    );
  }
}
