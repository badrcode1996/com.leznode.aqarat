import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ڕەنگە سەرەکییەکان بۆ یەکپارچەیی دیزاینەکە
const Color modernRed = Color(0xFFEF4444);

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
    this.secondValue,
    this.highlight = false,
    this.sparkline,
    this.width = 168,
    this.onTap,
  });

  final String title;
  final String value;

  /// Optional second line under [value] — e.g. a second currency total.
  final String? secondValue;
  final IconData icon;
  final Color accent;

  /// Optional tap handler (e.g. open the overdue-tenants list).
  final VoidCallback? onTap;

  /// Highlights the card (e.g. overdue payments in red).
  final bool highlight;

  /// Optional mini line-chart data drawn faintly in the background.
  final List<double>? sparkline;
  final double width;

  @override
  Widget build(BuildContext context) {
    // ڕێکخستنی ڕەنگەکان بۆ دۆخی ئاسایی و دۆخی ئاگادارکردنەوە
    final Color bgColor = highlight ? modernRed.withValues(alpha: 0.06) : Colors.white;
    final Color valueColor = highlight ? modernRed : accent;
    final Color borderColor = highlight ? modernRed.withValues(alpha: 0.3) : Colors.grey.shade200;

    final card = Container(
      width: width,
      margin: const EdgeInsetsDirectional.only(end: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // هێڵکاری پشتەوە (ئەگەر داتاکە بوونی هەبێت)
          if (sparkline != null)
            Positioned.fill(
              top: 36,
              child: _Sparkline(data: sparkline!, color: valueColor),
            ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ئایکۆنی سەرەوە
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: valueColor),
              ),

              const SizedBox(height: 12),

              // ژمارە یان بڕەکە
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: secondValue == null ? 22 : 19,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // دراوی دووەم (ئەگەر هەبێت)
              if (secondValue != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    secondValue!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: valueColor.withValues(alpha: 0.75),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              const SizedBox(height: 4),

              // ناونیشانی کارتەکە
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: highlight ? modernRed.withValues(alpha: 0.9) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
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
              color: color.withValues(alpha: 0.3), // ڕەنگی هێڵەکە کەمێک کاڵتر کراوە
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.08), // سێبەری ژێر هێڵەکە
              ),
            ),
          ],
        ),
      ),
    );
  }
}