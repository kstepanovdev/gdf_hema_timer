import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ActiveTimerBoard extends StatelessWidget {
  final int leftScore;
  final int rightScore;

  const ActiveTimerBoard({
    super.key,
    required this.leftScore,
    required this.rightScore,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Roboto',
      fontWeight: FontWeight.bold,
      fontSize: 90,
      height: 0.8,
      letterSpacing: 2,
      color: AppColors.onStage,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final text in ['$leftScore', ':', '$rightScore'])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(text, style: style),
          ),
      ],
    );
  }
}
