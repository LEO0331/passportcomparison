import 'package:flutter/material.dart';

class OpennessIndicator extends StatelessWidget {
  final double score;
  final double height;

  const OpennessIndicator({super.key, required this.score, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color = Colors.red;
    if (score > 70) {
      color = Colors.green;
    } else if (score > 30) {
      color = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Openness",
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 0.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            Text(
              score.toStringAsFixed(1),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}
