import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import 'email_screen.dart';
import 'interests_screen.dart';
import 'location_map_screen.dart';

class LocationScreen extends StatefulWidget {
  final AuthController authController;

  const LocationScreen({
    super.key,
    required this.authController,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late AuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.authController;
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

  void _navigateToInterests() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            InterestsScreen(authController: _controller),
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

  void _handleDetectLocation() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationMapScreen(authController: _controller),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEnterManually() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManualLocationBottomSheet(
        authController: _controller,
        onConfirmed: (locString) {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final hasLocation = state.selectedCity.isNotEmpty || state.isLocationDetected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
          scrolledUnderElevation: 0,
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
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Header Section (Step 3 of 5) ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '3 of 5',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: List.generate(5, (index) {
                                  final isCompletedOrCurrent = index < 3;
                                  return Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: EdgeInsets.only(
                                        right: index == 4 ? 0 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCompletedOrCurrent
                                            ? AppColors.primary
                                            : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),

                              Text(
                                'Let\'s find your spot!',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),

                              Text(
                                'Set your location to discover activities near you.',
                                style: AppTypography.bodySubtitle.copyWith(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // ── Bottom Sheet Card Section ──
                        Container(
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
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 14),

                              Text(
                                hasLocation ? 'Your Location' : 'Where are you?',
                                style: AppTypography.headline.copyWith(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),

                              Text(
                                hasLocation
                                    ? 'Confirm or update your current location.'
                                    : 'Find activities happening near you.',
                                style: AppTypography.bodySubtitle.copyWith(
                                  fontSize: 13.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (hasLocation) ...[
                                // Selected Location Details Display Card
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFECFDF5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.successGreen,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              state.selectedCity,
                                              style: AppTypography.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              state.locationSummary.isNotEmpty
                                                  ? state.locationSummary
                                                  : '${state.areaLocality}, ${state.selectedCity}',
                                              style: AppTypography.caption.copyWith(
                                                color: const Color(0xFF64748B),
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Continue Button
                                GestureDetector(
                                  onTap: _navigateToInterests,
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Continue',
                                      style: AppTypography.buttonText.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Change Location Option
                                Center(
                                  child: TextButton(
                                    onPressed: _handleEnterManually,
                                    child: Text(
                                      'Change Location',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Primary Button: "↗ Detect My Location"
                                GestureDetector(
                                  onTap: _handleDetectLocation,
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.north_east_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Detect My Location',
                                          style: AppTypography.buttonText.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Secondary Button: "Enter Location Manually"
                                GestureDetector(
                                  onTap: _handleEnterManually,
                                  child: Container(
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1.2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Enter Location Manually',
                                      style: AppTypography.buttonText.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ManualLocationBottomSheet extends StatefulWidget {
  final AuthController authController;
  final ValueChanged<String> onConfirmed;

  const _ManualLocationBottomSheet({
    required this.authController,
    required this.onConfirmed,
  });

  @override
  State<_ManualLocationBottomSheet> createState() =>
      __ManualLocationBottomSheetState();
}

class __ManualLocationBottomSheetState
    extends State<_ManualLocationBottomSheet> {
  late TextEditingController _cityController;
  late TextEditingController _localityController;
  late TextEditingController _pincodeController;
  late TextEditingController _landmarkController;

  bool _isCityDropdownOpen = false;
  final List<String> _popularCities = [
    'Bhavnagar',
    'Ahmedabad',
    'Gandhinagar',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Mumbai',
    'Delhi',
    'Bengaluru',
    'Hyderabad',
    'Chennai',
    'Kolkata',
    'Pune',
    'Jaipur',
    'Chandigarh',
    'Lucknow',
    'Indore',
    'Noida',
    'Gurugram',
  ];

  List<String> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(
      text: widget.authController.state.selectedCity,
    );
    _localityController = TextEditingController(
      text: widget.authController.state.areaLocality,
    );
    _pincodeController = TextEditingController(
      text: widget.authController.state.pincode,
    );
    _landmarkController = TextEditingController(
      text: widget.authController.state.landmark,
    );

    _filteredCities = List.from(_popularCities);

    _cityController.addListener(() {
      final query = _cityController.text.trim().toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _filteredCities = List.from(_popularCities);
        } else {
          _filteredCities = _popularCities
              .where((c) => c.toLowerCase().contains(query))
              .toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _localityController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _selectCity(String city) {
    setState(() {
      _cityController.text = city;
      _isCityDropdownOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Enter Location Details',
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Area / Locality
            _buildLabel('Area / Locality *'),
            const SizedBox(height: 6),
            _buildTextField(_localityController, 'e.g. Waghawadi Road / Sector 15'),
            const SizedBox(height: 14),

            // 2. City Searchable Input & Autocomplete Dropdown
            _buildLabel('City *'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      onTap: () {
                        setState(() {
                          _isCityDropdownOpen = true;
                        });
                      },
                      style: AppTypography.inputText.copyWith(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search or select city (e.g. Bhavnagar, Mumbai)',
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isCityDropdownOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: () {
                      setState(() {
                        _isCityDropdownOpen = !_isCityDropdownOpen;
                      });
                    },
                  ),
                ],
              ),
            ),

            if (_isCityDropdownOpen) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredCities.length,
                  separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, idx) {
                    final c = _filteredCities[idx];
                    return ListTile(
                      dense: true,
                      title: Text(
                        c,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13.5,
                          fontWeight: _cityController.text == c ? FontWeight.w700 : FontWeight.w500,
                          color: _cityController.text == c ? AppColors.primary : const Color(0xFF0F172A),
                        ),
                      ),
                      onTap: () => _selectCity(c),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),

            // 3. Landmark / Nearby place (Optional)
            _buildLabel('Landmark / Nearby place (Optional)'),
            const SizedBox(height: 6),
            _buildTextField(_landmarkController, 'e.g. Near City Park'),
            const SizedBox(height: 14),

            // 4. Pincode (ALWAYS LAST)
            _buildLabel('Pincode *'),
            const SizedBox(height: 6),
            _buildTextField(_pincodeController, '6-digit pincode (e.g. 364001)', isNumber: true, maxLength: 6),
            const SizedBox(height: 24),

            // Confirm button
            GestureDetector(
              onTap: () {
                final locality = _localityController.text.trim();
                final city = _cityController.text.trim();
                final pincode = _pincodeController.text.trim();
                final landmark = _landmarkController.text.trim();

                if (locality.isEmpty) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter your area/locality.'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }

                if (city.isEmpty) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please select your city.'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }

                final digitsOnly = pincode.replaceAll(RegExp(r'\D'), '');
                if (pincode.isEmpty || digitsOnly.length != 6 || pincode.length != 6) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Enter a valid 6-digit pincode.'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  return;
                }

                final loc = '$locality, $city';

                widget.authController.setManualLocation(
                  state: widget.authController.state.selectedState,
                  city: city,
                  locality: locality,
                  street: '',
                  pincode: pincode,
                  landmark: landmark,
                );
                Navigator.pop(context);
                widget.onConfirmed(loc);
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20063E9E),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Confirm Location',
                  style: AppTypography.buttonText.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    int? maxLength,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              maxLength: maxLength ?? (isNumber ? 6 : 100),
              style: AppTypography.inputText.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
