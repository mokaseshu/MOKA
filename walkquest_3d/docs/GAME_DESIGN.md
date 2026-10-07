# WalkQuest 3D — Game Design Document

> Real-world walking & running RPG. Pick a destination on a 3D map, walk or
> run there for real, and your avatar walks the route with you, earning coins
> and XP, completing quests, and capturing territory.

## 1. Pillars

| Pillar | Meaning in practice |
|---|---|
| **Every step counts** | Pedometer + GPS feed coins (1 per 100 steps), XP (10 per 100 m), quests and streaks. Nothing is wasted. |
| **The world is the board** | Real destinations, real routes, real 3D buildings and terrain (Mapbox Standard). Story landmarks spawn *near you*. |
| **Instant clarity** | Before you leave: time, steps, calories and climb for walking *and* running. While moving: one glance shows % done and what's left. |
| **Celebrate generously** | Animated reveals, voice cues, confetti, count-ups and level-ups at every milestone. |
| **Fair & private** | Server-side sanity checks; privacy zones trim route ends; history saving can be turned off. |

**Audience:** casual walkers (10k-steps crowd), commuters, beginner runners, Pokémon GO-style explorers. 13+.

## 2. Core loop

```
 ┌──────────── choose ────────────┐
 │  search / tap map / story quest │
 └──────────────┬─────────────────┘
                ▼
     route preview (walk vs run stats, fly-over)
                ▼
      START QUEST ── GPS + pedometer ──► avatar moves on 3D route
                ▼                               │ voice cues, banners
         arrive / finish ◄──────────────────────┘
                ▼
   rewards: coins · XP · quests · achievements · territory
                ▼
   spend: skins · trails · power-ups  ──► next quest
```

**Session length:** 10–60 min. **Meta loop:** daily quests (3/day, reset at midnight), weekly leaderboard (resets Monday), 7-day streaks, 4-chapter story campaign, territory collection.

## 3. Systems

### 3.1 Route & stats

| | Walking | Running |
|---|---|---|
| Default speed | 5 km/h | 10 km/h |
| Default stride | 0.7 m | 1.0 m |
| MET (ACSM, flat) | ≈ 3.4 | ≈ 10.5 |

- **Time** = distance ÷ speed · **Steps** = meters ÷ stride · **Calories** = MET × kg × hours.
- MET is computed from the configured speed with the ACSM walking/running equations, plus a grade term from the route's elevation gain, so custom speeds stay consistent.
- Mapbox Directions has no running profile, so both modes use the `walking` geometry. Only speed, stride and MET differ.
- Elevation profile: 24 Tilequery samples along the route (`mapbox-terrain-v2` contours).

Example (1.17 km): **🕒 14 min walking / 7 min running · 👣 ~1,700 steps · 🔥 ~55 kcal**.

### 3.2 Live tracking

- GPS: best-for-navigation accuracy, 3 m distance filter, background enabled (Android foreground service / iOS location background mode).
- Filters: drop fixes with accuracy > 35 m; ignore jitter smaller than max(3 m, accuracy/2); ignore implausible jumps > 30 km/h (flag "vehicle").
- Route snapping: projection onto the polyline with a forward-only window, so the avatar can't jump back on out-and-back routes. Off-route when > 45 m away. Arrival within 25 m of the destination.
- Steps: hardware pedometer (session deltas, pause-aware, reboot-safe). Falls back to distance ÷ stride when no sensor is available.
- Voice cues: every 500 steps ("You have walked 500 steps. 1.0 kilometers to go!"), every km, halfway, off-route, arrival, territory captured.

### 3.3 Economy

| Source | Coins | XP |
|---|---|---|
| Steps | 1 / 100 steps (×2 with Double Coins) | — |
| Distance | — | 10 / 100 m |
| Speed bonus | — | +10% brisk (≥ 5.5 km/h), +25% run (≥ 8 km/h) |
| Destination reached | — | +50 |
| Quest complete | 10–350 | 20–700 |
| Achievement | 25–600 | — |

**Sinks:** skins 250–900, trails 120–500, power-ups 60–150 (Double Coins, XP Boost ×1.5, Quest Reroll).

**Levels:** XP to reach level L = 100·(L−1)^1.5 (L2 = 100, L5 = 800, L10 = 2,700, L20 = 8,282). Titles: Wanderer → Scout → Ranger → Pathfinder → Trailblazer → Legend of the Roads.

### 3.4 Quests

| Type | Example | Completion |
|---|---|---|
| Daily: walk distance | "Wanderlust: walk 2.5 km today" | cumulative distance |
| Daily: steps | "Step Hoard: 5,000 steps" | cumulative steps |
| Daily: run | "Swift Courier: run 1.5 km" | distance in Running mode |
| Daily: territory | "Border Patrol: capture 1 territory" | loop closed |
| Story (chained) | "Walk 2 km to capture the Dragon's Lair" | reach the spawned landmark |
| Journey | "Journey to Golden Gate Park" | reach the map-selected destination |

