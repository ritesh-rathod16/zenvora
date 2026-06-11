import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:shimmer/shimmer.dart';

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

  String get _fallbackUrl =>
      "https://api.dicebear.com/7.x/avataaars/png?seed=$username";

  String _optimizeUrl(String url) {
    if (url.contains('supabase.co')) {
      // Add resizing parameters for Supabase CDN optimization
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['width'] = '300';
      params['quality'] = '80';
      return uri.replace(queryParameters: params).toString();
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? radius * 2;
    final effectiveHeight = height ?? radius * 2;

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return _buildFallback(effectiveWidth, effectiveHeight);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: _optimizeUrl(avatarUrl!),
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
            _buildFallback(effectiveWidth, effectiveHeight),
      ),
    );
  }

  Widget _buildFallback(double width, double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: _fallbackUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildSkeleton(width, height),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade900,
          child: const Icon(Icons.person, color: Colors.white24),
        ),
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
        decoration: BoxDecoration(
          shape: radius > 0 ? BoxShape.circle : BoxShape.rectangle,
          color: Colors.black,
        ),
      ),
    );
  }
}
