// Design-preview entry point: seeds a player with sample progress and opens a
// chosen screen, so the UI can be reviewed (e.g. on Flutter web) without
// walking anywhere.
//
//   flutter run -d chrome -t preview/main_preview.dart \
//     --web-browser-flag=--window-size=390,844
//   ...?screen=home|route|quest|reward&theme=light|dark
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkquest_3d/models/activity_mode.dart';
import 'package:walkquest_3d/models/app_settings.dart';
import 'package:walkquest_3d/models/lat_lng.dart';
import 'package:walkquest_3d/models/route_plan.dart';
import 'package:walkquest_3d/models/walk_session.dart';
import 'package:walkquest_3d/screens/active_quest_screen.dart';
import 'package:walkquest_3d/screens/home_shell.dart';
import 'package:walkquest_3d/screens/splash_login_screen.dart';
import 'package:walkquest_3d/services/auth_service.dart';
import 'package:walkquest_3d/services/catalog.dart';
import 'package:walkquest_3d/services/local_repository.dart';
import 'package:walkquest_3d/services/mapbox_api_service.dart';
import 'package:walkquest_3d/services/quest_service.dart';
import 'package:walkquest_3d/services/territory_service.dart';
import 'package:walkquest_3d/state/game_controller.dart';
import 'package:walkquest_3d/state/settings_controller.dart';
import 'package:walkquest_3d/state/tracking_controller.dart';
import 'package:walkquest_3d/utils/app_theme.dart';
import 'package:walkquest_3d/utils/env.dart';
import 'package:walkquest_3d/utils/geo_utils.dart';
import 'package:walkquest_3d/widgets/quest_map_view.dart';
import 'package:walkquest_3d/widgets/reward_popup.dart';
import 'package:walkquest_3d/widgets/route_preview_panel.dart';
import 'package:walkquest_3d/services/gamification_service.dart';

const _origin = LatLng(37.7694, -122.4862); // Golden Gate Park, SF

/// A ~1.2 km walking path with a few bends.
final _route = <LatLng>[
  _origin,
  GeoUtils.destinationPoint(_origin, 260, 80),
  GeoUtils.destinationPoint(GeoUtils.destinationPoint(_origin, 260, 80), 380, 35),
  GeoUtils.destinationPoint(GeoUtils.destinationPoint(GeoUtils.destinationPoint(_origin, 260, 80), 380, 35), 520, 95),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(Env.mapboxAccessToken);
  final q = Uri.base.queryParameters;
  final screen = q['screen'] ?? 'home';
  final dark = q['theme'] == 'dark';

  final prefs = await SharedPreferences.getInstance();
  if (screen == 'login') {
    await prefs.remove('wq_local_uid');
    final auth = AuthService(firebaseEnabled: false, prefs: prefs);
    runApp(
      MultiProvider(
        providers: [
          Provider.value(value: auth),
          ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
          ChangeNotifierProvider(
            create: (_) => GameController(repo: LocalRepository(prefs), auth: auth),
          ),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), home: const SplashLoginScreen()),
      ),
    );
    return;
  }
  await prefs.setString('wq_local_uid', 'preview_user');
  final auth = AuthService(firebaseEnabled: false, prefs: prefs);
  final game = GameController(repo: LocalRepository(prefs), auth: auth);
  final settings = SettingsController(prefs);
  await settings.update((s) => s.copyWith(themeMode: dark ? ThemeMode.dark : ThemeMode.light, demoMode: true));
  await game.signIn('preview_user', displayName: 'Mia');
  await _seed(game);

  final plan = RoutePlan(
    origin: _origin,
    destination: const PlaceResult(
      name: 'Stow Lake Boathouse',
      address: '50 Stow Lake Dr, San Francisco, CA',
      location: LatLng(0, 0),
    ),
    geometry: _route,
    distanceM: GeoUtils.pathLengthM(_route),
    elevationProfile: const [62, 64, 67, 71, 76, 80, 83, 81, 78, 79, 84, 88, 91, 89, 86, 84],
  );

  final tracking = TrackingController();
  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: auth),
        Provider(create: (_) => MapboxApiService()),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: tracking),
      ],
      child: _PreviewApp(screen: screen, plan: plan),
    ),
  );
}