Story landmarks spawn at 0.75 × target straight-line distance in a random direction (street networks add about 30%). Chapters unlock in order: Dragon's Lair → Whispering Woods → Crystal Spire → Ember Keep.

### 3.5 Territory capture

Walk a closed loop: the newest point comes back within 25 m of an earlier point, the loop is at least 400 m long, and it encloses at least 2,000 m². The enclosed polygon becomes a named territory (Dragon's Lair, Moonwell Grove, …), rendered as a glowing 3D extrusion on the map. Free Roam mode (flag button on the map) is built for this.

### 3.6 Achievements

First Steps, Questbound, 10K Day, 5K Runner, Unstoppable (7-day streak), Marathoner (42.2 km lifetime), Century Club (100 km), Landlord (first territory), Warlord (10 territories), Seasoned Ranger (level 10), Hundred Thousand (100k steps).

### 3.7 Social

- Friend codes (6 chars, no ambiguous characters), mutual friendship.
- Weekly step leaderboard among friends.
- Head-to-head challenges (10k / 25k / 50k steps this week).
- Guilds: members pool steps toward a weekly goal (credited by Cloud Function, reset Mondays).
- Share a route or session summary via the system share sheet.

## 4. 3D presentation

- **Style:** Mapbox Standard, which provides 3D buildings, extruded landmarks and lighting. `lightPreset` follows the app theme (day / night).
- **Terrain:** `mapbox-terrain-dem-v1`, exaggeration 1.4.
- **Route:** white blurred casing + 8 px line with a `line-progress` step gradient (gold = walked, trail color = remaining), `>` chevrons along the line, 1.5 s "draw-in" reveal via `line-trim-offset`.
- **Destination:** pulsing glow + a 45 m extruded hexagonal beacon.
- **Avatar:** glTF model via `ModelLayer`, rotated to the route bearing, with a halo circle underneath. The skin determines the model.
- **Camera:** Follow (pitch 65°, zoom 17.6, heading-up), Top-down (pitch 0°, north-up), Cinematic (orbiting, pitch 75°). The preview fly-over visits 8 waypoints along the route, then frames the whole route.

## 5. Wireframes

```
1. SPLASH / LOGIN              2. MAP (main)                   3. SEARCH & ROUTE PREVIEW
┌───────────────────────┐     ┌───────────────────────┐       ┌───────────────────────┐
│                       │     │ 🧭 [Lv3 ▓▓▓░░] 🪙 240 │       │ ← [ Golden Gate Pa… ] │
│          🗺️           │     │ 🔍 Where to, adventurer?│      │ 📍 Golden Gate Park  │
│     WalkQuest 3D      │     │                       │       │ 📍 Golden Gate Bridge │
│ Every step is an adv. │     │   ▟▙ 3D buildings ▟█▙ │       │ ───── tap result ──── │
│                       │     │      ▟█▙   ●you       │       │ ┌───────────────────┐ │
│ [🛡 Hero name       ] │     │  ▟▙        ▟█▙        │       │ │📍 Golden Gate Park ✕│ │
│ [✉ Email            ] │     │        ▟█▙       [◎]  │       │ │🕒 14 min walk / 7 run│ │
│ [🔒 Password        ] │     │                  [⚑]  │       │ │[🚶 14m] [🏃 7m]     │ │
│ (   Sign in   )       │     │ ┌───────────────────┐ │       │ │📏1.2km 👣~1.7k 🔥~55│ │
│ (  Play as Guest  )   │     │ │👆 Tap the map …   │ │       │ │⛰ ▁▂▄▆▅▃ elevation  │ │
│                       │     │ └───────────────────┘ │       │ │[✈Fly-over][▶START] │ │
└───────────────────────┘     │ Map Quests Stats Soc Me│      │ └───────────────────┘ │
                              └───────────────────────┘       └───────────────────────┘

4. ACTIVE QUEST                5. QUEST BOARD                  6. STATS & HISTORY
┌───────────────────────┐     ┌───────────────────────┐       ┌───────────────────────┐
│🐉 Dragon's Lair  [DEMO]│    │ Quest Board           │       │ 👣12k 📏9km 🔥640 ⚡3d │
│▓▓▓▓▓▓▓▓░░░░░ 62%      │     │ [Daily][Story][Journ.]│       │ 18,204 steps [Wk][Mo] │
│ ╭ Halfway there! ╮ [➤]│     │ (◔🥾) Wanderlust      │       │ ▁▃█▅▂▇▄  - - 10k - -  │
│      ▟█▙  ═══>═══ [▦]│     │   2.5 km · 🪙75 ✨150  │       │ Records: 🛣5.2km 👣7k │
│   ═══🧍══>═══▟▙   [🎥]│     │ (◑👣) Step Hoard      │       │ History               │
│ ┌───────────────────┐ │     │ (🔒) Crystal Spire    │       │ [map] Park · 2.1km +21│
│ │(1,240)  12:31     │ │     │ (◔🐉) Dragon's [Start]│       │ [map] Free roam  +8  │
│ │ steps  🚶 5.1km/h │ │     └───────────────────────┘       └───────────────────────┘
│ │📏450m 🕒5m 👣640 🔥│ │
│ │ [⏸ Pause][🏁Finish]│ │     7. SOCIAL                       8. PROFILE & AVATAR
│ └───────────────────┘ │     ┌───────────────────────┐       ┌───────────────────────┐
└───────────────────────┘     │ [Leaderbd][Friends][G]│       │ (🦊) Mia ✎   Lv 7    │
                              │ 🥇 🐺 Kai   61,204 👣 │       │ Fox Ranger·Dragonfire │
9. SETTINGS                   │ 🥈 🧭 You   48,330 👣 │       │ ▓▓▓▓▓▓░░ 1,840/2,180  │
┌───────────────────────┐     │ 🥉 🦄 Ava   40,112 👣 │       │ 📜12 🏰3 🏅5/11 🔥4   │
│ Use miles        [ ]  │     │ 4  🐼 Mio   22,870 👣 │       │[Achv][Skins][Trails][PU]│
│ Weight  ──●── 70 kg   │     │ Friend code: K7QX2M ⧉ │       │ 🦊 Equipped  🦆 🪙250 │
│ Stride  ─●─── 70 cm   │     │ Guild 🐉 ▓▓▓░ 120k/250k│      │ 🤖 🪙900    🧭 Owned  │
│ Theme   [☀][A][☾]     │     └───────────────────────┘       └───────────────────────┘
│ Voice cues       [✓]  │
│ AR mode          [ ]  │
│ Hide route ends  [✓]  │
│ Demo mode        [ ]  │
└───────────────────────┘
```

## 6. User stories

**Onboarding**
- As a new player, I can start as a guest in one tap, so I can try the game without an account.
- As a guest, I can later create an email account, and my progress carries over (anonymous account linking).

**Map & routing**
- As a player, I see my live location on a 3D map with buildings and terrain.
- As a player, I can search for a place or tap anywhere to set a destination.
- As a player, I see time, steps, calories and climb for both walking and running before I commit.
- As a player, I can watch a cinematic fly-over of the route to preview it.

**Tracking**
- As a player, when I start a quest my avatar moves along the route as I walk, and the walked part turns gold.
- As a player, I see % complete, remaining distance, time and steps, plus calories and coins earned so far.
- As a player, I hear voice cues at step and distance milestones, and when I go off route.
- As a player, tracking keeps working with the screen off.
- As a player, I can pause, resume, switch camera modes, or finish early and still get credit.
- As a developer or tester, I can enable Demo mode to simulate a walk without moving.

**Gamification**
- As a player, I get coins per 100 steps and XP for distance and speed, and I level up.
- As a player, I get three new daily quests every day, and story chapters unlock in order.
- As a player, I capture territory by walking a loop around an area and see it glow on the map.
- As a player, I unlock achievements (10k day, 5K run, 7-day streak, …) with coin rewards.
- As a player, I spend coins on skins (3D avatar models), trail colors and power-ups.

**Stats**
- As a player, I can browse every walk with a route thumbnail and detailed stats.
- As a player, I can see weekly or monthly step charts against the 10k line, and my personal records.

**Social**
- As a player, I add friends by code and compete on a weekly leaderboard.
- As a player, I challenge a friend to a step race and share my routes.
- As a player, I found or join a guild and contribute to its weekly goal.

**Settings & privacy**
- As a player, I can set units, weight, stride and speeds, and estimates update immediately.
- As a player, I can hide the start and end of my routes, or not store routes at all.
- As a player, I can sync with Apple Health or Health Connect.

## 7. Anti-cheat

Client: GPS accuracy and speed filters. Server (`onSessionCreated`): rejects sessions with average speed > 25 km/h, or a steps-to-distance ratio outside 0.4–2.2 steps/m. Rewards for a flagged session are clawed back and the session is marked `flagged`. Firestore rules keep coins and XP non-negative, and guild progress can only be written by Functions.

## 8. Roadmap

1. **AR Trail View** — ARCore/ARKit camera overlay of the route arrow and landmark (`ar_flutter_plugin` or a Unity ARFoundation module via `flutter_unity_widget`). The toggle and entry point already exist.
2. Live friend positions (opt-in) using the existing privacy setting.
3. Territory contests: other players' territories rendered and re-capturable.
4. FCM push for challenges and guild goals.
5. Offline map packs for planned routes (`OfflineManager`).
