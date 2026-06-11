import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import '../core/utils/image_helper.dart';
import 'default_avatar.dart';
import 'skeleton_avatar.dart';

class AppAvatar extends StatelessWidget {
  final String? url;
  final String username;
  final String? blurhash;
  final double radius;

  const AppAvatar({
    super.key, 
    this.url, 
    required this.username, 
    this.blurhash,
    this.radius = 30,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return DefaultAvatar(radius: radius);
    }

    final safeUrl = ImageHelper.safeImage(url);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: safeUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        memCacheWidth: 512,
        maxWidthDiskCache: 1024,
        placeholder: (context, url) {
          if (blurhash != null && blurhash!.isNotEmpty) {
            return BlurHash(
              hash: blurhash!,
              imageFit: BoxFit.cover,
            );
          }
          return SkeletonAvatar(radius: radius);
        },
        errorWidget: (context, url, error) => DefaultAvatar(radius: radius),
      ),
    );
  }
}
