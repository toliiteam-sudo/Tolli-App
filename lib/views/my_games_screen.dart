import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../controllers/activities_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/toli_empty_state.dart';
import 'create_activity_screen.dart';

class MyGamesScreen extends StatefulWidget {
  const MyGamesScreen({super.key});

  @override
  State<MyGamesScreen> createState() => _MyGamesScreenState();
}

class _MyGamesScreenState extends State<MyGamesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ActivitiesController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = ActivitiesController();
    _controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userGames = _controller.userActivities;

    final upcomingGames = userGames.where((a) => !a.isHost).toList();
    final hostedGames = userGames.where((a) => a.isHost).toList();

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
          'My Games',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Joined'),
            Tab(text: 'Hosted'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // 1. Upcoming Tab
            _buildGamesList(
              userGames,
              emptyState: ToliEmptyState.upcoming(
                onCreateActivity: _openCreateActivity,
                onExplore: _popAndExplore,
              ),
            ),

            // 2. Joined Tab
            _buildGamesList(
              upcomingGames,
              emptyState: ToliEmptyState.joined(
                onExplore: _popAndExplore,
              ),
            ),

            // 3. Hosted Tab
            _buildGamesList(
              hostedGames,
              emptyState: ToliEmptyState.hosted(
                onCreateActivity: _openCreateActivity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateActivityScreen(),
      ),
    );
  }

  void _popAndExplore() {
    Navigator.of(context).pop();
  }

  Widget _buildGamesList(List games, {required Widget emptyState}) {
    if (games.isEmpty) {
      return emptyState;
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: games.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final activity = games[index];
        return ActivityCard(activity: activity);
      },
    );
  }
}
