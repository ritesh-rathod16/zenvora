import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StoryGalleryPicker extends StatefulWidget {
  final Function(String path) onMediaSelected;

  const StoryGalleryPicker({
    super.key,
    required this.onMediaSelected,
  });

  @override
  State<StoryGalleryPicker> createState() => _StoryGalleryPickerState();
}

class _StoryGalleryPickerState extends State<StoryGalleryPicker> {
  final ImagePicker _picker = ImagePicker();
  String _selectedAlbum = "Recents";
  bool _isLoading = false;

  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null && mounted) {
        widget.onMediaSelected(file.path);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideoFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 15));
      if (file != null && mounted) {
        widget.onMediaSelected(file.path);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _selectedAlbum,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: "Recents", child: Text("Recents")),
                  DropdownMenuItem(value: "Camera", child: Text("Camera")),
                  DropdownMenuItem(value: "Favorites", child: Text("Favorites")),
                  DropdownMenuItem(value: "Downloads", child: Text("Downloads")),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAlbum = val);
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _buildPickerTile(
                        icon: Icons.photo_library_rounded,
                        label: "Select Photo",
                        onTap: _pickImageFromGallery,
                      ),
                      _buildPickerTile(
                        icon: Icons.videocam_rounded,
                        label: "Select Video",
                        onTap: _pickVideoFromGallery,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF6C63FF), size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
