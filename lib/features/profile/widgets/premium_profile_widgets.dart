import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class PremiumAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final bool isOnline;
  final bool isSpeaking;
  final VoidCallback? onTap;

  const PremiumAvatar({
    super.key,
    this.imageUrl,
    this.radius = 50,
    this.isOnline = false,
    this.isSpeaking = false,
    this.onTap,
  });

  String get _safeImageUrl => (imageUrl == null || imageUrl!.isEmpty) 
      ? "https://api.dicebear.com/7.x/avataaars/png?seed=ghost" 
      : imageUrl!;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isSpeaking)
            _buildSpeakingRing(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF),
                  const Color(0xFF00F2FE),
                  Colors.purpleAccent.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFF1A1A2E),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: _safeImageUrl,
                  fit: BoxFit.cover,
                  width: radius * 2,
                  height: radius * 2,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.white10,
                    highlightColor: Colors.white24,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => CachedNetworkImage(
                    imageUrl: "https://api.dicebear.com/7.x/avataaars/png?seed=error",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: radius * 0.1,
              right: radius * 0.1,
              child: Container(
                width: radius * 0.35,
                height: radius * 0.35,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF94),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0F0F1A), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF94).withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeakingRing() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: (radius + 8) * 2 * (1 + value * 0.15),
          height: (radius + 8) * 2 * (1 + value * 0.15),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(1 - value),
              width: 2.5,
            ),
          ),
        );
      },
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF252545),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 60),
            const CircleAvatar(radius: 60, backgroundColor: Colors.white),
            const SizedBox(height: 24),
            Container(height: 30, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 12),
            Container(height: 20, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => Container(height: 50, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))),
            ),
            const SizedBox(height: 32),
            Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          ],
        ),
      ),
    );
  }
}

class PremiumStatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const PremiumStatItem({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white38,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double? width;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isPrimary = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isPrimary
                  ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF3F37C9)],
                    )
                  : null,
              color: isPrimary ? null : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: isPrimary ? Colors.transparent : Colors.white.withOpacity(0.1),
              ),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoryCircle extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool hasUnseen;

  const StoryCircle({
    super.key,
    required this.title,
    this.imageUrl,
    this.onTap,
    this.hasUnseen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: hasUnseen
                    ? Border.all(color: const Color(0xFF6C63FF), width: 2.5)
                    : Border.all(color: Colors.white10, width: 1),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF1A1A2E),
                child: ClipOval(
                  child: imageUrl != null 
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.white10),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 20),
                      )
                    : const Icon(Icons.add, color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class CompatibilityMeter extends StatelessWidget {
  final double percentage;

  const CompatibilityMeter({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 65,
            width: 65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF00F2FE)),
                ),
                Text(
                  "${percentage.toInt()}%",
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF00F2FE),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI COMPATIBILITY",
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: Colors.white38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  percentage > 80 
                      ? "Incredible Vibe Match!" 
                      : percentage > 50 
                          ? "Great potential together." 
                          : "Explore common interests.",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 22),
        ],
      ),
    );
  }
}
