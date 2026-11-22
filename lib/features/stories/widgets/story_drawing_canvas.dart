import 'package:flutter/material.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class StoryDrawingCanvas extends StatefulWidget {
  final Color selectedColor;
  final double strokeWidth;

  const StoryDrawingCanvas({
    super.key,
    required this.selectedColor,
    required this.strokeWidth,
  });

  @override
  State<StoryDrawingCanvas> createState() => StoryDrawingCanvasState();
}

class StoryDrawingCanvasState extends State<StoryDrawingCanvas> {
  final List<DrawingPoint?> _points = [];

  void clear() {
    setState(() => _points.clear());
  }

  void undo() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _points.add(DrawingPoint(
            offset: details.localPosition,
            paint: Paint()
              ..color = widget.selectedColor
              ..isAntiAlias = true
              ..strokeWidth = widget.strokeWidth
              ..strokeCap = StrokeCap.round,
          ));
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _points.add(DrawingPoint(
            offset: details.localPosition,
            paint: Paint()
              ..color = widget.selectedColor
              ..isAntiAlias = true
              ..strokeWidth = widget.strokeWidth
              ..strokeCap = StrokeCap.round,
          ));
        });
      },
      onPanEnd: (_) {
        setState(() => _points.add(null));
      },
      child: CustomPaint(
        painter: _StoryPainter(points: _points),
        size: Size.infinite,
      ),
    );
  }
}

class _StoryPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  _StoryPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StoryPainter oldDelegate) => true;
}
