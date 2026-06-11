import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonAvatar extends StatelessWidget {
  final double radius;
  final double? width;
  final double? height;

  const SkeletonAvatar({
    super.key,
    this.radius = 30,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? radius * 2;
    final effectiveHeight = height ?? radius * 2;

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade800,
      child: Container(
        width: effectiveWidth,
        height: effectiveHeight,
        decoration: BoxDecoration(
          shape: radius > 0 ? BoxShape.circle : BoxShape.rectangle,
          color: Colors.black,
        ),
      ),
    );
  }
}
