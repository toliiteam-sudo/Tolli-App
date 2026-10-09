import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

class LocationVenueItem {
  final String id;
  final String name;
  final String address;
  final double rating;
  final int reviewsCount;
  final String distance;
  final String imageAsset;

  const LocationVenueItem({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.reviewsCount,
    required this.distance,
    required this.imageAsset,
  });
}

class BrowseLocationsScreen extends StatelessWidget {
  const BrowseLocationsScreen({super.key});

  final List<LocationVenueItem> _venues = const [
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
    LocationVenueItem(
      id: 'venue_5',
      name: 'Aangan Badminton Arena',
      address: 'Kalanala, Bhavnagar',
      rating: 4.7,
      reviewsCount: 95,
      distance: '2.8 km',
      imageAsset: AppAssets.aanganBadmintonPng,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          'Popular Places',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: _venues.length,
          itemBuilder: (context, index) {
            final venue = _venues[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Venue Thumbnail Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      venue.imageAsset,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        width: 72,
                        height: 72,
                        color: const Color(0xFFEEF4FF),
                        child: const Icon(
                          Icons.sports_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Venue Details (Name, Address, Rating, Distance)
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
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${venue.rating}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${venue.reviewsCount})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 2),
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