/// Builds a believable two-week history through the real reward pipeline.
Future<void> _seed(GameController game) async {
  if (game.sessions.isNotEmpty) return;
  final now = DateTime.now();
  final days = [13, 12, 10, 9, 8, 6, 5, 4, 3, 2, 1, 0];
  final dists = <double>[2100, 3400, 1800, 5200, 2600, 4100, 6300, 2900, 3800, 7400, 5100, 3300];
  for (var i = 0; i < days.length; i++) {
    final running = i % 3 == 1;
    final d = dists[i];
    final speed = running ? 9.6 : 5.1;
    final dur = Duration(seconds: (d / 1000 / speed * 3600).round());
    final start = DateTime(now.year, now.month, now.day, 7 + i % 5).subtract(Duration(days: days[i]));
    final captured = i == 4 || i == 9
        ? [
            TerritoryService.build(
              ring: [
                for (var a = 0; a < 360; a += 30)
                  GeoUtils.destinationPoint(GeoUtils.destinationPoint(_origin, 300.0 * i, 60), 90, a.toDouble()),
              ],
              ownerUid: game.me.uid,
            ),
          ]
        : const <dynamic>[];
    await game.recordSession(
      WalkSession(
        id: 'seed_$i',
        mode: running ? ActivityMode.running : ActivityMode.walking,
        startedAt: start,
        endedAt: start.add(dur),
        activeDuration: dur,
        distanceM: d,
        steps: (d / (running ? 1.0 : 0.7) * (0.96 + (i % 4) * 0.02)).round(),
        kcal: d / 1000 * (running ? 70 : 52),
        path: _route,
        destinationName: i % 2 == 0 ? ['Stow Lake', 'Ocean Beach', 'Japanese Tea Garden'][i % 3] : null,
        reachedDestination: i % 2 == 0,
      ),
      captured: captured.cast(),
    );
  }
  // Start the first story chapter so the board shows an in-progress quest.
  await game.beginStoryQuest(QuestService.storyQuests.first, _origin);
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.screen, required this.plan});
  final String screen;
  final RoutePlan plan;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsController, ThemeMode>((s) => s.value.themeMode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: switch (screen) {
        'route' => _RoutePreview(plan: plan),
        'quest' => _QuestLauncher(plan: plan),
        'reward' => const _RewardLauncher(),
        _ => const HomeShell(),
      },
    );
  }
}

class _RoutePreview extends StatefulWidget {
  const _RoutePreview({required this.plan});
  final RoutePlan plan;

  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  ActivityMode _mode = ActivityMode.walking;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final game = context.watch<GameController>();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: QuestMapView(
              initialCenter: _origin,
              dark: Theme.of(context).brightness == Brightness.dark,
              terrain: true,
              routeColor: game.trailColor,
              onReady: (l) {
                l.setRoute(widget.plan.geometry);
                l.setDestination(widget.plan.geometry.last);
                l.fitRoute(widget.plan.geometry);
              },
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: RoutePreviewPanel(
              plan: widget.plan,
              settings: settings,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
              onStart: () {},
              onFlyOver: () {},
              onClose: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestLauncher extends StatefulWidget {
  const _QuestLauncher({required this.plan});
  final RoutePlan plan;

  @override
  State<_QuestLauncher> createState() => _QuestLauncherState();
}

class _QuestLauncherState extends State<_QuestLauncher> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final game = context.read<GameController>();
    final AppSettings settings = context.read<SettingsController>().value.copyWith(voiceCues: false);
    final quest = await game.addDestinationQuest(widget.plan);
    if (!mounted) return;
    await context.read<TrackingController>().start(
      mode: ActivityMode.walking,
      settings: settings,
      ownerUid: game.me.uid,
      plan: widget.plan,
      quest: quest,
    );
    if (mounted) setState(() => _started = true);
  }

  @override
  Widget build(BuildContext context) =>
      _started ? const ActiveQuestScreen() : const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _RewardLauncher extends StatefulWidget {
  const _RewardLauncher();

  @override
  State<_RewardLauncher> createState() => _RewardLauncherState();
}

class _RewardLauncherState extends State<_RewardLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final story = QuestService.storyQuests.first;
      showRewardPopup(
        context,
        RewardSummary(
          stepCoins: 33,
          questCoins: story.rewardCoins,
          achievementCoins: 150,
          xp: 520,
          levelBefore: 6,
          levelAfter: 7,
          completedQuests: [story],
          territoriesCaptured: 1,
        ).withAchievement('day_10k'),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const HomeShell();
}

extension on RewardSummary {
  RewardSummary withAchievement(String id) => RewardSummary(
    stepCoins: stepCoins,
    questCoins: questCoins,
    achievementCoins: achievementCoins,
    xp: xp,
    levelBefore: levelBefore,
    levelAfter: levelAfter,
    completedQuests: completedQuests,
    territoriesCaptured: territoriesCaptured,
    newAchievements: [
      for (final a in Catalog.achievements)
        if (a.id == id) a,
    ],
  );
}
