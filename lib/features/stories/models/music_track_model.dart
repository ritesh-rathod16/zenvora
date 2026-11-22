class MusicTrackModel {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final String previewUrl;
  final int duration;
  final String genre;

  MusicTrackModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumArt,
    required this.previewUrl,
    required this.duration,
    required this.genre,
  });

  factory MusicTrackModel.fromJson(Map<String, dynamic> json) {
    return MusicTrackModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Track',
      artist: json['artist'] ?? 'Unknown Artist',
      albumArt: json['album_art'] ?? '',
      previewUrl: json['preview_url'] ?? '',
      duration: json['duration'] ?? 30,
      genre: json['genre'] ?? 'Music',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album_art': albumArt,
    'preview_url': previewUrl,
    'duration': duration,
    'genre': genre,
  };
}
