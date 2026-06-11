import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';

import '../../core/services/api_service.dart';
import '../chat/chat_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final ApiService _apiService = ApiService();

  final CardSwiperController _swiperController = CardSwiperController();
  final ConfettiController _confettiController =
  ConfettiController(duration: const Duration(seconds: 3));

  List<dynamic> _profiles = [];

  bool _isLoading = true;
  bool _isMatching = false;

  Map<String, dynamic>? _lastMatch;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    try {
      final response = await _apiService.get('/discovery/swipe-discovery');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _profiles.addAll(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    final profile = _profiles[previousIndex];

    final String userId = profile['_id'] ?? profile['id'];
    final String username = profile['username'];

    String action = "pass";

    if (direction == CardSwiperDirection.right) action = "like";
    if (direction == CardSwiperDirection.top) action = "super_like";

    if (action != "pass") {
      _handleSwipeAction(userId, action, username);
    }

    if (_profiles.length - (currentIndex ?? 0) < 5) {
      _fetchProfiles();
    }

    return true;
  }

  Future<void> _handleSwipeAction(
      String targetId, String action, String username) async {
    try {
      final response = await _apiService.post('/swipe', {
        "target_user_id": targetId,
        "action": action,
      });

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result["match"] == true) {
          _showMatchExplosion(username, targetId);
        }
      }
    } catch (e) {
      debugPrint("Swipe error: $e");
    }
  }

  void _showMatchExplosion(String username, String id) {
    setState(() {
      _lastMatch = {"username": username, "id": id};
      _isMatching = true;
    });

    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF6C63FF)))
              : _profiles.isEmpty
              ? _buildEmptyState()
              : SafeArea(
            child: Column(
              children: [
                _buildRadarInfo(),
                Expanded(
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: _profiles.length,
                    numberOfCardsDisplayed: _profiles.length >= 3 ? 3 : _profiles.length,
                    onSwipe: _onSwipe,
                    backCardOffset: const Offset(0, 40),
                    padding: const EdgeInsets.all(20),
                    cardBuilder: (context, index,
                        horizontalThresholdPercentage,
                        verticalThresholdPercentage) {
                      return DiscoveryCard(
                        profile: _profiles[index],
                      );
                    },
                  ),
                ),
                _buildSwipeControls(),
              ],
            ),
          ),
          if (_isMatching) _buildMatchOverlay(),
        ],
      ),
    );
  }

  Widget _buildRadarInfo() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, color: Colors.greenAccent, size: 10),
          SizedBox(width: 8),
          Text(
            "24 people active nearby",
            style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          const Text(
            "You're out of matches for now",
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchProfiles,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
            ),
            child: const Text("REFRESH DISCOVERY"),
          )
        ],
      ),
    );
  }

  Widget _buildSwipeControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleBtn(Icons.close, Colors.redAccent,
                  () => _swiperController.swipe(CardSwiperDirection.left)),
          _buildCircleBtn(Icons.star, Colors.blueAccent,
                  () => _swiperController.swipe(CardSwiperDirection.top),
              isSmall: true),
          _buildCircleBtn(Icons.favorite, Colors.greenAccent,
                  () => _swiperController.swipe(CardSwiperDirection.right)),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(
      IconData icon, Color color, VoidCallback onTap,
      {bool isSmall = false}) {
    return Container(
      width: isSmall ? 50 : 64,
      height: isSmall ? 50 : 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2)
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: isSmall ? 24 : 32),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildMatchOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("❤️", style: TextStyle(fontSize: 80)),
              const Text(
                "It's a Match!",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                "You and @${_lastMatch?['username']} liked each other",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isMatching = false);
                },
                child: const Text("START CHAT"),
              ),
              TextButton(
                onPressed: () => setState(() => _isMatching = false),
                child: const Text("Keep Swiping"),
              )
            ],
          )
        ],
      ),
    );
  }
}

class DiscoveryCard extends StatelessWidget {
  final dynamic profile;

  const DiscoveryCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final int compatibility = profile['compatibility_score'] ?? 85;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircularPercentIndicator(
            radius: 90,
            percent: compatibility / 100,
            center: CircleAvatar(
              radius: 70,
              backgroundImage:
              NetworkImage(profile['avatar_url'] ?? ""),
            ),
            lineWidth: 8,
            progressColor: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 24),
          Text(
            "@${profile['username']}",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${profile['country'] ?? ""}",
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          _buildInterests(profile['interests'] ?? []),
          const Spacer(),
          _VoiceIntroBtn(url: profile['voice_intro_url']),
          const SizedBox(height: 20)
        ],
      ),
    );
  }

  Widget _buildInterests(List<dynamic> interests) {
    return Wrap(
      spacing: 8,
      children: interests.take(3).map((i) {
        return Chip(
          label: Text(i.toString()),
          backgroundColor: Colors.white10,
        );
      }).toList(),
    );
  }
}

class _VoiceIntroBtn extends StatefulWidget {
  final String? url;

  const _VoiceIntroBtn({this.url});

  @override
  State<_VoiceIntroBtn> createState() => _VoiceIntroBtnState();
}

class _VoiceIntroBtnState extends State<_VoiceIntroBtn> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;

  void _toggle() async {
    if (widget.url == null) return;

    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      await _player.setUrl(widget.url!);
      _player.play();
      setState(() => _isPlaying = true);

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          _player.stop();
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: const Color(0xFF6C63FF),
          ),
          const SizedBox(width: 6),
          const Text(
            "Voice Intro",
            style: TextStyle(color: Color(0xFF6C63FF)),
          )
        ],
      ),
    );
  }
}
