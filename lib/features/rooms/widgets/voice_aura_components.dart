import 'dart:math' as math;
import 'package:flutter/material.dart';

class VoiceAuraPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;
  final int particlesCount;

  VoiceAuraPainter({
    required this.animationValue,
    required this.baseColor,
    this.particlesCount = 15,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = baseColor.withOpacity(0.3 * (1 - animationValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw expanding rings
    for (int i = 0; i < 3; i++) {
      final ringValue = (animationValue + i / 3.0) % 1.0;
      canvas.drawCircle(center, radius * (1 + ringValue * 0.5), paint);
    }

    // Draw particles
    final random = math.Random(42);
    for (int i = 0; i < particlesCount; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = radius * (1 + animationValue * (0.5 + random.nextDouble()));
      final particleX = center.dx + distance * math.cos(angle);
      final particleY = center.dy + distance * math.sin(angle);
      
      final particlePaint = Paint()
        ..color = baseColor.withOpacity(0.5 * (1 - animationValue))
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(particleX, particleY), 2.0 * (1 - animationValue), particlePaint);
    }
  }

  @override
  bool shouldRepaint(VoiceAuraPainter oldDelegate) => true;
}

class EmotionalAuraWidget extends StatefulWidget {
  final Widget child;
  final bool isSpeaking;
  final String auraTheme;

  const EmotionalAuraWidget({
    super.key,
    required this.child,
    this.isSpeaking = false,
    this.auraTheme = "Cyber Purple",
  });

  @override
  State<EmotionalAuraWidget> createState() => _EmotionalAuraWidgetState();
}

class _EmotionalAuraWidgetState extends State<EmotionalAuraWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Color get _themeColor {
    switch (widget.auraTheme) {
      case "Ghost Blue": return const Color(0xFF00F2FE);
      case "Neon Pink": return const Color(0xFFFF00E0);
      case "Void Black": return Colors.white24;
      case "Dreamcore": return Colors.tealAccent;
      default: return const Color(0xFF6C63FF);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.isSpeaking) _controller.repeat();
  }

  @override
  void didUpdateWidget(EmotionalAuraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpeaking && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: widget.isSpeaking 
            ? VoiceAuraPainter(animationValue: _controller.value, baseColor: _themeColor)
            : null,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
