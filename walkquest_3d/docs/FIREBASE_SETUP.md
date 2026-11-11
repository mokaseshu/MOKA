# Firebase setup

WalkQuest runs without Firebase. If initialization fails, it switches to an
offline `LocalRepository` (SharedPreferences, with simulated leaderboard
rivals). To turn on accounts, cloud saves, friends and guilds:

## 1. Create the project

1. Go to <https://console.firebase.google.com> and click **Add project**.
2. **Authentication → Sign-in method:** enable **Anonymous** and **Email/Password**.
3. **Firestore Database → Create database** (production mode, a region near your players).

## 2. Connect the Flutter app

```bash
dart pub global activate flutterfire_cli
npm i -g firebase-tools && firebase login
cd walkquest_3d
flutterfire configure --platforms=android,ios \
  --android-package-name=com.walkquest.walkquest_3d \
  --ios-bundle-id=com.walkquest.walkquest3d
```

This writes `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist`, and applies the Google Services Gradle
plugin. `main.dart` calls `Firebase.initializeApp()` with no options, which
reads those native files.

> If you prefer the generated `lib/firebase_options.dart`, change the call to
> `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

Confirm the bundle id in Xcode (Runner → Signing & Capabilities). It must match the iOS app registered in Firebase.

## 3. Deploy rules, indexes and Cloud Functions

```bash
cd walkquest_3d/firebase
firebase use --add            # pick your project
(cd functions && npm install)
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Scheduled functions (`weeklyReset`) require the **Blaze** plan.

## 4. Data model

| Path | Contents | Access |
|---|---|---|
| `users/{uid}` | `UserProfile`: displayName, friendCode, avatar, coins, xp, level, lifetime totals, dailySteps, weekId, weeklySteps, ownedItems, unlockedAchievements, powerUps | read: signed-in; write: owner |
| `users/{uid}/sessions/{id}` | `WalkSession`: mode, start/end, activeSeconds, distanceM, steps, kcal, coins/xp earned, `path` as flat `[lng,lat,…]` | owner |
| `users/{uid}/quests/{id}` | `Quest`: type, category, target, progress, rewards, status, destination | owner |
| `users/{uid}/territories/{id}` | `Territory`: name, polygon (flat), areaM2, capturedAt | read: signed-in; write: owner |
| `users/{uid}/friends/{friendUid}` | `{since}` | owner; or the friend adding themselves |
| `friendCodes/{code}` | `{uid}` | read: signed-in; write: the uid itself |
| `guilds/{id}` | `Guild`: name, emoji, ownerUid, memberUids, goalSteps, progressSteps | read: signed-in; join: add self only; progress: Functions |
| `challenges/{id}` | `Challenge`: from/to uid + name, targetSteps, status | the two participants |

Paths are stored as flat number arrays because Firestore does not allow nested
arrays. `firestore.indexes.json` turns off indexing on `path` and `polygon`,
which keeps writes cheap.

## 5. Cloud Functions

| Function | Trigger | What it does |
|---|---|---|
| `onSessionCreated` | new session doc | Anti-cheat: average speed > 25 km/h, or steps/m outside 0.4–2.2, flags the session and claws back its rewards. Otherwise adds the session's steps to each of the player's guilds. |
| `weeklyReset` | Mondays 00:00 UTC | Sets `weeklySteps` and guild progress to 0. The client also rolls over when `weekId` changes. |
| `onChallengeAccepted` | challenge status → accepted | Logging hook where FCM notifications can be added. |

## 6. Local development with emulators

```bash
cd walkquest_3d/firebase
firebase emulators:start --only auth,firestore,functions
```

To point the app at the emulators, add this after `Firebase.initializeApp()`
in `main.dart`:

```dart
FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);      // Android emulator host
FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
```
