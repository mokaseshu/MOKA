import 'package:flutter/material.dart';

import '../models/quest.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'quest_board_screen.dart';
import 'social_screen.dart';
import 'stats_history_screen.dart';

/// Bottom navigation: Map, Quests, Stats, Social, Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _mapKey = GlobalKey<MapScreenState>();

  void _startQuestOnMap(Quest quest) {
    setState(() => _index = 0);
    // Let the tab switch settle before the camera flies.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mapKey.currentState?.planStoryQuest(quest));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(key: _mapKey),
          QuestBoardScreen(onStartQuest: _startQuestOnMap),
          const StatsHistoryScreen(),
          const SocialScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Map'),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Quests',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
