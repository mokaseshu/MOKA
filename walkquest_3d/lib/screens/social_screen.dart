import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/social.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

/// Leaderboard, friends & challenges, guilds.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social'),
          actions: [
            IconButton(
              tooltip: 'Add friend',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _addFriend(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Leaderboard'),
              Tab(text: 'Friends'),
              Tab(text: 'Guilds'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: game.refreshSocial,
          child: TabBarView(
            children: [
              _Leaderboard(rows: game.leaderboard),
              _Friends(game: game),
              _Guilds(game: game),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _addFriend(BuildContext context) async {
    final game = context.read<GameController>();
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your code: ${game.me.friendCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: "Friend's code"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final f = await game.addFriend(code);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(f == null ? 'No adventurer found with that code.' : '${f.displayName} joined your party! 🎉'),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.rows});
  final List<FriendEntry> rows;

  @override
  Widget build(BuildContext context) {
    const medals = ['🥇', '🥈', '🥉'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('This week · resets Monday', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: rows[i].isMe ? AppColors.gradientPrimary : null,
                color: rows[i].isMe ? null : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: SizedBox(
                  width: 64,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          i < 3 ? medals[i] : '${i + 1}',
                          style: TextStyle(
                            fontSize: i < 3 ? 22 : 16,
                            fontWeight: FontWeight.w800,
                            color: rows[i].isMe ? Colors.white : null,
                          ),
                        ),
                      ),
                      Text(rows[i].avatarEmoji, style: const TextStyle(fontSize: 26)),
                    ],
                  ),
                ),
                title: Text(
                  rows[i].isMe ? '${rows[i].displayName} (you)' : rows[i].displayName,
                  style: TextStyle(fontWeight: FontWeight.w800, color: rows[i].isMe ? Colors.white : null),
                ),
                subtitle: Text('Level ${rows[i].level}', style: TextStyle(color: rows[i].isMe ? Colors.white70 : null)),
                trailing: Text(
                  '${Fmt.count(rows[i].weeklySteps)} 👣',
                  style: TextStyle(fontWeight: FontWeight.w900, color: rows[i].isMe ? Colors.white : null),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Friends extends StatelessWidget {
  const _Friends({required this.game});
  final GameController game;

  Future<void> _challenge(BuildContext context, FriendEntry f) async {
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Challenge ${f.displayName}'),
        children: [
          for (final steps in [10000, 25000, 50000])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, steps),
              child: Text('First to ${Fmt.count(steps)} steps this week'),
            ),
        ],
      ),
    );
    if (target == null) return;
    await game.challenge(f, target);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Challenge sent to ${f.displayName} ⚔️')));
    }
  }

  void _shareRoute(BuildContext context) {
    final miles = context.read<SettingsController>().value.useMiles;
    final last = game.sessions.isEmpty ? null : game.sessions.first;
    final text = last == null
        ? 'Join me on WalkQuest 3D! My friend code: ${game.me.friendCode}'
        : 'Try my route${last.destinationName == null ? '' : ' to ${last.destinationName}'} on WalkQuest 3D: '
              '${Fmt.distance(last.distanceM, miles: miles)}, ${Fmt.count(last.steps)} steps. '
              'Add me with code ${game.me.friendCode}!';
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final friends = game.friends;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Text('🎟️', style: TextStyle(fontSize: 28)),
            title: Text('Friend code: ${game.me.friendCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Share it so friends can add you'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => Clipboard.setData(ClipboardData(text: game.me.friendCode)),
                ),
                IconButton(icon: const Icon(Icons.ios_share_rounded), onPressed: () => _shareRoute(context)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final f in friends)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Text(f.avatarEmoji, style: const TextStyle(fontSize: 30)),
                title: Text(f.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Lv ${f.level} · ${Fmt.count(f.weeklySteps)} steps this week'),
                trailing: IconButton(
                  tooltip: 'Challenge',
                  icon: const Text('⚔️', style: TextStyle(fontSize: 22)),
                  onPressed: () => _challenge(context, f),
                ),
              ),
            ),
          ),
        if (game.challenges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Challenges', style: Theme.of(context).textTheme.titleMedium),
          for (final c in game.challenges)
            ListTile(
              leading: const Text('⚔️', style: TextStyle(fontSize: 22)),
              title: Text(c.fromUid == game.me.uid ? 'You → ${c.toName}' : '${c.fromName} → you'),
              subtitle: Text(c.description),
              trailing: Text(c.status.name),
            ),
        ],
      ],
    );
  }
}

class _Guilds extends StatelessWidget {
  const _Guilds({required this.game});
  final GameController game;

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    var emoji = '🛡️';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Found a guild'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(hintText: 'Guild name'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in ['🛡️', '🐉', '🦅', '🌙', '🔥', '🌊'])
                    ChoiceChip(label: Text(e), selected: emoji == e, onSelected: (_) => set(() => emoji = e)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await game.createGuild(name.text.trim(), emoji, 250000);
    }
  }

  Future<void> _join(BuildContext context) async {
    final ctrl = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a guild'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Guild ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Join')),
        ],
      ),
    );
    if (id == null || id.trim().isEmpty) return;
    final ok = await game.joinGuild(id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? 'Welcome to the guild! 🛡️' : 'Guild not found (online mode only).')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _create(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create guild'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _join(context),
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('Join'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (game.guilds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Team up! Guild members pool their steps toward a weekly goal.', textAlign: TextAlign.center),
          ),
        for (final g in game.guilds)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(g.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          g.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text('${g.memberUids.length} 👥'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: g.fraction,
                      minHeight: 12,
                      color: AppColors.teal,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${Fmt.count(g.progressSteps)} / ${Fmt.count(g.goalSteps)} steps this week'),
                  SelectableText('ID: ${g.id}', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
