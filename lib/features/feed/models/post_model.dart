enum PostType { confession, poll, normal, story }

class PostModel {
  final String id;
  final PostType type;
  final String authorId;
  final String? authorPhoto;
  final String? authorDisplayName;
  final String content;
  final String? mediaUrl;
  final int likes;
  final int repliesCount;
  final int repostsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isReposted;
  final bool isRepost;
  final String? originalAuthorId;
  final String? originalAuthorPhoto;
  final String? originalPostId;
  final bool isTrending;
  final bool aiVerified;
  final List<PollOption>? pollOptions;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.type,
    required this.authorId,
    this.authorPhoto,
    this.authorDisplayName,
    required this.content,
    this.mediaUrl,
    required this.likes,
    required this.repliesCount,
    this.repostsCount = 0,
    this.sharesCount = 0,
    this.isLiked = false,
    this.isReposted = false,
    this.isRepost = false,
    this.originalAuthorId,
    this.originalAuthorPhoto,
    this.originalPostId,
    required this.isTrending,
    required this.aiVerified,
    this.pollOptions,
    required this.createdAt,
  });

  PostModel copyWith({
    String? id,
    PostType? type,
    String? authorId,
    String? authorPhoto,
    String? authorDisplayName,
    String? content,
    String? mediaUrl,
    int? likes,
    int? repliesCount,
    int? repostsCount,
    int? sharesCount,
    bool? isLiked,
    bool? isReposted,
    bool? isRepost,
    String? originalAuthorId,
    String? originalAuthorPhoto,
    String? originalPostId,
    bool? isTrending,
    bool? aiVerified,
    List<PollOption>? pollOptions,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      type: type ?? this.type,
      authorId: authorId ?? this.authorId,
      authorPhoto: authorPhoto ?? this.authorPhoto,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      likes: likes ?? this.likes,
      repliesCount: repliesCount ?? this.repliesCount,
      repostsCount: repostsCount ?? this.repostsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLiked: isLiked ?? this.isLiked,
      isReposted: isReposted ?? this.isReposted,
      isRepost: isRepost ?? this.isRepost,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      originalAuthorPhoto: originalAuthorPhoto ?? this.originalAuthorPhoto,
      originalPostId: originalPostId ?? this.originalPostId,
      isTrending: isTrending ?? this.isTrending,
      aiVerified: aiVerified ?? this.aiVerified,
      pollOptions: pollOptions ?? this.pollOptions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    int likesCount = 0;
    if (json['likes'] is List) {
      likesCount = (json['likes'] as List).length;
    } else if (json['likes'] is int) {
      likesCount = json['likes'];
    } else if (json['likes_count'] is int) {
      likesCount = json['likes_count'];
    }

    final String rawId = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final String? media = json['media_url']?.toString() ?? json['image_url']?.toString();

    int reposts = 0;
    if (json['reposts_count'] is int) {
      reposts = json['reposts_count'];
    } else if (json['reposts'] is List) {
      reposts = (json['reposts'] as List).length;
    }

    int shares = json['shares_count'] is int ? json['shares_count'] : 0;

    return PostModel(
      id: rawId,
      type: _parsePostType(json['type']),
      authorId: json['author_id']?.toString() ?? 'Anonymous',
      authorPhoto: json['author_photo']?.toString(),
      authorDisplayName: json['author_display_name']?.toString(),
      content: json['content']?.toString() ?? '',
      mediaUrl: (media != null && media.isNotEmpty) ? media : null,
      likes: likesCount,
      repliesCount: json['replies_count'] is int ? json['replies_count'] : 0,
      repostsCount: reposts,
      sharesCount: shares,
      isLiked: json['is_liked'] == true,
      isReposted: json['is_reposted'] == true,
      isRepost: json['is_repost'] == true,
      originalAuthorId: json['original_author_id']?.toString(),
      originalAuthorPhoto: json['original_author_photo']?.toString(),
      originalPostId: json['original_post_id']?.toString(),
      isTrending: json['is_trending'] == true || likesCount >= 3,
      aiVerified: json['ai_verified'] ?? true,
      pollOptions: json['poll_options'] != null
          ? (json['poll_options'] as List)
              .map((e) => PollOption.fromJson(e))
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static PostType _parsePostType(String? type) {
    switch (type) {
      case 'confession':
        return PostType.confession;
      case 'poll':
        return PostType.poll;
      case 'story':
        return PostType.story;
      default:
        return PostType.normal;
    }
  }
}

class PollOption {
  final String label;
  final int votes;
  final double percentage;

  PollOption({required this.label, required this.votes, required this.percentage});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      label: json['label']?.toString() ?? '',
      votes: json['votes'] is int ? json['votes'] : 0,
      percentage: (json['percentage'] is num ? (json['percentage'] as num).toDouble() : 0.0),
    );
  }
}
