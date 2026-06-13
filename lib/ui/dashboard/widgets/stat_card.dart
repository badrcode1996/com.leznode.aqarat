import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A compact statistic card for the dashboard stats row.
///
/// Modern, clean styling: rounded corners, subtle shadow, white (or tinted)
/// background, an accent icon chip, and an optional faint sparkline drawn
/// behind the content.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.highlight = false,
    this.sparkline,
    this.width = 168,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  /// Highlights the card (e.g. overdue payments in red).
  final bool highlight;

  /// Optional mini line-chart data drawn faintly in the background.
  final List<double>? sparkline;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? const Color(0xFFFFEBEE) : Colors.white;
    final valueColor = highlight ? const Color(0xFFC62828) : accent;

    return Container(
      width: width,
      margin: const EdgeInsetsDirectional.only(end: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (sparkline != null)
            Positioned.fill(
              top: 36,
              child: _Sparkline(data: sparkline!, color: accent),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (highlight ? valueColor : accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20, color: highlight ? valueColor : accent),
              ),
              const SizedBox(height: 14),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];
    return IgnorePointer(
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color.withValues(alpha: 0.5),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
