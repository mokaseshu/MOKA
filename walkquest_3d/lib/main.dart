import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/firestore_repository.dart';
import 'services/local_repository.dart';
import 'services/mapbox_api_service.dart';
import 'services/repository.dart';
import 'state/game_controller.dart';
import 'state/settings_controller.dart';
import 'state/tracking_controller.dart';
import 'utils/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(Env.mapboxAccessToken);

  final prefs = await SharedPreferences.getInstance();

  // Firebase is optional: without google-services.json / GoogleService-Info.plist
  // the app runs fully offline with LocalRepository.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured, running offline: $e');
  }

  final auth = AuthService(firebaseEnabled: firebaseReady, prefs: prefs);
  final GameRepository repo = firebaseReady ? FirestoreRepository() : LocalRepository(prefs);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: auth),
        Provider(create: (_) => MapboxApiService()),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider(
          create: (_) => GameController(repo: repo, auth: auth),
        ),
        ChangeNotifierProvider(create: (_) => TrackingController()),
      ],
      child: const WalkQuestApp(),
    ),
  );
}
