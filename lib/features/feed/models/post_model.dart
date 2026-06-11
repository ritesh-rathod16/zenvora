enum PostType { confession, poll, normal, story }

class PostModel {
  final String id;
  final PostType type;
  final String authorId;
  final String content;
  final int likes;
  final int repliesCount;
  final bool isTrending;
  final bool aiVerified;
  final List<PollOption>? pollOptions;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.type,
    required this.authorId,
    required this.content,
    required this.likes,
    required this.repliesCount,
    required this.isTrending,
    required this.aiVerified,
    this.pollOptions,
    required this.createdAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] ?? '',
      type: _parsePostType(json['type']),
      authorId: json['author_id'] ?? 'Anonymous',
      content: json['content'] ?? '',
      likes: json['likes'] ?? 0,
      repliesCount: json['replies_count'] ?? 0,
      isTrending: json['is_trending'] ?? false,
      aiVerified: json['ai_verified'] ?? true,
      pollOptions: json['poll_options'] != null
          ? (json['poll_options'] as List)
              .map((e) => PollOption.fromJson(e))
              .toList()
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
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
      label: json['label'] ?? '',
      votes: json['votes'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}
