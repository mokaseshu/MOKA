import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/achievement.dart';
import '../models/shop_item.dart';
import '../services/catalog.dart';
import '../state/game_controller.dart';
import '../utils/app_theme.dart';
import '../widgets/progress_ring.dart';
import '../widgets/stat_tile.dart';
import '../widgets/xp_bar.dart';
import 'settings_screen.dart';

/// Avatar, level, achievements and the shop (skins, trails, power-ups).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final p = game.me;
    final t = Theme.of(context).textTheme;
    final skin = Catalog.skin(p.avatar.skinId);
    final trail = Catalog.trail(p.avatar.trailId);

    final ctx = AchievementContext(profile: p, history: game.sessions, territoriesCaptured: game.territories.length);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CoinPill(coins: p.coins),
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [Color(skin.color), Color(trail.color)]),
                                boxShadow: [
                                  BoxShadow(color: Color(trail.color).withValues(alpha: 0.5), blurRadius: 18),
                                ],
                              ),
                              child: Text(p.avatar.emoji, style: const TextStyle(fontSize: 46)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () => _rename(context, game),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.displayName,
                                            overflow: TextOverflow.ellipsis,
                                            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.edit_rounded, size: 16),
                                      ],
                                    ),
                                  ),
                                  Text('${skin.name} · ${trail.name} trail', style: t.bodySmall),
                                  const SizedBox(height: 10),
                                  XpBar(xp: p.xp),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        StatRow(
                          children: [
                            StatTile(emoji: '📜', value: '${p.questsCompleted}', label: 'quests'),
                            StatTile(emoji: '🏰', value: '${game.territories.length}', label: 'territories'),
                            StatTile(
                              emoji: '🏅',
                              value: '${Catalog.unlockedCount(p)}/${Catalog.achievements.length}',
                              label: 'badges',
                            ),
                            StatTile(emoji: '🔥', value: '${p.streakDays(DateTime.now())}', label: 'day streak'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Achievements'),
                  Tab(text: 'Skins'),
                  Tab(text: 'Trails'),
                  Tab(text: 'Power-ups'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.7,
                children: [
                  for (final a in Catalog.achievements)
                    _AchievementTile(
                      achievement: a,
                      unlocked: p.unlockedAchievements.contains(a.id),
                      progress: a.progress(ctx),
                    ),
                ],
              ),
              _ShopGrid(items: Catalog.skins, game: game),
              _ShopGrid(items: Catalog.trails, game: game),
              _ShopGrid(items: Catalog.powerUps, game: game),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, GameController game) async {
    final ctrl = TextEditingController(text: game.me.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hero name'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null) await game.rename(name);
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked, required this.progress});
  final Achievement achievement;
  final bool unlocked;
  final double progress;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: achievement.description,
    triggerMode: TooltipTriggerMode.tap,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(
              value: unlocked ? 1 : progress,
              size: 56,
              colors: unlocked ? const [AppColors.gold, AppColors.sunset] : const [AppColors.teal, AppColors.violet],
              child: Opacity(
                opacity: unlocked ? 1 : 0.35,
                child: Text(achievement.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(unlocked ? 'Unlocked' : '${(progress * 100).round()}%', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class _ShopGrid extends StatelessWidget {
  const _ShopGrid({required this.items, required this.game});
  final List<ShopItem> items;
  final GameController game;

  bool _equipped(ShopItem i) => i.id == game.me.avatar.skinId || i.id == game.me.avatar.trailId;

  Future<void> _onTap(BuildContext context, ShopItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    if (game.owns(item)) {
      await game.equip(item);
      messenger.showSnackBar(SnackBar(content: Text('${item.emoji} ${item.name} equipped')));
      return;
    }
    if (game.me.coins < item.price) {
      messenger.showSnackBar(SnackBar(content: Text('Need ${item.price - game.me.coins} more coins — go walk! 🚶')));
      return;
    }
    final ok = await game.buy(item);
    if (ok && item.type != ShopItemType.powerUp) await game.equip(item);
    messenger.showSnackBar(SnackBar(content: Text(ok ? '${item.emoji} ${item.name} acquired!' : 'Purchase failed')));
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.8,
      children: [
        for (final item in items)
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: _equipped(item) ? Color(item.color) : Colors.transparent, width: 3),
            ),
            child: InkWell(
              onTap: () => _onTap(context, item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(item.color).withValues(alpha: 0.2),
                      ),
                      child: Text(item.emoji, style: const TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      item.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _equipped(item)
                          ? 'Equipped'
                          : game.owns(item)
                          ? 'Tap to equip'
                          : item.type == ShopItemType.powerUp && game.powerUpCharges(item.id) > 0
                          ? '🪙 ${item.price} · owned ×${game.powerUpCharges(item.id)}'
                          : item.price == 0
                          ? 'Free'
                          : '🪙 ${item.price}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Color(item.color)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
