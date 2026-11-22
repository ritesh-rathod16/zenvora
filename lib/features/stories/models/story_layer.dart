import 'package:flutter/material.dart';

enum LayerType { text, gif, sticker, drawing }

class StoryLayer {
  final String id;
  final LayerType type;
  final String content; // text content or GIF/sticker URL
  Offset position;
  double scale;
  double rotation;
  Color? color;

  StoryLayer({
    required this.id,
    required this.type,
    required this.content,
    this.position = const Offset(150, 300),
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'content': content,
      'x': position.dx,
      'y': position.dy,
      'scale': scale,
      'rotation': rotation,
    };
  }
}
