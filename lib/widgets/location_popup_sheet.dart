import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class LocationPopupSheet extends StatefulWidget {
  final String initialQuery;
  final VoidCallback onDetectLocation;
  final VoidCallback onEnterManually;

  const LocationPopupSheet({
    super.key,
    this.initialQuery = 'Chitra, Bhavnagar',
    required this.onDetectLocation,
    required this.onEnterManually,
  });

  @override
  State<LocationPopupSheet> createState() => _LocationPopupSheetState();
}

class _LocationPopupSheetState extends State<LocationPopupSheet> {
  late TextEditingController _searchController;
  bool _isAreaSelected = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top circular location pin icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),

            // Heading & Subtitle
            Text(
              'Where are you?',
              style: AppTypography.headline.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Find activities happening near you.',
              style: AppTypography.bodySubtitle.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Search text box
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.borderLight,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      maxLength: 100,
                      style: AppTypography.inputText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter area or city',
                        border: InputBorder.none,
                        isDense: true,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _isAreaSelected = val.trim().isNotEmpty;
                        });
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _isAreaSelected = false;
                        });
                      },
                      child: const Icon(
                        Icons.cancel_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Green "✓ Area selected" badge
            if (_isAreaSelected) ...[
              Row(
                children: [
                  const Icon(
                    Icons.check,
                    size: 15,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Area selected',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ] else ...[
              const SizedBox(height: 20),
            ],

            // Primary Button: Detect My Location
            GestureDetector(
              onTap: widget.onDetectLocation,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Detect My Location',
                      style: AppTypography.buttonText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Button: Enter Location Manually
            GestureDetector(
              onTap: widget.onEnterManually,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Enter Location Manually',
                  style: AppTypography.buttonText.copyWith(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
