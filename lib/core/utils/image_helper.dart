class ImageHelper {
  /// Optimizes Supabase URLs for CDN resizing and quality.
  static String safeImage(String? url, {int width = 400, int quality = 80}) {
    if (url == null || url.isEmpty) {
      return "";
    }

    if (url.contains('supabase.co')) {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['width'] = width.toString();
      params['quality'] = quality.toString();
      return uri.replace(queryParameters: params).toString();
    }
    
    return url;
  }

  static bool isSvg(String url) => url.toLowerCase().endsWith('.svg');
}
