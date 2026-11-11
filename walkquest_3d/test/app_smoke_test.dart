import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkquest_3d/app.dart';
import 'package:walkquest_3d/models/activity_mode.dart';
import 'package:walkquest_3d/models/walk_session.dart';
import 'package:walkquest_3d/screens/settings_screen.dart';
import 'package:walkquest_3d/services/auth_service.dart';
import 'package:walkquest_3d/services/local_repository.dart';
import 'package:walkquest_3d/services/mapbox_api_service.dart';
import 'package:walkquest_3d/state/game_controller.dart';
import 'package:walkquest_3d/state/settings_controller.dart';
import 'package:walkquest_3d/state/tracking_controller.dart';

/// Boots the app in offline mode (no Firebase, no Mapbox token, no GPS) and
/// visits every tab to catch runtime and layout errors.
void main() {
  testWidgets('guest sign-in and every tab renders', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthService(firebaseEnabled: false, prefs: prefs);
    final game = GameController(repo: LocalRepository(prefs), auth: auth);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: auth),
          Provider(create: (_) => MapboxApiService(accessToken: 'test')),
          ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider(create: (_) => TrackingController()),
        ],
        child: const WalkQuestApp(),
      ),
    );

    // Splash → login form.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(find.text('Play as Guest'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Tester');
    await tester.tap(find.text('Play as Guest'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));

    // Map tab (placeholder without a token).
    expect(find.textContaining('Mapbox token missing'), findsOneWidget);
    expect(find.text('Where to, adventurer?'), findsOneWidget);
    expect(game.me.displayName, 'Tester');
    expect(game.dailyQuests, hasLength(3));

    // Record a session so stats/history have content.
    final now = DateTime.now();
    final rewards = await game.recordSession(
      WalkSession(
        id: 's1',
        mode: ActivityMode.walking,
        startedAt: now.subtract(const Duration(minutes: 20)),
        endedAt: now,
        activeDuration: const Duration(minutes: 20),
        distanceM: 1700,
        steps: 2400,
        kcal: 80,
      ),
    );
    expect(rewards.stepCoins, 24);
    expect(rewards.newAchievements.map((a) => a.id), contains('first_steps'));

    for (final tab in ['Quests', 'Stats', 'Social', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
    // Leaderboard includes simulated rivals and me.
    await tester.tap(find.text('Social').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('(you)'), findsOneWidget);

    // Shop tabs on the profile.
    await tester.tap(find.text('Profile').last);
    await tester.pump(const Duration(seconds: 1));
    final tabs = DefaultTabController.of(tester.element(find.text('Skins')));
    for (var i = 1; i <= 3; i++) {
      tabs.animateTo(i);
      for (var f = 0; f < 10; f++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: 'profile tab $i');
    }
    expect(find.text('Quest Reroll'), findsOneWidget);

    // Settings screen.
    await tester.tap(find.byIcon(Icons.settings_rounded));
    for (var f = 0; f < 10; f++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo mode'),
      300,
      scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first,
    );
    expect(find.text('Demo mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
