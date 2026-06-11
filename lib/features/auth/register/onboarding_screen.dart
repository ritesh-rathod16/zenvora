import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final ApiService _apiService = ApiService();
  int _currentPage = 0;

  // Data State
  String _gender = "male";
  String _interestedIn = "everyone";
  RangeValues _ageRange = const RangeValues(18, 35);
  File? _profileImage;
  String? _avatarUrl;
  final _bioController = TextEditingController();
  String _personalityType = "Explorer";
  List<String> _selectedInterests = [];
  String? _voiceIntroPath;
  String? _voiceIntroUrl;

  final List<String> _personalities = [
    "Explorer", "Dreamer", "Strategist", "Adventurer", 
    "Creator", "Observer", "Thinker", "Visionary"
  ];

  final List<String> _interestsList = [
    "Music", "Books", "Movies", "Gaming", "Anime", "Travel", "Fitness", 
    "Art", "Photography", "Tech", "Coding", "Food", "Nature", "Meditation",
    "Fashion", "Sports", "Startups", "Design", "AI", "Space"
  ];

  // Voice recording state
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitOnboarding();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
      _uploadAvatar();
    }
  }

  Future<void> _uploadAvatar() async {
    if (_profileImage == null) return;
    try {
      final response = await _apiService.uploadFile('/users/avatar', _profileImage!.path);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _avatarUrl = data['avatar_url']);
      }
    } catch (e) {
      debugPrint("Avatar upload error: $e");
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/voice_intro.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _voiceIntroPath = path;
        });
        
        // Auto stop after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (_isRecording) _stopRecording();
        });
      }
    } catch (e) {
      debugPrint("Recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _voiceIntroPath = path;
    });
    _uploadVoiceIntro();
  }

  Future<void> _uploadVoiceIntro() async {
    if (_voiceIntroPath == null) return;
    try {
      final response = await _apiService.uploadFile('/users/voice-intro', _voiceIntroPath!);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _voiceIntroUrl = data['voice_intro_url']);
      }
    } catch (e) {
      debugPrint("Voice upload error: $e");
    }
  }

  Future<void> _playPreview() async {
    if (_voiceIntroPath == null) return;
    setState(() => _isPlaying = true);
    await _audioPlayer.setFilePath(_voiceIntroPath!);
    await _audioPlayer.play();
    setState(() => _isPlaying = false);
  }

  Future<void> _submitOnboarding() async {
    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 3 interests")));
      return;
    }
    if (_avatarUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a profile photo")));
      return;
    }

    try {
      final response = await _apiService.post('/users/onboarding', {
        "gender": _gender,
        "interested_in": _interestedIn,
        "age_min": _ageRange.start.round(),
        "age_max": _ageRange.end.round(),
        "avatar_url": _avatarUrl,
        "bio": _bioController.text,
        "personality_type": _personalityType,
        "interests": _selectedInterests,
        "voice_intro_url": _voiceIntroUrl,
      });

      if (response.statusCode == 200) {
        if (mounted) context.go('/home');
      }
    } catch (e) {
      debugPrint("Onboarding submit error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 7,
                backgroundColor: Colors.white10,
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPreferencesPage(),
                  _buildPhotoPage(),
                  _buildBioPage(),
                  _buildPersonalityPage(),
                  _buildInterestsPage(),
                  _buildVoicePage(),
                  _buildFinalPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_currentPage == 6 ? "FINISH SETUP" : "CONTINUE"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return _buildPageWrapper(
      title: "Set Your Match Preferences",
      subtitle: "This helps us show you the right people.",
      content: [
        const Text("What is your gender?", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        _buildSelectionRow(["male", "female", "non_binary", "unknown"], _gender, (v) => setState(() => _gender = v)),
        const SizedBox(height: 32),
        const Text("Who would you like to see?", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        _buildSelectionRow(["male", "female", "everyone"], _interestedIn, (v) => setState(() => _interestedIn = v)),
        const SizedBox(height: 32),
        Text("Preferred Age Range: ${_ageRange.start.round()} - ${_ageRange.end.round()}", style: const TextStyle(color: Colors.white70)),
        RangeSlider(
          values: _ageRange,
          min: 18,
          max: 60,
          activeColor: const Color(0xFF6C63FF),
          onChanged: (v) => setState(() => _ageRange = v),
        ),
      ],
    );
  }

  Widget _buildSelectionRow(List<String> options, String current, Function(String) onSelect) {
    return Wrap(
      spacing: 10,
      children: options.map((opt) => ChoiceChip(
        label: Text(opt.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10)),
        selected: current == opt,
        onSelected: (s) => onSelect(opt),
        selectedColor: const Color(0xFF6C63FF),
        backgroundColor: const Color(0xFF1A1A2E),
      )).toList(),
    );
  }

  Widget _buildPhotoPage() {
    return _buildPageWrapper(
      title: "Add Your Profile Photo",
      subtitle: "People are more likely to match when they can see you.",
      content: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: const Color(0xFF1A1A2E),
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? const Icon(Icons.person, size: 80, color: Colors.white10) : null,
              ),
              if (_avatarUrl != null) 
                const Positioned(bottom: 0, right: 0, child: Icon(Icons.check_circle, color: Colors.green, size: 32)),
            ],
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text("TAKE PHOTO"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.image),
          label: const Text("CHOOSE FROM GALLERY"),
        ),
      ],
    );
  }

  Widget _buildBioPage() {
    return _buildPageWrapper(
      title: "Tell people about you",
      subtitle: "Write something interesting about yourself.",
      content: [
        TextField(
          controller: _bioController,
          maxLength: 150,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: "Write your bio...",
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityPage() {
    return _buildPageWrapper(
      title: "What describes you best?",
      subtitle: "This value will be used in compatibility scoring.",
      content: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: _personalities.map((p) => InkWell(
            onTap: () => setState(() => _personalityType = p),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _personalityType == p ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(p, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildInterestsPage() {
    return _buildPageWrapper(
      title: "Select Your Interests",
      subtitle: "Choose 3-5 things you love.",
      content: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interestsList.map((i) {
            final selected = _selectedInterests.contains(i);
            return FilterChip(
              label: Text(i),
              selected: selected,
              onSelected: (s) {
                setState(() {
                  if (selected) {
                    _selectedInterests.remove(i);
                  } else if (_selectedInterests.length < 5) {
                    _selectedInterests.add(i);
                  }
                });
              },
              selectedColor: const Color(0xFF6C63FF),
              backgroundColor: const Color(0xFF1A1A2E),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVoicePage() {
    return _buildPageWrapper(
      title: "Add a Voice Intro",
      subtitle: "Record up to 10 seconds. Show your personality!",
      content: [
        Center(
          child: Column(
            children: [
              IconButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                iconSize: 80,
                icon: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic,
                  color: _isRecording ? Colors.red : const Color(0xFF6C63FF),
                ),
              ),
              Text(_isRecording ? "RECORDING..." : "TAP TO RECORD"),
              const SizedBox(height: 40),
              if (_voiceIntroPath != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _playPreview,
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      label: const Text("PLAY PREVIEW"),
                    ),
                    const SizedBox(width: 12),
                    if (_voiceIntroUrl != null) const Icon(Icons.cloud_done, color: Colors.green),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalPage() {
    return _buildPageWrapper(
      title: "You're all set!",
      subtitle: "Zenvora is ready for you. Let's find your first match.",
      content: [
        const Center(child: Icon(Icons.rocket_launch, size: 120, color: Color(0xFF6C63FF))),
      ],
    );
  }

  Widget _buildPageWrapper({required String title, required String subtitle, required List<Widget> content}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white38)),
          const SizedBox(height: 40),
          ...content,
        ],
      ),
    );
  }
}
