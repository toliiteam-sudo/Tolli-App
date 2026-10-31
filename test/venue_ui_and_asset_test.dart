import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/repositories/venue_repository.dart';
import 'package:tolii/views/venues_landing_screen.dart';
import 'package:tolii/views/select_court_date_slot_screen.dart';
import 'package:tolii/widgets/custom_bottom_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VenueRepository Data & Filtering Unit Tests', () {
    final venueRepo = VenueRepository();

    test('Venue repository success with data', () async {
      final venues = await venueRepo.getVenues();
      expect(venues.isNotEmpty, true);
      expect(venues.first.name, isNotEmpty);
    });

    test('Venue repository sport filtering', () async {
      final badmintonVenues = await venueRepo.getVenues(selectedSport: 'Badminton');
      expect(badmintonVenues.isNotEmpty, true);
      for (final v in badmintonVenues) {
        expect(
          v.supportedSports.any((s) => s.toLowerCase() == 'badminton'),
          true,
        );
      }
    });

    test('Venue repository returning an empty result for unknown query', () async {
      final emptyVenues = await venueRepo.getVenues(searchQuery: 'NonExistentVenue12399');
      expect(emptyVenues.isEmpty, true);
    });

    test('Venue repository stream returns data within timeout threshold', () async {
      final stream = venueRepo.streamVenues(
        timeout: const Duration(milliseconds: 500),
      );
      final firstResult = await stream.first;
      expect(firstResult.isNotEmpty, true);
    });

    test('Venue repository search and filter updates do not return stale results', () async {
      final initial = await venueRepo.getVenues(selectedSport: 'All');
      final cricketOnly = await venueRepo.getVenues(selectedSport: 'Box Cricket');
      final footballOnly = await venueRepo.getVenues(selectedSport: 'Football');

      expect(initial.length >= cricketOnly.length, true);
      expect(cricketOnly.every((v) => v.supportedSports.contains('Box Cricket')), true);
      expect(footballOnly.every((v) => v.supportedSports.contains('Football')), true);
    });

    test('Venue repository getSlots returns generated slots on timeout/fallback', () async {
      final sampleVenue = (await venueRepo.getVenues()).first;
      final sampleCourt = sampleVenue.courts.first;
      final slots = await venueRepo.getSlots(
        venueId: sampleVenue.id,
        court: sampleCourt,
        dateStr: '2026-10-10',
        timeout: const Duration(milliseconds: 500),
      );

      expect(slots.isNotEmpty, true);
      expect(slots.any((s) => s.status == 'AVAILABLE'), true);
    });
  });

  group('Asset Loading & Fallback Widget Tests', () {
    testWidgets('Missing asset image renders errorBuilder fallback widget gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Image.asset(
              'assets/images/non_existent_image_123.png',
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.sports_rounded,
                key: Key('fallback_sport_icon'),
                size: 24,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byKey(const Key('fallback_sport_icon')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CustomBottomNavBar uses Icons.stadium_outlined and renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 3,
              onTap: (index) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.stadium_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('VenuesLandingScreen Widget & UI State Tests', () {
    testWidgets('VenuesLandingScreen loads and displays venue list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenuesLandingScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Venues'), findsOneWidget);
      expect(find.text('Book courts & turf slots'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('VenuesLandingScreen search filter displays empty state when no venues match', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenuesLandingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'NonExistentVenue999');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Venues Found'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      await tester.tap(find.text('Reset Filters'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Venues Found'), findsNothing);
    });

    testWidgets('VenuesLandingScreen sport chip selection updates list without hanging loader', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VenuesLandingScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final badmintonChip = find.text('Badminton').first;
      expect(badmintonChip, findsOneWidget);
      await tester.tap(badmintonChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('SelectCourtDateSlotScreen Date Selector & Slot Loading Tests', () {
    testWidgets('SelectCourtDateSlotScreen date selector renders without overflow', (tester) async {
      final venueRepo = VenueRepository();
      final venues = await venueRepo.getVenues();
      final sampleVenue = venues.first;

      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourtDateSlotScreen(venue: sampleVenue),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Select Date & Time'), findsOneWidget);
      expect(find.text('SELECT DATE'), findsOneWidget);
      expect(find.text('AVAILABLE START TIMES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Selecting a date refreshes slot list without endless spinner', (tester) async {
      final venueRepo = VenueRepository();
      final venues = await venueRepo.getVenues();
      final sampleVenue = venues.first;

      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourtDateSlotScreen(venue: sampleVenue),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap on the 2nd date card
      final dayTwoText = find.text('${DateTime.now().add(const Duration(days: 1)).day}');
      if (dayTwoText.evaluate().isNotEmpty) {
        await tester.tap(dayTwoText.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Verify slot list loaded and no progress indicator remains
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
