import 'package:flutter/material.dart';

class StoryRing extends StatelessWidget {
  final Widget child;
  final bool hasUnseen;
  final bool isCloseFriends;
  final double radius;
  final double strokeWidth;

  const StoryRing({
    super.key,
    required this.child,
    required this.hasUnseen,
    required this.isCloseFriends,
    this.radius = 28,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasUnseen) {
      return Container(
        padding: EdgeInsets.all(strokeWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: strokeWidth),
        ),
        child: child,
      );
    }

    return Container(
      padding: EdgeInsets.all(strokeWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCloseFriends
            ? const LinearGradient(
                colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: child,
    );
  }
}
