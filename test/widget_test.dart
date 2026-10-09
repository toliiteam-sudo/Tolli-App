import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tolii/main.dart';
import 'package:tolii/constants/app_assets.dart';
import 'package:tolii/controllers/activities_controller.dart';
import 'package:tolii/views/home_screen.dart';
import 'package:tolii/views/nearby_activities_screen.dart';
import 'package:tolii/widgets/custom_bottom_nav_bar.dart';
import 'package:tolii/widgets/filters_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ToliiApp());
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(ToliiApp), findsOneWidget);
  });

  testWidgets('HomeScreen renders floating overlay nav bar and switches tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Home Tab Content & Floating Nav Bar
    expect(find.text('What are you up for?'), findsOneWidget);
    expect(find.byType(CustomBottomNavBar), findsOneWidget);

    // Tap on Activities Icon (2nd icon)
    final activitiesIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == AppAssets.activitiesNavPng,
    );
    expect(activitiesIcon, findsOneWidget);
    await tester.tap(activitiesIcon);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Activities Screen Elements
    expect(find.text('Nearby activities'), findsOneWidget);

    // Tap on Community Icon
    final communityIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == AppAssets.communityNavPng,
    );
    expect(communityIcon, findsOneWidget);
    await tester.tap(communityIcon);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CustomBottomNavBar), findsOneWidget);

    // Tap on Profile Icon
    final profileIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == AppAssets.profileNavPng,
    );
    expect(profileIcon, findsOneWidget);
    await tester.tap(profileIcon);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('My Profile'), findsOneWidget);

    // Tap back on Home Icon
    final homeIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == AppAssets.homeNavPng,
    );
    expect(homeIcon, findsOneWidget);
    await tester.tap(homeIcon);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('What are you up for?'), findsOneWidget);
  });

  testWidgets('FiltersBottomSheet renders all filter sections accurately',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FiltersBottomSheet(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Title
    expect(find.text('Filters'), findsOneWidget);

    // Verify Sections
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('When'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Skill Level'), findsOneWidget);
    expect(find.text('Players Needed'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);

    // Verify Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Any Time'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Any Level'), findsOneWidget);
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);

    // Verify Bottom Actions
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    // Test selection
    await tester.tap(find.text('Fitness'));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Clear all'));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('NearbyActivitiesScreen renders all UI elements accurately',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NearbyActivitiesScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Header
    expect(find.text('Hey User!'), findsOneWidget);
    expect(find.text('Bhavnagar'), findsOneWidget);

    // Verify Date selector & Month badge
    final String currentMonth = const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][DateTime.now().month - 1];
    expect(find.text(currentMonth), findsWidgets);
    expect(find.text('TODAY'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All Activities'), findsOneWidget);
    expect(find.text('Within 25 km'), findsOneWidget);
    expect(find.text('Any time'), findsOneWidget);

    // Verify Section Header
    expect(find.text('Nearby activities'), findsOneWidget);

    // Test Filter Selection Interaction
    await tester.tap(find.text('Within 25 km'));
    await tester.pump(const Duration(milliseconds: 200));
  });

  test('ActivitiesController manages dates and filters correctly', () {
    final controller = ActivitiesController();
    controller.reset();
    expect(controller.selectedDateIndex, 0);
    expect(controller.dates.first.isSelected, isTrue);

    controller.selectDate(2);
    expect(controller.selectedDateIndex, 2);
    expect(controller.dates[2].isSelected, isTrue);
    expect(controller.dates[0].isSelected, isFalse);

    controller.toggleFilter('distance');
    expect(controller.filters.firstWhere((f) => f.id == 'distance').isSelected, isTrue);
  });
}
