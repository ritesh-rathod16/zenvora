import 'package:flutter/material.dart';

class DefaultAvatar extends StatelessWidget {
  final double radius;
  const DefaultAvatar({super.key, this.radius = 30});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1A1A2E),
      child: Icon(Icons.person, color: Colors.white54, size: radius),
    );
  }
}
