import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../models/activity_model.dart';

class ActivitySelectionItem {
  final String title;
  final String iconAsset;
  final SportCategory sportCategory;
  final String section;

  const ActivitySelectionItem({
    required this.title,
    required this.iconAsset,
    required this.sportCategory,
    required this.section,
  });
}

class SelectActivitySheet extends StatefulWidget {
  final String currentSelected;

  const SelectActivitySheet({
    super.key,
    required this.currentSelected,
  });

  @override
  State<SelectActivitySheet> createState() => _SelectActivitySheetState();
}

class _SelectActivitySheetState extends State<SelectActivitySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<ActivitySelectionItem> _allItems = [
    // SPORTS
    ActivitySelectionItem(
      title: 'Box Cricket',
      iconAsset: AppAssets.actBoxCricket,
      sportCategory: SportCategory.boxCricket,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Football',
      iconAsset: AppAssets.actFootball,
      sportCategory: SportCategory.football,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Badminton',
      iconAsset: AppAssets.actBadminton,
      sportCategory: SportCategory.badminton,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Pickleball',
      iconAsset: AppAssets.actPickleball,
      sportCategory: SportCategory.pickleball,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Basketball',
      iconAsset: AppAssets.actBasketball,
      sportCategory: SportCategory.basketball,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Volleyball',
      iconAsset: AppAssets.actVolleyball,
      sportCategory: SportCategory.volleyball,
      section: 'SPORTS',
    ),
    ActivitySelectionItem(
      title: 'Table Tennis',
      iconAsset: AppAssets.actTableTennis,
      sportCategory: SportCategory.tableTennis,
      section: 'SPORTS',
    ),

    // OUTDOOR
    ActivitySelectionItem(
      title: 'Cycling',
      iconAsset: AppAssets.actCycling,
      sportCategory: SportCategory.cycling,
      section: 'OUTDOOR',
    ),
    ActivitySelectionItem(
      title: 'Running',
      iconAsset: AppAssets.actRunning,
      sportCategory: SportCategory.running,
      section: 'OUTDOOR',
    ),
    ActivitySelectionItem(
      title: 'Walking',
      iconAsset: AppAssets.actWalking,
      sportCategory: SportCategory.walking,
      section: 'OUTDOOR',
    ),
    ActivitySelectionItem(
      title: 'Hiking',
      iconAsset: AppAssets.actHiking,
      sportCategory: SportCategory.hiking,
      section: 'OUTDOOR',
    ),
    ActivitySelectionItem(
      title: 'Photography Walk',
      iconAsset: AppAssets.actPhotography,
      sportCategory: SportCategory.photography,
      section: 'OUTDOOR',
    ),

    // FUN & SOCIAL
    ActivitySelectionItem(
      title: 'Cafe Hangout',
      iconAsset: AppAssets.actCafeHangout,
      sportCategory: SportCategory.cafeHangout,
      section: 'FUN & SOCIAL',
    ),
    ActivitySelectionItem(
      title: 'Movie',
      iconAsset: AppAssets.actMovie,
      sportCategory: SportCategory.movie,
      section: 'FUN & SOCIAL',
    ),
    ActivitySelectionItem(
      title: 'Gaming',
      iconAsset: AppAssets.actGaming,
      sportCategory: SportCategory.gaming,
      section: 'FUN & SOCIAL',
    ),
    ActivitySelectionItem(
      title: 'Shopping',
      iconAsset: AppAssets.actShopping,
      sportCategory: SportCategory.shopping,
      section: 'FUN & SOCIAL',
    ),
    ActivitySelectionItem(
      title: 'Chilling / Hangout',
      iconAsset: AppAssets.actHangout,
      sportCategory: SportCategory.cafeHangout,
      section: 'FUN & SOCIAL',
    ),

    // FITNESS & WELLNESS
    ActivitySelectionItem(
      title: 'Gym',
      iconAsset: AppAssets.actGym,
      sportCategory: SportCategory.gym,
      section: 'FITNESS & WELLNESS',
    ),
    ActivitySelectionItem(
      title: 'Yoga',
      iconAsset: AppAssets.actYoga,
      sportCategory: SportCategory.yoga,
      section: 'FITNESS & WELLNESS',
    ),
    ActivitySelectionItem(
      title: 'Dance',
      iconAsset: AppAssets.actDance,
      sportCategory: SportCategory.dance,
      section: 'FITNESS & WELLNESS',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _allItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.section.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Group items by section
    final Map<String, List<ActivitySelectionItem>> grouped = {};
    for (var item in filteredItems) {
      grouped.putIfAbsent(item.section, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Select Activity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // Balanced spacing
                ],
              ),
            ),

            // Search Bar (Matching SS 3: Height 50, Capsule shape radius 25, primary search icon)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x05000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        maxLength: 100,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search activities, people or places',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Divider(color: Color(0xFFF1F5F9), height: 1),

            // Categorized List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  for (var entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    ...entry.value.map((item) {
                      final bool isSelected = item.title.toLowerCase() ==
                          widget.currentSelected.toLowerCase();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            Navigator.of(context).pop(item);
                          },
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textDark,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFCBD5E1),
                                  size: 20,
                                ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
