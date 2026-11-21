import '../constants/api_constants.dart';

/// Helper utility for image processing, CDN optimization (ImageKit),
/// validation, and fallback handling across the Zenvora platform.
class ImageHelper {
  static const String defaultCdnDomain = "ik.imagekit.io";

  /// Resolves relative backend paths (e.g. /media/profile/...) against ApiConstants.baseUrl
  static String resolveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return "";
    final trimmed = url.trim();
    if (trimmed.contains('dicebear.com')) return "";

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      final base = ApiConstants.baseUrl;
      return Uri.parse('$base/').resolve(trimmed).toString();
    }

    return trimmed;
  }

  /// Validates whether a given string is a non-empty, well-formed HTTP/HTTPS URL.
  static bool isValidUrl(String? url) {
    final resolved = resolveUrl(url);
    if (resolved.isEmpty) return false;
    final uri = Uri.tryParse(resolved);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Checks if the image is an SVG.
  static bool isSvg(String? url) {
    if (url == null || url.isEmpty) return false;
    final clean = url.toLowerCase();
    return clean.endsWith('.svg') || clean.contains('/svg?') || clean.contains('/svg');
  }

  /// Transforms and optimizes ImageKit CDN URLs dynamically.
  static String safeImage(
    String? url, {
    int width = 400,
    int? height,
    int quality = 80,
    String format = 'auto',
  }) {
    final resolved = resolveUrl(url);
    if (resolved.isEmpty) {
      return "";
    }

    // ImageKit CDN dynamic transformations
    if (resolved.contains(defaultCdnDomain) || resolved.contains('imagekit.io')) {
      final uri = Uri.parse(resolved);
      final params = Map<String, String>.from(uri.queryParameters);

      final List<String> transforms = [];
      transforms.add("w-$width");
      if (height != null && height > 0) {
        transforms.add("h-$height");
      }
      transforms.add("q-$quality");
      if (format.isNotEmpty) {
        transforms.add("f-$format");
      }

      params['tr'] = transforms.join(',');
      return uri.replace(queryParameters: params).toString();
    }

    return resolved;
  }

  /// Convenience method for optimized avatar image delivery.
  static String avatar(String? url, {int size = 150}) {
    return safeImage(url, width: size, height: size, quality: 80);
  }

  /// Convenience method for thumbnail generation.
  static String thumbnail(String? url, {int width = 200, int height = 200}) {
    return safeImage(url, width: width, height: height, quality: 75);
  }

  /// Returns the original image URL without CDN downscaling transformations.
  static String fullResolution(String? url) {
    final resolved = resolveUrl(url);
    if (resolved.isEmpty) return "";

    if (resolved.contains(defaultCdnDomain) || resolved.contains('imagekit.io')) {
      final uri = Uri.parse(resolved);
      final params = Map<String, String>.from(uri.queryParameters)..remove('tr');
      return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
    }

    return resolved;
  }
}
