import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../stories/widgets/story_drawing_canvas.dart';
import '../../stories/widgets/sticker_picker_sheet.dart';
import '../../stories/widgets/music_picker_sheet.dart';
import '../../stories/models/music_track_model.dart';

class StoryEditorScreen extends StatefulWidget {
  final String imagePath;

  const StoryEditorScreen({super.key, required this.imagePath});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _captionController = TextEditingController();
  final GlobalKey<StoryDrawingCanvasState> _canvasKey = GlobalKey<StoryDrawingCanvasState>();

  bool _isCloseFriendsOnly = false;
  bool _isUploading = false;
  bool _isDrawingMode = false;
  Color _selectedDrawingColor = const Color(0xFF6C63FF);
  final double _strokeWidth = 4.0;

  Map<String, dynamic>? _selectedPoll;
  MusicTrackModel? _selectedMusicTrack;

  final List<Color> _palette = const [
    Color(0xFF6C63FF),
    Colors.white,
    Colors.amberAccent,
    Colors.redAccent,
    Colors.cyanAccent,
    Colors.greenAccent,
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _openStickerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPickerSheet(
        onStickerSelected: (type, data) {
          if (type == 'poll') {
            setState(() {
              _selectedPoll = {
                "question": "What's your vibe?",
                "options": ["Yes", "No"]
              };
            });
          }
        },
        onGifSelected: (gifUrl) {},
      ),
    );
  }

  void _openMusicPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerSheet(
        onTrackSelected: (track) {
          setState(() {
            _selectedMusicTrack = track;
          });
        },
      ),
    );
  }

  Future<void> _publishStory() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      Map<String, String> fields = {
        'caption': _captionController.text.trim(),
        'is_close_friends_only': _isCloseFriendsOnly.toString(),
      };

      if (_selectedPoll != null) {
        fields['poll'] = jsonEncode(_selectedPoll);
      }
      if (_selectedMusicTrack != null) {
        fields['music_track'] = jsonEncode(_selectedMusicTrack!.toJson());
      }

      final res = await _apiService.uploadFile(
        '/stories/create',
        widget.imagePath,
        fields: fields,
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story published successfully!")),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to publish story")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media Preview
          Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
          ),

          // Freehand Drawing Canvas Overlay
          if (_isDrawingMode)
            StoryDrawingCanvas(
              key: _canvasKey,
              selectedColor: _selectedDrawingColor,
              strokeWidth: _strokeWidth,
            ),

          // Gradient Overlay
          if (!_isDrawingMode)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),

          // Top Header Controls
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.draw_rounded,
                        color: _isDrawingMode ? const Color(0xFF6C63FF) : Colors.white,
                        size: 26,
                      ),
                      onPressed: () => setState(() => _isDrawingMode = !_isDrawingMode),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 26),
                      onPressed: _openStickerPicker,
                    ),
                    IconButton(
                      icon: const Icon(Icons.music_note_rounded, color: Colors.white, size: 26),
                      onPressed: _openMusicPicker,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Render active poll or music sticker preview on canvas
          if (_selectedPoll != null)
            Positioned(
              bottom: 160,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_selectedPoll!['question'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_selectedPoll!['options'] as List).map((opt) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(opt.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                    )),
                  ],
                ),
              ),
            ),

          // Drawing Palette Bar when in Drawing Mode
          if (_isDrawingMode)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, color: Colors.white),
                    onPressed: () => _canvasKey.currentState?.undo(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _canvasKey.currentState?.clear(),
                  ),
                  const SizedBox(width: 12),
                  ..._palette.map((color) => GestureDetector(
                    onTap: () => setState(() => _selectedDrawingColor = color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedDrawingColor == color ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),

          // Bottom Controls & Caption
          if (!_isDrawingMode)
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add a caption...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black45,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : () {
                                  setState(() => _isCloseFriendsOnly = false);
                                  _publishStory();
                                },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text("Your Story"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading
                              ? null
                              : () {
                                  setState(() => _isCloseFriendsOnly = true);
                                  _publishStory();
                                },
                          icon: const Icon(Icons.stars_rounded, color: Color(0xFF00FF87), size: 18),
                          label: const Text("Close Friends"),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00FF87), width: 1.5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    SizedBox(height: 16),
                    Text("Sharing story...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
