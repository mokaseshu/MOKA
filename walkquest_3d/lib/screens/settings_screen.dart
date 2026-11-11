import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../services/location_service.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import 'splash_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SettingsController>();
    final s = ctrl.value;
    Future<void> set(AppSettings Function(AppSettings) f) => ctrl.update(f);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Units & body'),
          SwitchListTile(
            title: const Text('Use miles'),
            subtitle: Text(s.useMiles ? 'mi / ft' : 'km / m'),
            value: s.useMiles,
            onChanged: (v) => set((x) => x.copyWith(useMiles: v)),
          ),
          _SliderTile(
            label: 'Weight',
            value: s.weightKg,
            min: 30,
            max: 180,
            divisions: 150,
            display: s.useMiles ? '${(s.weightKg * 2.20462).round()} lb' : '${s.weightKg.round()} kg',
            onChanged: (v) => set((x) => x.copyWith(weightKg: v)),
          ),
          _SliderTile(
            label: 'Walking stride',
            value: s.walkingStrideM,
            min: 0.4,
            max: 1.0,
            divisions: 60,
            display: '${(s.walkingStrideM * 100).round()} cm',
            onChanged: (v) => set((x) => x.copyWith(walkingStrideM: v)),
          ),
          _SliderTile(
            label: 'Running stride',
            value: s.runningStrideM,
            min: 0.6,
            max: 1.8,
            divisions: 120,
            display: '${(s.runningStrideM * 100).round()} cm',
            onChanged: (v) => set((x) => x.copyWith(runningStrideM: v)),
          ),
          _SliderTile(
            label: 'Walking speed',
            value: s.walkingSpeedKmh,
            min: 3,
            max: 7,
            divisions: 40,
            display: '${s.walkingSpeedKmh.toStringAsFixed(1)} km/h',
            onChanged: (v) => set((x) => x.copyWith(walkingSpeedKmh: v)),
          ),
          _SliderTile(
            label: 'Running speed',
            value: s.runningSpeedKmh,
            min: 6,
            max: 18,
            divisions: 120,
            display: '${s.runningSpeedKmh.toStringAsFixed(1)} km/h',
            onChanged: (v) => set((x) => x.copyWith(runningSpeedKmh: v)),
          ),
          const _Header('Experience'),
          ListTile(
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => set((x) => x.copyWith(themeMode: v.first)),
            ),
          ),
          SwitchListTile(
            title: const Text('Voice cues'),
            subtitle: const Text('"You have walked 500 steps. 1 km to go!"'),
            value: s.voiceCues,
            onChanged: (v) => set((x) => x.copyWith(voiceCues: v)),
          ),
          SwitchListTile(
            title: const Text('3D terrain'),
            subtitle: const Text('Exaggerated elevation on the map'),
            value: s.terrain3d,
            onChanged: (v) => set((x) => x.copyWith(terrain3d: v)),
          ),
          SwitchListTile(
            title: const Text('AR mode'),
            subtitle: const Text('Show the AR trail view button during quests (preview)'),
            value: s.arMode,
            onChanged: (v) => set((x) => x.copyWith(arMode: v)),
          ),
          SwitchListTile(
            title: const Text('Sync with Apple Health / Health Connect'),
            subtitle: const Text('Import daily steps, export finished quests as workouts'),
            value: s.healthSync,
            onChanged: (v) async {
              await set((x) => x.copyWith(healthSync: v));
              if (v && context.mounted) await context.read<GameController>().syncHealthSteps();
            },
          ),
          const _Header('Privacy'),
          SwitchListTile(
            title: const Text('Share live location with friends'),
            value: s.shareLocationWithFriends,
            onChanged: (v) => set((x) => x.copyWith(shareLocationWithFriends: v)),
          ),
          SwitchListTile(
            title: const Text('Hide route start & end'),
            subtitle: const Text('Trims 100 m from both ends of saved routes'),
            value: s.hideRouteEndpoints,
            onChanged: (v) => set((x) => x.copyWith(hideRouteEndpoints: v)),
          ),
          SwitchListTile(
            title: const Text('Save route history'),
            subtitle: const Text('Off = keep stats only, no GPS track'),
            value: s.saveRouteHistory,
            onChanged: (v) => set((x) => x.copyWith(saveRouteHistory: v)),
          ),
          ListTile(
            title: const Text('Location permission'),
            subtitle: const Text('Open system settings'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => LocationService().openSettings(),
          ),
          const _Header('Developer'),
          SwitchListTile(
            title: const Text('Demo mode'),
            subtitle: const Text('Simulate walking along the route at 4× speed (no GPS needed)'),
            value: s.demoMode,
            onChanged: (v) => set((x) => x.copyWith(demoMode: v)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: () async {
              await context.read<GameController>().signOut();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SplashLoginScreen()), (_) => false);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800),
    ),
  );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value, min, max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
        SizedBox(width: 72, child: Text(display, textAlign: TextAlign.end)),
      ],
    ),
  );
}
