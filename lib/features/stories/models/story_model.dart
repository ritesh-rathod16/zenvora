class StorySlideModel {
  final String id;
  final String authorId;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final bool isCloseFriendsOnly;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewsCount;

  StorySlideModel({
    required this.id,
    required this.authorId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.isCloseFriendsOnly,
    required this.createdAt,
    required this.expiresAt,
    required this.viewsCount,
  });

  factory StorySlideModel.fromJson(Map<String, dynamic> json) {
    return StorySlideModel(
      id: json['id'] ?? json['_id'] ?? '',
      authorId: json['author_id'] ?? json['user_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      caption: json['caption'],
      isCloseFriendsOnly: json['is_close_friends_only'] == true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : DateTime.now().add(const Duration(hours: 24)),
      viewsCount: json['views_count'] ?? (json['views'] is List ? (json['views'] as List).length : 0),
    );
  }
}

class StoryGroupModel {
  final String authorId;
  final String? authorPhoto;
  final bool hasCloseFriendsStory;
  final bool hasUnseenStory;
  final List<StorySlideModel> slides;

  StoryGroupModel({
    required this.authorId,
    this.authorPhoto,
    required this.hasCloseFriendsStory,
    required this.hasUnseenStory,
    required this.slides,
  });

  factory StoryGroupModel.fromJson(Map<String, dynamic> json) {
    final List slidesRaw = json['slides'] is List ? json['slides'] : (json['stories'] is List ? json['stories'] : [json]);
    final slidesParsed = slidesRaw.map((s) => StorySlideModel.fromJson(s)).toList();

    return StoryGroupModel(
      authorId: json['author_id'] ?? json['user_id'] ?? '',
      authorPhoto: json['author_photo'] ?? json['avatar_url'],
      hasCloseFriendsStory: json['is_close_friends_only'] == true || slidesParsed.any((s) => s.isCloseFriendsOnly),
      hasUnseenStory: json['has_unseen'] ?? true,
      slides: slidesParsed,
    );
  }
}
