import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/activity_model.dart';
import '../utils/app_transitions.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/home_google_fit_card.dart';
import '../widgets/toli_footer.dart';
import '../widgets/toli_header.dart';
import '../widgets/toli_refresh_indicator.dart';
import 'activity_detail_screen.dart';
import 'browse_locations_screen.dart';
import 'community_screen.dart';
import 'create_activity_screen.dart';
import 'nearby_activities_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class _SearchBarSliverDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SearchBarSliverDelegate({
    required this.child,
    this.height = 60.0,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF9FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SearchBarSliverDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _handleRefresh() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Graceful error handling
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      _openCreateActivity();
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _openCreateActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateActivityScreen(),
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
        backgroundColor: const Color(0xFFF9FAFC),
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Index 0: Home Tab
            _buildHomeContent(),

            // Index 1: Nearby Activities Tab
            const NearbyActivitiesScreen(),

            // Index 2: Create Action placeholder
            _buildHomeContent(),

            // Index 3: Community Tab
            const CommunityScreen(),

            // Index 4: Profile Tab
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          onPlusPressed: _openCreateActivity,
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FIXED TOP HEADER BAR (Always visible at the top of Home)
          Container(
            color: const Color(0xFFF9FAFC),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _buildHeader(),
          ),

          // 2. COORDINATED SCROLL AREA
          Expanded(
            child: ToliRefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  // A. "What are you up for?" — Scrolls away underneath fixed header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: _buildMainTitle(),
                    ),
                  ),

                  // B. HOME SEARCH BAR — Pins directly beneath fixed Header when scrolled
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchBarSliverDelegate(
                      child: _buildSearchBar(),
                      height: 60.0,
                    ),
                  ),

                  // C. UPCOMING ACTIVITY CAROUSEL (Manual-swipe horizontal peeking carousel)
                  SliverToBoxAdapter(
                    child: UpcomingActivityCarousel(
                      onFindOutMore: () {
                        setState(() {
                          _currentIndex = 1;
                        });
                      },
                    ),
                  ),

                  // D. MARKETING / PROMOTIONAL BANNER CAROUSEL (Auto-scrolling peeking ad carousel)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 14, bottom: 26),
                      child: MarketingBannerCarousel(),
                    ),
                  ),

                  // E. REMAINING HOME FEED CONTENT
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 5. Explore What You Love
                          _buildExploreCategories(),
                          const SizedBox(height: 24),

                          // 6. Discover Activities
                          _buildDiscoverActivities(),
                          const SizedBox(height: 24),

                          // 7. Google Fit Integration Card
                          _buildGoogleFitCard(),
                          const SizedBox(height: 24),

                          // 8. Popular Near You
                          _buildPopularNearYou(),

                          // 9. Home Bottom Footer
                          const ToliFooter(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final state = AuthController.instance.state;
        final firstName = state.firstName.trim();
        final dispName = state.displayName.trim();
        final name = firstName.isNotEmpty
            ? firstName
            : (dispName.isNotEmpty
                ? dispName.split(' ').first
                : 'User');
        final location = state.selectedCity.isNotEmpty
            ? state.selectedCity
            : 'Bhavnagar';

        return ToliHeader(
          title: 'Hey $name!',
          subtitle: location,
          onAvatarTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are you up for?',
          style: AppTypography.headline.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Find something fun. Find your people.',
          style: AppTypography.bodySubtitle.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          AppTransitions.slidePageRoute(
            const SearchScreen(),
          ),
        );
      },
      child: Container(
        height: 48,
        width: double.infinity,
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
              child: Text(
                'Search activities, sports or venues',
                style: AppTypography.bodySubtitle.copyWith(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreCategories() {
    final categories = [
      {
        'title': 'Box Cricket',
        'icon': AppAssets.cricketPng,
        'bg': AppColors.categoryCricketBg,
      },
      {
        'title': 'Pickleball',
        'icon': AppAssets.pickelballPng,
        'bg': AppColors.categoryPickleballBg,
      },
      {
        'title': 'Café',
        'icon': AppAssets.cafePng,
        'bg': AppColors.categoryCafeBg,
      },
      {
        'title': 'Badminton',
        'icon': AppAssets.badmintonPng,
        'bg': AppColors.categoryCricketBg,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore what you love',
          style: AppTypography.headline.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = categories[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: Container(
                  width: 100,
                  height: 110,
                  decoration: BoxDecoration(
                    color: item['bg'] as Color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0x18000000),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          item['icon'] as String,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item['title'] as String,
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoverActivities() {
    final activities = [
      {
        'title': 'Sports',
        'subtitle': 'Play together, compete together.',
        'image': AppAssets.sportsPng,
      },
      {
        'title': 'Hangout',
        'subtitle': 'Chill, connect, and have fun.',
        'image': AppAssets.hangOutPng,
      },
      {
        'title': 'Creative',
        'subtitle': 'Create, learn, Connect and share.',
        'image': AppAssets.creativePng,
      },
      {
        'title': 'Explore',
        'subtitle': 'Discover places and new experiences.',
        'image': AppAssets.explorePng,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discover activities',
          style: AppTypography.headline.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.22,
          ),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final item = activities[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight, width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['subtitle']!,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(17),
                            bottomRight: Radius.circular(17),
                          ),
                          child: Image.asset(
                            item['image']!,
                            height: 98,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoogleFitCard() {
    return const HomeGoogleFitCard();
  }

  Widget _buildPopularNearYou() {
    final venues = [
      {
        'title': 'Ahmedabad Academy',
        'subtitle': 'Sports Arena',
        'image': AppAssets.ahmedabadPng,
      },
      {
        'title': 'Aangan Badminton',
        'subtitle': '5 Professional Courts',
        'image': AppAssets.aanganBadmintonPng,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular near you',
              style: AppTypography.headline.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textDark,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BrowseLocationsScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'See all',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: venues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final venue = venues[index];
              return Container(
                width: 185,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderLight, width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(17),
                        topRight: Radius.circular(17),
                      ),
                      child: Image.asset(
                        venue['image']!,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            venue['title']!,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            venue['subtitle']!,
                            style: AppTypography.caption.copyWith(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ],
    );
  }
}

class UpcomingActivityCarousel extends StatefulWidget {
  final VoidCallback? onFindOutMore;

  const UpcomingActivityCarousel({
    super.key,
    this.onFindOutMore,
  });

  @override
  State<UpcomingActivityCarousel> createState() => _UpcomingActivityCarouselState();
}

class _UpcomingActivityCarouselState extends State<UpcomingActivityCarousel> {
  late final PageController _pageController;
  int _currentIndex = 200;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 200,
      viewportFraction: 0.85,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActivitiesController(),
      builder: (context, _) {
        final activities = ActivitiesController().userActivities;
        if (activities.isEmpty) {
          return const SizedBox.shrink();
        }

        final int totalCount = activities.length;
        final int displayIndex = (_currentIndex % totalCount) + 1;

        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Section Header Row: WHAT'S COMING UP Title (Left) + Page Indicator (Right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "WHAT'S COMING UP",
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (totalCount > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$displayIndex/$totalCount',
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Carousel or Single Card (Manual Swipe Only - No Timer)
            if (totalCount == 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCard(context, activities[0]),
              )
            else
              SizedBox(
                height: 185,
                child: PageView.builder(
                  controller: _pageController,
                  padEnds: false,
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalCount * 1000,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = activities[index % totalCount];
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, right: 0),
                      child: _buildCard(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, ActivityModel item) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          AppTransitions.slidePageRoute(
            ActivityDetailScreen(activity: item),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 185,
        decoration: BoxDecoration(
          color: AppColors.heroBannerBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Section: Info (Left) + Icon Box (Right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.isHost ? const Color(0xFFFEF3C7) : AppColors.badgePeachBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isHost ? 'HOSTING' : 'UPCOMING ACTIVITY',
                          style: AppTypography.caption.copyWith(
                            color: item.isHost
                                ? const Color(0xFFD97706)
                                : AppColors.badgePeachText,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        item.title,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Date & Time
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Venue
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.venueName ?? 'Bhavnagar',
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Icon Box Right
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    item.iconAsset,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.sports_cricket_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Section: Status & Details Link
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.joinedPlayers}/${item.totalPlayers} Players',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  item.priceText,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MarketingBannerCarousel extends StatefulWidget {
  const MarketingBannerCarousel({super.key});

  @override
  State<MarketingBannerCarousel> createState() => _MarketingBannerCarouselState();
}

class _MarketingBannerCarouselState extends State<MarketingBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 300;
  bool _isUserDragging = false;

  static const List<Map<String, dynamic>> _marketingBanners = [
    {
      'badge': 'TOLII EXCLUSIVE',
      'title': 'Find Your Next Game',
      'subtitle': 'Discover sports and activities happening near you.',
      'gradient': [Color(0xFF063E9E), Color(0xFF0284C7)],
      'asset': AppAssets.sportsPng,
    },
    {
      'badge': 'POPULAR NEAR YOU',
      'title': 'Meet. Play. Repeat.',
      'subtitle': 'Connect with local players for matches today.',
      'gradient': [Color(0xFF0F172A), Color(0xFF063E9E)],
      'asset': AppAssets.playersPng,
    },
    {
      'badge': 'COMMUNITY SPECIAL',
      'title': 'Host Your Own Match',
      'subtitle': 'Gather your squad and book local venues effortlessly.',
      'gradient': [Color(0xFF1E1B4B), Color(0xFF4338CA)],
      'asset': AppAssets.cricketPng,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 300,
      viewportFraction: 0.85,
    );
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (_marketingBanners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_pageController.hasClients || _isUserDragging) return;
      final int currentPage = _pageController.page?.round() ?? _currentIndex;
      final int nextPage = currentPage + 1;
      _currentIndex = nextPage;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_marketingBanners.isEmpty) return const SizedBox.shrink();

    final int totalCount = _marketingBanners.length;
    final int activeDotIndex = _currentIndex % totalCount;

    return Column(
      children: [
        SizedBox(
          height: 175,
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollStartNotification && scrollNotification.dragDetails != null) {
                _isUserDragging = true;
              } else if (scrollNotification is ScrollEndNotification) {
                if (_isUserDragging) {
                  _isUserDragging = false;
                  _startAutoScroll();
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              padEnds: false,
              physics: const BouncingScrollPhysics(),
              itemCount: totalCount * 1000,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final item = _marketingBanners[index % totalCount];
                return Padding(
                  padding: const EdgeInsets.only(left: 16, right: 0),
                  child: _buildCreativeCard(item),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Indicator Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalCount, (index) {
            final bool isSelected = activeDotIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCreativeCard(Map<String, dynamic> item) {
    final List<Color> colors = item['gradient'] as List<Color>;
    final String badge = item['badge'] as String;
    final String title = item['title'] as String;
    final String subtitle = item['subtitle'] as String;
    final String asset = item['asset'] as String;

    return Container(
      width: double.infinity,
      height: 175,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Left Content Block (Non-interactive display only)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: const Color(0xFFE0F2FE),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right Artwork Container
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0x20FFFFFF),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(14),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => const Icon(
                Icons.sports_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

