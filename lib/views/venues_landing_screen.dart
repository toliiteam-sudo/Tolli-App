import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/activity_model.dart';
import '../models/venue_model.dart';
import '../repositories/venue_repository.dart';
import '../widgets/filter_chips_bar.dart';
import '../widgets/toli_empty_state.dart';
import '../widgets/toli_header.dart';
import '../widgets/toli_refresh_indicator.dart';
import '../utils/app_transitions.dart';
import 'venue_detail_screen.dart';

class VenuesLandingScreen extends StatefulWidget {
  const VenuesLandingScreen({super.key});

  @override
  State<VenuesLandingScreen> createState() => _VenuesLandingScreenState();
}

class _VenuesLandingScreenState extends State<VenuesLandingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final VenueRepository _venueRepo = VenueRepository();

  String _selectedSport = 'All';
  String _searchQuery = '';
  late Stream<List<VenueModel>> _venuesStream;

  final List<String> _sportsList = [
    'All',
    'Box Cricket',
    'Pickleball',
    'Badminton',
    'Football',
    'Tennis',
  ];

  IconData _getIconForSport(String sport) {
    switch (sport) {
      case 'Box Cricket':
        return Icons.sports_cricket_rounded;
      case 'Pickleball':
        return Icons.sports_tennis_rounded;
      case 'Badminton':
        return Icons.sports_baseball_rounded;
      case 'Football':
        return Icons.sports_soccer_rounded;
      case 'Tennis':
        return Icons.sports_tennis_rounded;
      default:
        return Icons.sports_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    _venuesStream = _venueRepo.streamVenues(
      selectedSport: _selectedSport,
      searchQuery: _searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openVenueDetails(VenueModel venue) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      AppTransitions.slidePageRoute(
        VenueDetailScreen(venue: venue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ToliHeader(
                  title: 'Venues',
                  subtitle: 'Book courts & turf slots',
                  showAvatar: false,
                ),
              ),

              // 2. Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          maxLength: 100,
                          style: AppTypography.bodySubtitle.copyWith(
                            color: AppColors.textDark,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search venues, sports or locations',
                            hintStyle: AppTypography.bodySubtitle.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                              _updateStream();
                            });
                          },
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _updateStream();
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

              // 3. Sport Selector Chips Bar (Matching Explore filter design)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilterChipsBar(
                  filters: _sportsList.map((sport) {
                    return FilterChipModel(
                      id: sport,
                      label: sport,
                      icon: _getIconForSport(sport),
                      isSelected: _selectedSport == sport,
                    );
                  }).toList(),
                  onFilterSelected: (sportId) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedSport = sportId;
                      _updateStream();
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),

              // 4. Venues List View
              Expanded(
                child: StreamBuilder<List<VenueModel>>(
                  stream: _venuesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ToliEmptyState(
                        title: 'Unable to Load Venues',
                        subtitle: 'Something went wrong. Please check your connection and try again.',
                        mainIcon: Icons.wifi_off_rounded,
                        primaryCtaText: 'Retry',
                        onPrimaryCtaPressed: () {
                          setState(() {
                            _updateStream();
                          });
                        },
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final venues = snapshot.data ?? VenueRepository.defaultVenues;

                    if (venues.isEmpty) {
                      return ToliEmptyState(
                        title: 'No Venues Found',
                        subtitle: 'Try tweaking your search or sport filter.',
                        mainIcon: Icons.stadium_outlined,
                        primaryCtaText: 'Reset Filters',
                        onPrimaryCtaPressed: () {
                          setState(() {
                            _selectedSport = 'All';
                            _searchController.clear();
                            _searchQuery = '';
                            _updateStream();
                          });
                        },
                      );
                    }

                    return ToliRefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(const Duration(milliseconds: 800));
                        if (mounted) {
                          setState(() {
                            _updateStream();
                          });
                        }
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          MediaQuery.of(context).padding.bottom + 100,
                        ),
                        itemCount: venues.length,
                        itemBuilder: (context, index) {
                          final venue = venues[index];
                          return _buildVenueCard(venue);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVenueCard(VenueModel venue) {
    final imageAsset = venue.imageAssets.isNotEmpty ? venue.imageAssets.first : '';
    final startingPriceRupees = (venue.startingPricePaise / 100).toInt();

    return GestureDetector(
      onTap: () => _openVenueDetails(venue),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Venue Cover Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    topRight: Radius.circular(19),
                  ),
                  child: imageAsset.isEmpty
                      ? Container(
                          height: 160,
                          width: double.infinity,
                          color: const Color(0xFFEEF4FF),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        )
                      : Image.asset(
                          imageAsset,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            height: 160,
                            width: double.infinity,
                            color: const Color(0xFFEEF4FF),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sports_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
                // Rating Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${venue.rating}',
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          ' (${venue.reviewsCount})',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Details Container
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue.address,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sports Chips Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: venue.supportedSports.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 12),

                  // Price & Action Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Starts from',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '₹$startingPriceRupees / hr',
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x20063E9E),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Book Slot',
                              style: AppTypography.buttonText.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
