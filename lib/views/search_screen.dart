import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/activities_controller.dart';
import '../models/activity_model.dart';
import '../utils/app_transitions.dart';
import 'activity_detail_screen.dart';
import 'browse_locations_screen.dart';
import 'community_chat_screen.dart';
import 'community_screen.dart';
import 'select_location_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  List<String> _recentSearches = [];

  late List<CommunityModel> _allSports;
  late List<LocationVenueItem> _allVenues;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadRecentSearches();
    // Auto request focus to open mobile keyboard seamlessly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  String get _recentSearchesKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'recent_searches_$uid';
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  void _addRecentSearch(String term) {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
    });
    _saveRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeData() {
    final controller = ActivitiesController();
    final String userLoc = controller.selectedLocation;

    // 2. Sports & Communities dataset (No People)
    _allSports = [
      CommunityModel(
        id: 'group_1',
        title: '$userLoc Badminton Club',
        lastMessage: 'Anyone playing tonight at 6:30 PM?',
        time: '8:42 PM',
        unreadCount: 3,
        icon: Icons.sports_tennis_rounded,
        iconColor: const Color(0xFF0284C7),
        iconBgColor: const Color(0xFFE0F2FE),
        avatarInitials: 'BB',
        membersCount: '48 active players',
        description: 'Dedicated badminton games and court updates in $userLoc.',
      ),
      CommunityModel(
        id: 'group_2',
        title: 'Box Cricket League $userLoc',
        lastMessage: 'Need 3 more players for tonight!',
        time: '7:18 PM',
        unreadCount: 5,
        icon: Icons.sports_cricket_rounded,
        iconColor: const Color(0xFF16A34A),
        iconBgColor: const Color(0xFFDCFCE7),
        avatarInitials: 'BC',
        membersCount: '64 active players',
        description: 'Casual and tournament box cricket matches in $userLoc.',
      ),
      CommunityModel(
        id: 'group_3',
        title: 'Weekend Cycling Tour 🚴',
        lastMessage: 'Sunday morning ride planned!',
        time: 'Yesterday',
        unreadCount: 2,
        icon: Icons.directions_bike_rounded,
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF3C7),
        avatarInitials: 'WC',
        membersCount: '32 cyclists',
        description: 'Early morning cycling routes around $userLoc.',
      ),
      CommunityModel(
        id: 'group_4',
        title: '$userLoc Football Squad',
        lastMessage: 'Weekend match confirmed.',
        time: 'Yesterday',
        unreadCount: 0,
        icon: Icons.sports_soccer_rounded,
        iconColor: const Color(0xFF7C3AED),
        iconBgColor: const Color(0xFFF3E8FF),
        avatarInitials: 'FS',
        membersCount: '85 players',
        description: '7v7 and 11v11 football games every weekend.',
      ),
    ];

    // 3. Venues / Places dataset
    _allVenues = [
      LocationVenueItem(
        id: 'venue_1',
        name: 'Sports Arena Sidsar',
        address: 'Sidsar Road, $userLoc',
        rating: 4.8,
        reviewsCount: 142,
        distance: '1.8 km',
        imageAsset: AppAssets.pickleballCourtsPng,
      ),
      LocationVenueItem(
        id: 'venue_2',
        name: '$userLoc Sports Club',
        address: 'Jewel Circle, $userLoc',
        rating: 4.6,
        reviewsCount: 98,
        distance: '2.5 km',
        imageAsset: AppAssets.aanganBadmintonPng,
      ),
      LocationVenueItem(
        id: 'venue_3',
        name: 'Victoria Park Turf',
        address: 'Victoria Park, $userLoc',
        rating: 4.4,
        reviewsCount: 56,
        distance: '2.1 km',
        imageAsset: AppAssets.ahmedabadPng,
      ),
      LocationVenueItem(
        id: 'venue_4',
        name: 'ABC Sports Arena',
        address: 'Kalanala, $userLoc',
        rating: 4.7,
        reviewsCount: 110,
        distance: '3.0 km',
        imageAsset: AppAssets.pickleballCourtsPng,
      ),
    ];
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
    });
  }

  void _setSearchQuery(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    setState(() {
      _query = term.trim();
    });
  }

  void _removeRecentSearch(String term) {
    setState(() {
      _recentSearches.remove(term);
    });
  }

  @override
  Widget build(BuildContext context) {
    final queryLower = _query.toLowerCase();

    final liveActivities = ActivitiesController().activities;
    final filteredActivities = liveActivities.where((item) {
      return item.title.toLowerCase().contains(queryLower) ||
          item.subtitle.toLowerCase().contains(queryLower) ||
          (item.venueName ?? '').toLowerCase().contains(queryLower);
    }).toList();

    final filteredSports = _allSports.where((item) {
      return item.title.toLowerCase().contains(queryLower) ||
          item.description.toLowerCase().contains(queryLower) ||
          item.lastMessage.toLowerCase().contains(queryLower);
    }).toList();

    final filteredVenues = _allVenues.where((item) {
      return item.name.toLowerCase().contains(queryLower) ||
          item.address.toLowerCase().contains(queryLower);
    }).toList();

    final int totalResults = filteredActivities.length +
        filteredSports.length +
        filteredVenues.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar & Search Input Box
            _buildSearchHeaderBar(),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Search Content Body
            Expanded(
              child: _query.isEmpty
                  ? _buildPreSearchState()
                  : (totalResults == 0
                      ? _buildEmptyState()
                      : _buildSearchResults(
                          activities: filteredActivities,
                          sports: filteredSports,
                          venues: filteredVenues,
                        )),
            ),
          ],
        ),
      ),
    ),
  );
}

  // Header Bar with Back Button and Integrated Search Box
  Widget _buildSearchHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 12),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Search Field Container
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: AppTypography.bodyText.copyWith(
                        color: AppColors.textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search activities, sports or venues',
                        hintStyle: AppTypography.bodySubtitle.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _query = val;
                        });
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
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

  // Pre-search state: RECENT SEARCHES, EXPLORE CATEGORIES, POPULAR NEAR YOU
  Widget _buildPreSearchState() {
    final String userLoc = ActivitiesController().selectedLocation;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. RECENT SEARCHES (if available)
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT SEARCHES',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: const Color(0xFF64748B),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((term) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _setSearchQuery(term);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              term,
                              style: AppTypography.bodySubtitle.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(term),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // 2. EXPLORE CATEGORIES (No People)
          Text(
            'EXPLORE',
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCategoryPill(
                icon: Icons.bolt_rounded,
                label: 'Activities',
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                onTap: () => _setSearchQuery('Badminton'),
              ),
              const SizedBox(width: 8),
              _buildCategoryPill(
                icon: Icons.sports_cricket_rounded,
                label: 'Sports',
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                onTap: () => _setSearchQuery('Box Cricket'),
              ),
              const SizedBox(width: 8),
              _buildCategoryPill(
                icon: Icons.location_on_rounded,
                label: 'Venues',
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () => _setSearchQuery('Sports Club'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 3. POPULAR NEAR YOU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'POPULAR NEAR YOU',
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    userLoc,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ActivitiesController().activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  'No popular activities near you yet',
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            Column(
              children: ActivitiesController().activities.take(3).map((act) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildPopularCardRow(
                    title: act.title,
                    subtitle: act.subtitle,
                    tag: act.skillLevel.label,
                    iconAsset: act.iconAsset,
                    onTap: () {
                      _addRecentSearch(act.title);
                      Navigator.of(context).push(
                        AppTransitions.slidePageRoute(
                          ActivityDetailScreen(activity: act),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.bodyText.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularCardRow({
    required String title,
    required String subtitle,
    required String tag,
    String? iconAsset,
    IconData? iconData,
    bool isVenue = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Icon / Asset box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: isVenue && iconAsset != null
                  ? Image.asset(iconAsset, fit: BoxFit.cover)
                  : (iconAsset != null
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(iconAsset, fit: BoxFit.contain),
                        )
                      : Icon(iconData, size: 22, color: AppColors.primary)),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Tag Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live Search Results View (Activities, Sports, Venues ONLY)
  Widget _buildSearchResults({
    required List<ActivityModel> activities,
    required List<CommunityModel> sports,
    required List<LocationVenueItem> venues,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. ACTIVITIES SECTION
        if (activities.isNotEmpty) ...[
          _buildSectionHeader('ACTIVITIES', activities.length),
          ...activities.map((item) => _buildActivityCardRow(item)),
          const SizedBox(height: 18),
        ],

        // 2. SPORTS & GAMES SECTION
        if (sports.isNotEmpty) ...[
          _buildSectionHeader('SPORTS & GAMES', sports.length),
          ...sports.map((item) => _buildSportCardRow(item)),
          const SizedBox(height: 18),
        ],

        // 3. VENUES & PLACES SECTION
        if (venues.isNotEmpty) ...[
          _buildSectionHeader('VENUES & PLACES', venues.length),
          ...venues.map((item) => _buildVenueCardRow(item)),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Activity Compact Result Card
  Widget _buildActivityCardRow(ActivityModel activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              activity.iconAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.sports_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
          title: Text(
            activity.title,
            style: AppTypography.bodyText.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            activity.subtitle,
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: activity.skillLevel.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              activity.skillLevel.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activity.skillLevel.textColor,
              ),
            ),
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              AppTransitions.slidePageRoute(
                ActivityDetailScreen(activity: activity),
              ),
            );
          },
        ),
      ),
    );
  }

  // Sport & Game Compact Result Card
  Widget _buildSportCardRow(CommunityModel sport) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sport.iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sport.icon, size: 22, color: sport.iconColor),
          ),
          title: Text(
            sport.title,
            style: AppTypography.bodyText.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${sport.membersCount} · Sports Community',
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              AppTransitions.slidePageRoute(
                CommunityChatScreen(
                  title: sport.title,
                  membersCount: sport.membersCount,
                  avatarInitials: sport.avatarInitials,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Venue / Place Compact Result Card
  Widget _buildVenueCardRow(LocationVenueItem venue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              venue.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.location_on_rounded,
                color: AppColors.primary,
              ),
            ),
          ),
          title: Text(
            venue.name,
            style: AppTypography.bodyText.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${venue.address} · ${venue.distance}',
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 3),
              Text(
                '${venue.rating}',
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              AppTransitions.slidePageRoute(
                SelectLocationScreen(currentSelectedVenue: venue.name),
              ),
            );
          },
        ),
      ),
    );
  }

  // Polished Empty State View
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 34,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No results found',
            style: AppTypography.headline.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find anything matching "$_query".\nTry searching for activities, sports, or venues nearby.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySubtitle.copyWith(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              'Explore Activities',
              style: AppTypography.buttonText.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
