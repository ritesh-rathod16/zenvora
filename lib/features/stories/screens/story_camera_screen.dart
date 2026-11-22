import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/story_camera_provider.dart';
import '../../feed/widgets/story_editor_screen.dart';

class StoryCameraScreen extends StatefulWidget {
  const StoryCameraScreen({super.key});

  @override
  State<StoryCameraScreen> createState() => _StoryCameraScreenState();
}

class _StoryCameraScreenState extends State<StoryCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  Timer? _recordingTimer;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final cameraProvider = Provider.of<StoryCameraProvider>(context, listen: false);
    final source = cameraProvider.isFrontCamera ? ImageSource.camera : ImageSource.camera;
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: cameraProvider.isFrontCamera ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        _openStoryEditor(photo.path);
      }
    } catch (_) {
      // Fallback gallery selection if camera hardware is unavailable
      _pickFromGallery();
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? media = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (media != null && mounted) {
        _openStoryEditor(media.path);
      }
    } catch (_) {}
  }

  void _openStoryEditor(String mediaPath) async {
    final bool? published = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StoryEditorScreen(imagePath: mediaPath),
      ),
    );

    if (published == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _startVideoRecording() {
    final provider = Provider.of<StoryCameraProvider>(context, listen: false);
    provider.startRecording();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick >= 15) {
        _stopVideoRecording();
      } else {
        provider.updateRecordingTime(timer.tick);
      }
    });
  }

  void _stopVideoRecording() async {
    _recordingTimer?.cancel();
    final provider = Provider.of<StoryCameraProvider>(context, listen: false);
    if (!provider.isRecording) return;

    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 15));
      if (video != null && mounted) {
        provider.stopRecording(video.path);
        _openStoryEditor(video.path);
      } else {
        provider.clearCapturedMedia();
      }
    } catch (_) {
      provider.clearCapturedMedia();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoryCameraProvider>(
      builder: (context, cameraProvider, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera Viewport Preview / Background
                Container(
                  color: const Color(0xFF0F0F1A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cameraProvider.isFrontCamera ? Icons.person_outline_rounded : Icons.photo_camera_outlined,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          cameraProvider.isFrontCamera ? "Front Camera Active" : "Rear Camera Active",
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Control Bar
                Positioned(
                  top: 16,
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
                              cameraProvider.flashMode == "on"
                                  ? Icons.flash_on_rounded
                                  : (cameraProvider.flashMode == "auto" ? Icons.flash_auto_rounded : Icons.flash_off_rounded),
                              color: cameraProvider.flashMode == "off" ? Colors.white70 : Colors.amberAccent,
                              size: 24,
                            ),
                            onPressed: cameraProvider.cycleFlash,
                          ),
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 24),
                            onPressed: cameraProvider.toggleCamera,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Side Camera Creation Modes
                Positioned(
                  left: 16,
                  top: 100,
                  child: Column(
                    children: [
                      _buildModeIcon(Icons.text_fields_rounded, "Create", CameraMode.create, cameraProvider),
                      _buildModeIcon(Icons.loop_rounded, "Boomerang", CameraMode.boomerang, cameraProvider),
                      _buildModeIcon(Icons.grid_view_rounded, "Layout", CameraMode.layout, cameraProvider),
                      _buildModeIcon(Icons.auto_awesome_rounded, "Effects", CameraMode.effects, cameraProvider),
                    ],
                  ),
                ),

                // Bottom Controls Area
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Recording Duration Indicator if recording video
                      if (cameraProvider.isRecording) ...[
                        Text(
                          "00:${cameraProvider.recordingSeconds.toString().padLeft(2, '0')}",
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Gallery Thumbnail Button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white30, width: 1.5),
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                            ),
                          ),

                          // Main Capture / Video Record Button
                          GestureDetector(
                            onTap: _capturePhoto,
                            onLongPressStart: (_) => _startVideoRecording(),
                            onLongPressEnd: (_) => _stopVideoRecording(),
                            child: Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cameraProvider.isRecording ? Colors.redAccent : Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cameraProvider.isRecording ? Colors.redAccent : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),

                          // Secondary Filter Action
                          IconButton(
                            icon: const Icon(Icons.color_lens_outlined, color: Colors.white, size: 28),
                            onPressed: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Horizontal Mode Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildModeSelector("NORMAL", CameraMode.normal, cameraProvider),
                            _buildModeSelector("CREATE", CameraMode.create, cameraProvider),
                            _buildModeSelector("BOOMERANG", CameraMode.boomerang, cameraProvider),
                            _buildModeSelector("LAYOUT", CameraMode.layout, cameraProvider),
                            _buildModeSelector("EFFECTS", CameraMode.effects, cameraProvider),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeIcon(IconData icon, String label, CameraMode mode, StoryCameraProvider provider) {
    final isSelected = provider.selectedMode == mode;
    return GestureDetector(
      onTap: () {
        provider.setMode(mode);
        if (mode == CameraMode.create) {
          // Open create mode directly
          _pickFromGallery();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildModeSelector(String label, CameraMode mode, StoryCameraProvider provider) {
    final isSelected = provider.selectedMode == mode;
    return GestureDetector(
      onTap: () => provider.setMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
