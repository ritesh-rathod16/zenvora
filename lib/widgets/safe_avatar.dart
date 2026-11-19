import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:shimmer/shimmer.dart';
import '../core/utils/image_helper.dart';

class SafeAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final String? blurhash;
  final double radius;
  final double? width;
  final double? height;

  const SafeAvatar({
    super.key,
    required this.avatarUrl,
    required this.username,
    this.blurhash,
    this.radius = 30,
    this.width,
    this.height,
  });

  static const List<List<Color>> _palettes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink to Rose
    [Color(0xFF14B8A6), Color(0xFF06B6D4)], // Teal to Cyan
    [Color(0xFFF97316), Color(0xFFFB923C)], // Orange
    [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple to Fuchsia
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Blue
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
  ];

  List<Color> _getGradient(String seed) {
    if (seed.isEmpty) return [const Color(0xFF374151), const Color(0xFF1F2937)];
    final hash = seed.codeUnits.fold(0, (prev, elem) => prev + elem);
    return _palettes[hash % _palettes.length];
  }

  String _optimizeUrl(String url, double width, double height) {
    final targetSize = (width * 2).clamp(100.0, 600.0).toInt();
    return ImageHelper.safeImage(
      url,
      width: targetSize,
      height: targetSize,
      quality: 85,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? radius * 2;
    final effectiveHeight = height ?? radius * 2;

    if (!ImageHelper.isValidUrl(avatarUrl)) {
      return _buildInitials(effectiveWidth, effectiveHeight);
    }

    final optimizedUrl = _optimizeUrl(avatarUrl!, effectiveWidth, effectiveHeight);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: optimizedUrl,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          if (blurhash != null && blurhash!.isNotEmpty) {
            return BlurHash(hash: blurhash!);
          }
          return _buildSkeleton(effectiveWidth, effectiveHeight);
        },
        errorWidget: (context, url, error) =>
            _buildInitials(effectiveWidth, effectiveHeight),
      ),
    );
  }

  Widget _buildInitials(double width, double height) {
    final cleanName = username.trim().replaceAll('@', '');
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '';
    final gradient = _getGradient(cleanName);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: initial.isNotEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: (width * 0.42).clamp(10.0, 36.0),
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: (width * 0.55).clamp(12.0, 40.0),
            ),
    );
  }

  Widget _buildSkeleton(double width, double height) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade900,
      highlightColor: Colors.grey.shade800,
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
      ),
    );
  }
}
