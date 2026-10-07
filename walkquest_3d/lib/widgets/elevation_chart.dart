import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Small filled elevation profile for the route preview.
class ElevationChart extends StatelessWidget {
  const ElevationChart({super.key, required this.profile, this.height = 64});

  final List<double> profile;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (profile.length < 2) return SizedBox(height: height);
    final minE = profile.reduce((a, b) => a < b ? a : b);
    final maxE = profile.reduce((a, b) => a > b ? a : b);
    final pad = ((maxE - minE) * 0.2).clamp(5, 50).toDouble();
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minE - pad,
          maxY: maxE + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < profile.length; i++) FlSpot(i.toDouble(), profile[i])],
              isCurved: true,
              barWidth: 2.5,
              color: AppColors.teal,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppColors.teal.withValues(alpha: 0.45), AppColors.teal.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
