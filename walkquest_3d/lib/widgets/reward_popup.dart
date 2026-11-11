import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gamification_service.dart';
import '../utils/app_theme.dart';
import 'game_button.dart';

/// Celebratory pop-up after a quest: coins count up, confetti, level-up and
/// unlocked achievements.
Future<void> showRewardPopup(BuildContext context, RewardSummary r, {String? title}) {
  HapticFeedback.heavyImpact();
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => _RewardDialog(r, title ?? 'Quest Complete!'),
    transitionBuilder: (_, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _RewardDialog extends StatefulWidget {
  const _RewardDialog(this.r, this.title);
  final RewardSummary r;
  final String title;

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..forward();
  final _pieces = List.generate(70, (i) => _Confetti(math.Random(i)));

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final t = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _confetti.value)),
            ),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 330,
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 56)),
                  Text(widget.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CountUp(emoji: '🪙', value: r.totalCoins, label: 'coins', color: AppColors.gold),
                      _CountUp(emoji: '✨', value: r.xp, label: 'XP', color: AppColors.xp),
                    ],
                  ),
                  if (r.doubleCoinsUsed) ...[
                    const SizedBox(height: 6),
                    Text('Double Coins applied!', style: t.labelMedium?.copyWith(color: AppColors.gold)),
                  ],
                  if (r.leveledUp) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '⬆️  LEVEL UP!  ${r.levelBefore} → ${r.levelAfter}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                  if (r.territoriesCaptured > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '🏰 ${r.territoriesCaptured} territor${r.territoriesCaptured == 1 ? 'y' : 'ies'} captured',
                      style: t.titleSmall,
                    ),
                  ],
                  for (final q in r.completedQuests) _Line('${q.emoji}  ${q.title}', '+${q.rewardCoins} 🪙'),
                  for (final a in r.newAchievements) _Line('${a.emoji}  ${a.title} unlocked', '+${a.rewardCoins} 🪙'),
                  const SizedBox(height: 22),
                  GameButton(
                    label: 'Collect',
                    icon: Icons.check_rounded,
                    gradient: AppColors.gradientReward,
                    onPressed: () => Navigator.of(context).pop(),
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

class _Line extends StatelessWidget {
  const _Line(this.left, this.right);
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(left, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Text(
          right,
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
        ),
      ],
    ),
  );
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.emoji, required this.value, required this.label, required this.color});
  final String emoji;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
    tween: IntTween(begin: 0, end: value),
    duration: const Duration(milliseconds: 1400),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 30)),
        Text(
          '+$v',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color),
        ),
        Text(label),
      ],
    ),
  );
}

class _Confetti {
  _Confetti(math.Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.3,
      speed = 0.6 + r.nextDouble() * 0.8,
      drift = (r.nextDouble() - 0.5) * 0.3,
      spin = r.nextDouble() * 10,
      color = [AppColors.gold, AppColors.teal, AppColors.pink, AppColors.violet, AppColors.sunset][r.nextInt(5)];

  final double x, delay, speed, drift, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Confetti> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * size.height * 1.1;
      final x = (p.x + p.drift * local) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      canvas.drawRect(const Rect.fromLTWH(-4, -7, 8, 14), Paint()..color = p.color.withValues(alpha: 1 - local * 0.6));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
