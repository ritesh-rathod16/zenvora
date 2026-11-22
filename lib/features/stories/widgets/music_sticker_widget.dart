import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/music_track_model.dart';

enum MusicStickerStyle { albumArtCard, compactPill, lyricsCard }

class MusicStickerWidget extends StatelessWidget {
  final MusicTrackModel track;
  final MusicStickerStyle style;
  final Color backgroundColor;
  final List<Map<String, dynamic>>? lyricsLines;
  final double currentPositionSeconds;

  const MusicStickerWidget({
    super.key,
    required this.track,
    this.style = MusicStickerStyle.albumArtCard,
    this.backgroundColor = const Color(0xFF1A1A2E),
    this.lyricsLines,
    this.currentPositionSeconds = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case MusicStickerStyle.compactPill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: track.albumArt.isNotEmpty
                    ? CachedNetworkImage(imageUrl: track.albumArt, width: 32, height: 32, fit: BoxFit.cover)
                    : Container(width: 32, height: 32, color: const Color(0xFF6C63FF), child: const Icon(Icons.music_note, color: Colors.white, size: 16)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(track.artist, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ],
          ),
        );

      case MusicStickerStyle.lyricsCard:
        String activeLyric = "♪ ${track.title} • ${track.artist} ♪";
        if (lyricsLines != null && lyricsLines!.isNotEmpty) {
          for (var line in lyricsLines!.reversed) {
            final t = (line['time'] as num?)?.toDouble() ?? 0.0;
            if (currentPositionSeconds >= t) {
              activeLyric = line['text']?.toString() ?? activeLyric;
              break;
            }
          }
        }

        return Container(
          width: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "♪ Synchronized Lyrics ♪",
                style: TextStyle(color: Color(0xFF00D2FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Text(
                activeLyric,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                track.artist,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        );

      case MusicStickerStyle.albumArtCard:
        return Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: track.albumArt.isNotEmpty
                    ? CachedNetworkImage(imageUrl: track.albumArt, width: 56, height: 56, fit: BoxFit.cover)
                    : Container(width: 56, height: 56, color: const Color(0xFF6C63FF), child: const Icon(Icons.music_note, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.music_note_rounded, color: Color(0xFF6C63FF), size: 12),
                        SizedBox(width: 4),
                        Text("Zenvora Music", style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}
