import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/leveling.dart';

/// Level badge + animated XP bar.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.xp, this.compact = false});

  final int xp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final level = Leveling.levelForXp(xp);
    final next = Leveling.xpForLevel(level + 1);
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: compact ? 34 : 44,
          height: compact ? 34 : 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(gradient: AppColors.gradientPrimary, shape: BoxShape.circle),
          child: Text(
            '$level',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: compact ? 14 : 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) Text(Leveling.titleFor(level), style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: Leveling.levelProgress(xp)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: compact ? 6 : 10,
                    backgroundColor: AppColors.xp.withValues(alpha: 0.18),
                    color: AppColors.xp,
                  ),
                ),
              ),
              if (!compact) ...[const SizedBox(height: 2), Text('$xp / $next XP', style: t.labelSmall)],
            ],
          ),
        ),
      ],
    );
  }
}
