import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/services/api_service.dart';

class StoryEditorScreen extends StatefulWidget {
  final String imagePath;

  const StoryEditorScreen({super.key, required this.imagePath});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _captionController = TextEditingController();
  bool _isCloseFriendsOnly = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _publishStory() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final res = await _apiService.uploadFile(
        '/stories/create',
        widget.imagePath,
        fields: {
          'caption': _captionController.text.trim(),
          'is_close_friends_only': _isCloseFriendsOnly.toString(),
        },
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

          // Gradient Overlay
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
                      icon: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 26),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 26),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Controls & Caption
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
