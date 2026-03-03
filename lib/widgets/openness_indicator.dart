import 'package:flutter/material.dart';

class OpennessIndicator extends StatelessWidget {
  final double score;
  final double height;

  const OpennessIndicator({super.key, required this.score, this.height = 8});

  @override
  Widget build(BuildContext context) {
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
            const Text(
              "Openness",
              style: TextStyle(
                fontSize: 10,
                color: Color.fromARGB(255, 47, 45, 45),
              ),
            ),
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: color.withValues(),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: height,
          ),
        ),
      ],
    );
  }
}
