import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class RoomEnergyVisualizer extends StatelessWidget {
  final String vibe; // calm, chaotic, emotional, romantic, funny, intense

  const RoomEnergyVisualizer({super.key, required this.vibe});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        gradient: _getVibeGradient(),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: _buildVibeOverlay(),
        ),
      ),
    );
  }

  LinearGradient _getVibeGradient() {
    switch (vibe) {
      case "chaotic":
        return const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case "emotional":
        return const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case "romantic":
        return const LinearGradient(colors: [Color(0xFFE94057), Color(0xFFF27121)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case "funny":
        return const LinearGradient(colors: [Color(0xFFFDC830), Color(0xFFF37335)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case "intense":
        return const LinearGradient(colors: [Color(0xFF000000), Color(0xFF434343)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default: // calm
        return const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  Widget _buildVibeOverlay() {
    return Center(
      child: Opacity(
        opacity: 0.05,
        child: Text(
          vibe.toUpperCase(),
          style: GoogleFonts.orbitron(fontSize: 120, color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class EnergyBadge extends StatelessWidget {
  final String vibe;
  final double intensity;

  const EnergyBadge({super.key, required this.vibe, required this.intensity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getVibeIcon(),
          const SizedBox(width: 8),
          Text(
            "${vibe.toUpperCase()} VIBE",
            style: GoogleFonts.orbitron(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(width: 10),
          _buildIntensityMeter(),
        ],
      ),
    );
  }

  Widget _getVibeIcon() {
    IconData icon = Icons.waves_rounded;
    Color color = Colors.cyanAccent;
    if (vibe == "chaotic") { icon = Icons.bolt_rounded; color = Colors.orangeAccent; }
    if (vibe == "emotional") { icon = Icons.favorite_rounded; color = Colors.pinkAccent; }
    return Icon(icon, size: 14, color: color);
  }

  Widget _buildIntensityMeter() {
    return Row(
      children: List.generate(5, (index) {
        final active = index < (intensity * 5).toInt();
        return Container(
          width: 3, height: 10,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6C63FF) : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
