/// Helper utility for image processing, CDN optimization (ImageKit),
/// validation, and fallback handling across the Zenvora platform.
class ImageHelper {
  static const String defaultCdnDomain = "ik.imagekit.io";

  /// Validates whether a given string is a non-empty, well-formed HTTP/HTTPS URL.
  /// Rejects any synthetic avatar URLs like DiceBear to respect user photo uploads.
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmed = url.trim();
    if (trimmed.contains('dicebear.com')) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Checks if the image is an SVG.
  static bool isSvg(String? url) {
    if (url == null || url.isEmpty) return false;
    final clean = url.toLowerCase();
    return clean.endsWith('.svg') || clean.contains('/svg?') || clean.contains('/svg');
  }

  /// Transforms and optimizes ImageKit CDN URLs dynamically.
  /// If the URL does not belong to ImageKit, it is returned without modification.
  static String safeImage(
    String? url, {
    int width = 400,
    int? height,
    int quality = 80,
    String format = 'auto',
  }) {
    if (!isValidUrl(url)) {
      return "";
    }

    String trimmedUrl = url!.trim();

    // ImageKit CDN dynamic transformations
    if (trimmedUrl.contains(defaultCdnDomain) || trimmedUrl.contains('imagekit.io')) {
      final uri = Uri.parse(trimmedUrl);
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

    return trimmedUrl;
  }

  /// Convenience method for optimized avatar image delivery.
  static String avatar(String? url, {int size = 150}) {
    if (!isValidUrl(url)) {
      return "";
    }
    return safeImage(url, width: size, height: size, quality: 80);
  }

  /// Convenience method for thumbnail generation.
  static String thumbnail(String? url, {int width = 200, int height = 200}) {
    return safeImage(url, width: width, height: height, quality: 75);
  }

  /// Returns the original image URL without CDN downscaling transformations.
  static String fullResolution(String? url) {
    if (!isValidUrl(url)) return "";
    final trimmedUrl = url!.trim();

    if (trimmedUrl.contains(defaultCdnDomain) || trimmedUrl.contains('imagekit.io')) {
      final uri = Uri.parse(trimmedUrl);
      final params = Map<String, String>.from(uri.queryParameters)..remove('tr');
      return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
    }

    return trimmedUrl;
  }
}
