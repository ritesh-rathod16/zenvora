import 'package:flutter/material.dart';

class StoryGradientBackgrounds {
  static const List<List<Color>> palettes = [
    [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)], // Instagram classic
    [Color(0xFF6C63FF), Color(0xFF00D2FF)], // Zenvora Cyan
    [Color(0xFFFF416C), Color(0xFFFF4B2B)], // Sunset Fire
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Emerald Lush
    [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)], // Nightfall
  ];
}

class StoryLayoutWidget extends StatelessWidget {
  final List<String?> panelImagePaths;
  final Function(int index)? onPanelTap;

  const StoryLayoutWidget({
    super.key,
    required this.panelImagePaths,
    this.onPanelTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final path = index < panelImagePaths.length ? panelImagePaths[index] : null;

        return GestureDetector(
          onTap: () {
            if (onPanelTap != null) onPanelTap!(index);
          },
          child: Container(
            color: const Color(0xFF1A1A2E),
            child: path != null
                ? Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.photo, color: Colors.white24))
                : const Center(child: Icon(Icons.add_a_photo_rounded, color: Colors.white38)),
          ),
        );
      },
    );
  }
}
