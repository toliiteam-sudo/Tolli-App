import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../models/location_venue_item.dart';

class SelectLocationScreen extends StatefulWidget {
  final String currentSelectedVenue;

  const SelectLocationScreen({
    super.key,
    required this.currentSelectedVenue,
  });

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  late String _selectedVenueId;
  LocationVenueItem? _customVenue;

  final List<String> _filters = ['All', 'Nearby', 'Bookable', 'Top Rated'];

  final List<LocationVenueItem> _venues = const [
    LocationVenueItem(
      id: 'venue_decide_later',
      name: 'Decide location later',
      address: 'Host will specify location before match',
      rating: 5.0,
      reviewsCount: 1,
      distance: 'TBD',
      imageAsset: AppAssets.ahmedabadPng,
    ),
    LocationVenueItem(
      id: 'venue_1',
      name: 'Sports Arena Sidsar',
      address: 'Sidsar Road, Bhavnagar',
      rating: 4.8,
      reviewsCount: 142,
      distance: '2.3 km',
      imageAsset: AppAssets.pickleballCourtsPng,
    ),
    LocationVenueItem(
      id: 'venue_2',
      name: 'Bhavnagar Sports Club',
      address: 'Jewel Circle, Bhavnagar',
      rating: 4.5,
      reviewsCount: 88,
      distance: '3.1 km',
      imageAsset: AppAssets.aanganBadmintonPng,
    ),
    LocationVenueItem(
      id: 'venue_3',
      name: 'Victoria Park Turf',
      address: 'Victoria Park, Bhavnagar',
      rating: 4.2,
      reviewsCount: 34,
      distance: '4.5 km',
      imageAsset: AppAssets.ahmedabadPng,
    ),
    LocationVenueItem(
      id: 'venue_4',
      name: 'Ahmedabad Academy',
      address: 'Bodakdev, Ahmedabad',
      rating: 4.9,
      reviewsCount: 210,
      distance: '1.5 km',
      imageAsset: AppAssets.ahmedabadPng,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final query = widget.currentSelectedVenue.trim();
    final match = _venues.firstWhere(
      (v) => v.name.toLowerCase() == query.toLowerCase() || v.id == query,
      orElse: () {
        if (query.isNotEmpty &&
            query.toLowerCase() != 'bhavnagar' &&
            query.toLowerCase() != 'select location') {
          final custom = LocationVenueItem(
            id: 'venue_custom_initial',
            name: query,
            address: 'Arranged location · Bhavnagar',
            rating: 5.0,
            reviewsCount: 1,
            distance: 'Custom',
            imageAsset: AppAssets.pickleballCourtsPng,
          );
          _customVenue = custom;
          return custom;
        }
        return _venues.firstWhere((v) => v.id == 'venue_1', orElse: () => _venues.first);
      },
    );
    _selectedVenueId = match.id;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocationVenueItem> get _filteredVenues {
    final query = _searchController.text.trim().toLowerCase();
    List<LocationVenueItem> list = List.from(_venues);
    if (_customVenue != null && !list.any((v) => v.id == _customVenue!.id)) {
      list.insert(1, _customVenue!);
    }

    if (_selectedFilter == 'Nearby') {
      list = list.where((v) => v.id == 'venue_decide_later' || v.distance.contains('1.') || v.distance.contains('2.')).toList();
    } else if (_selectedFilter == 'Bookable') {
      list = list.where((v) => v.id != 'venue_decide_later' && v.id != 'venue_custom_initial' && v.id != 'venue_custom_search').toList();
    } else if (_selectedFilter == 'Top Rated') {
      list = list.where((v) => v.rating >= 4.5).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((v) =>
        v.name.toLowerCase().contains(query) ||
        v.address.toLowerCase().contains(query)
      ).toList();
    }

    return list;
  }

  LocationVenueItem _getSelectedVenue() {
    if (_customVenue != null && _selectedVenueId == _customVenue!.id) {
      return _customVenue!;
    }
    return _venues.firstWhere(
      (v) => v.id == _selectedVenueId,
      orElse: () => _customVenue ?? _venues.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredVenues;
    final searchQuery = _searchController.text.trim();
    final bool hasExactSearchMatch = filteredList.any((v) => v.name.toLowerCase() == searchQuery.toLowerCase());

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textDark,
            ),
          ),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textDark,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search venues, grounds or custom location',
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
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
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

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filters.map((filter) {
                  final bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Venues Selection List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // If user entered custom search query not matching any venue, show "Use custom location" card
                  if (searchQuery.isNotEmpty && !hasExactSearchMatch) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final customItem = LocationVenueItem(
                          id: 'venue_custom_search',
                          name: searchQuery,
                          address: 'Host-arranged custom ground · Bhavnagar',
                          rating: 5.0,
                          reviewsCount: 1,
                          distance: 'Arranged',
                          imageAsset: AppAssets.pickleballCourtsPng,
                        );
                        setState(() {
                          _customVenue = customItem;
                          _selectedVenueId = customItem.id;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedVenueId == 'venue_custom_search'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFBBF7D0),
                            width: _selectedVenueId == 'venue_custom_search' ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_location_alt_rounded,
                                color: Color(0xFF16A34A),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Use "$searchQuery"',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF166534),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Specify this as an already-arranged venue',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedVenueId == 'venue_custom_search'
                                    ? const Color(0xFF16A34A)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _selectedVenueId == 'venue_custom_search'
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF86EFAC),
                                  width: 1.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _selectedVenueId == 'venue_custom_search'
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Venue List Items
                  ...filteredList.map((venue) {
                    final bool isSelected = venue.id == _selectedVenueId;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedVenueId = venue.id;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.025),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                venue.imageAsset,
                                width: 68,
                                height: 68,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venue.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    venue.address,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${venue.rating} (${venue.reviewsCount})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        venue.distance,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Selection Radio Check Icon
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFCBD5E1),
                                  width: 1.8,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (filteredList.isEmpty && searchQuery.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No venues found for "$_selectedFilter"',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Confirm Venue Sticky Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final selected = _getSelectedVenue();
                  Navigator.of(context).pop(selected);
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
