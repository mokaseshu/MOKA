import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted panel that floats over the map.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF16152A) : Colors.white).withValues(alpha: dark ? 0.78 : 0.86),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Emoji + value + label, e.g. "👣 1,600 steps".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.emoji, required this.value, required this.label, this.color});

  final String emoji;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: t.labelSmall?.copyWith(color: t.labelSmall?.color?.withValues(alpha: 0.65)),
        ),
      ],
    );
  }
}

/// A row of [StatTile]s sharing the width equally, so long values shrink
/// instead of overflowing on narrow phones.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final c in children)
        Expanded(
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c),
        ),
    ],
  );
}

/// Coin counter pill.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD45A), Color(0xFFFF9F2E)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: coins, end: coins),
            duration: const Duration(milliseconds: 600),
            builder: (_, v, _) => Text(
              '$v',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4A2A00)),
            ),
          ),
        ],
      ),
    );
  }
}
