import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/music_provider.dart';
import '../models/music_track_model.dart';

class MusicPickerSheet extends StatefulWidget {
  final Function(MusicTrackModel track) onTrackSelected;

  const MusicPickerSheet({
    super.key,
    required this.onTrackSelected,
  });

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MusicProvider>(context, listen: false).fetchTrendingTracks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final query = _searchController.text.trim();
        final tracks = query.isEmpty ? musicProvider.trendingTracks : musicProvider.searchResults;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text("Music Library", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => musicProvider.searchTracks(val),
                decoration: InputDecoration(
                  hintText: "Search music or artists...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            musicProvider.searchTracks('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0F0F1A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              if (musicProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(musicProvider.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              Expanded(
                child: musicProvider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                    : tracks.isEmpty
                        ? const Center(child: Text("No tracks found", style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: tracks.length,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              final isPlaying = musicProvider.playingTrack?.id == track.id && musicProvider.isPlaying;

                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: track.albumArt.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: track.albumArt,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.white10, width: 48, height: 48),
                                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF6C63FF), width: 48, height: 48, child: const Icon(Icons.music_note, color: Colors.white)),
                                        )
                                      : Container(color: const Color(0xFF6C63FF), width: 48, height: 48, child: const Icon(Icons.music_note, color: Colors.white)),
                                ),
                                title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${track.artist} • ${track.genre}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                    if (isPlaying) ...[
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: musicProvider.duration.inMilliseconds > 0
                                            ? (musicProvider.position.inMilliseconds / musicProvider.duration.inMilliseconds).clamp(0.0, 1.0)
                                            : 0.0,
                                        backgroundColor: Colors.white10,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                                        minHeight: 2,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${_formatDuration(musicProvider.position)} / ${_formatDuration(musicProvider.duration)}",
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded,
                                        color: const Color(0xFF6C63FF),
                                        size: 32,
                                      ),
                                      onPressed: () => musicProvider.previewTrack(track),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: () {
                                        musicProvider.stopPreview();
                                        Navigator.pop(context);
                                        widget.onTrackSelected(track);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6C63FF),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(60, 32),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text("Select", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
