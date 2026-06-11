import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../profile/widgets/premium_profile_widgets.dart';

class GhostStoriesSection extends StatelessWidget {
  const GhostStoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "GHOST STORIES",
                style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const Icon(Icons.auto_fix_high_rounded, color: Colors.white24, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: 8,
            itemBuilder: (context, index) {
              if (index == 0) return _buildAddStory();
              return _buildStoryCircle(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddStory() {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          Container(
            width: 65, height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 1.5),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white24, size: 28),
          ),
          const SizedBox(height: 8),
          Text("You", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStoryCircle(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00F2FE)]),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1A1A2E),
              child: ClipOval(
                child: Image.network(
                  "https://picsum.photos/200/300?random=$index",
                  fit: BoxFit.cover,
                  width: 60, height: 60,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text("Anon_$index", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
