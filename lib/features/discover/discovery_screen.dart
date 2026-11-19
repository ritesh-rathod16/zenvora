import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/api_service.dart';
import '../../widgets/safe_avatar.dart';
import '../profile/user_profile_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final CardSwiperController _swiperController = CardSwiperController();

  List<dynamic> _profiles = [];
  bool _isLoading = true;
  String _selectedGender = "everyone"; // "everyone", "male" (Boys), "female" (Girls)
  String? _selectedInterest;
  String? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadGenderPreference();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadGenderPreference() async {
    final saved = await _storage.read(key: 'discover_gender_filter');
    if (saved != null && saved.isNotEmpty) {
      _selectedGender = saved;
    }
    _fetchProfiles();
  }

  Future<void> _setGenderFilter(String gender) async {
    if (_selectedGender == gender) return;
    setState(() {
      _selectedGender = gender;
    });
    await _storage.write(key: 'discover_gender_filter', value: gender);
    _fetchProfiles();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      String query = "/discovery/swipe-discovery?gender=$_selectedGender&";
      if (_selectedInterest != null && _selectedInterest!.isNotEmpty) {
        query += "interest=$_selectedInterest&";
      }
      if (_selectedCountry != null && _selectedCountry!.isNotEmpty) {
        query += "country=$_selectedCountry&";
      }

      final response = await _apiService.get(query);
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _profiles = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    if (previousIndex < 0 || previousIndex >= _profiles.length) return true;

    final profile = _profiles[previousIndex];
    final String targetUsername = profile['username'];

    String action = "pass";
    if (direction == CardSwiperDirection.right || direction == CardSwiperDirection.top) {
      action = "like";
    }

    _handleSwipeAction(targetUsername, action);

    if (_profiles.length - (currentIndex ?? 0) < 3) {
      _fetchProfiles();
    }

    return true;
  }

  Future<void> _handleSwipeAction(String targetUsername, String action) async {
    try {
      final response = await _apiService.post('/swipe', {
        "target_user_id": targetUsername,
        "action": action,
      });

      if (response.statusCode == 200 && mounted) {
        final result = jsonDecode(response.body);
        final String message = result["message"] ?? (action == "pass" ? "Skipped" : "Follow Request Sent");
        final String status = result["status"] ?? "";

        if (action != "pass") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    status == "following" ? Icons.check_circle_rounded : Icons.mark_email_read_rounded,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF1A1A2E),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Swipe error: $e");
    }
  }

  Future<void> _undoLastSwipe() async {
    try {
      final res = await _apiService.post('/swipe/undo', {});
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Undid last swipe")),
        );
        _fetchProfiles();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No previous swipe to undo")),
        );
      }
    } catch (_) {}
  }

  Future<void> _resetDiscovery() async {
    try {
      final res = await _apiService.post('/discovery/reset-swipes', {});
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Discovery history reset!")),
        );
        _fetchProfiles();
      }
    } catch (_) {}
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Discovery Filters", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: "Filter by Interest (e.g. Gaming, Music)"),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => _selectedInterest = val.trim(),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: "Filter by Country / Location"),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => _selectedCountry = val.trim(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedInterest = null;
                        _selectedCountry = null;
                      });
                      Navigator.pop(context);
                      _fetchProfiles();
                    },
                    child: const Text("Reset Filters", style: TextStyle(color: Colors.white54)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchProfiles();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
                    child: const Text("Apply Filters"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(username: username)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("ZENVORA DISCOVER", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: "Filters",
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: "Reset History",
            onPressed: _resetDiscovery,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Gender Filter Bar: Show Me: [ Everyone ] [ Boys ] [ Girls ]
            _buildShowMeGenderBar(),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_rounded, color: Color(0xFF6C63FF), size: 14),
                  SizedBox(width: 6),
                  Text(
                    "SWIPE RIGHT = SEND FOLLOW REQUEST",
                    style: TextStyle(color: Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                  : _profiles.isEmpty
                      ? _buildEmptyState()
                      : CardSwiper(
                          controller: _swiperController,
                          cardsCount: _profiles.length,
                          numberOfCardsDisplayed: _profiles.length >= 3 ? 3 : _profiles.length,
                          onSwipe: _onSwipe,
                          backCardOffset: const Offset(0, 35),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          cardBuilder: (context, index, horizontalThreshold, verticalThreshold) {
                            return _DiscoveryProfileCard(
                              profile: _profiles[index],
                              onViewProfile: () => _openProfile(_profiles[index]['username']),
                            );
                          },
                        ),
            ),
            if (!_isLoading && _profiles.isNotEmpty) _buildSwipeControls(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildShowMeGenderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF161626),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Show Me: ",
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          _buildGenderChip("Everyone", "everyone"),
          const SizedBox(width: 8),
          _buildGenderChip("Boys", "male"),
          const SizedBox(width: 8),
          _buildGenderChip("Girls", "female"),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, String value) {
    final bool isSelected = _selectedGender == value;

    return GestureDetector(
      onTap: () => _setGenderFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radar_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 16),
          const Text("No profiles match your Discovery filter right now", style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _resetDiscovery,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("RESET DISCOVERY HISTORY"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleBtn(Icons.undo_rounded, Colors.amberAccent, _undoLastSwipe, isSmall: true),
          _buildCircleBtn(Icons.close_rounded, Colors.redAccent, () {
            _swiperController.swipe(CardSwiperDirection.left);
          }),
          _buildCircleBtn(Icons.favorite_rounded, Colors.greenAccent, () {
            _swiperController.swipe(CardSwiperDirection.right);
          }),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, Color color, VoidCallback onTap, {bool isSmall = false}) {
    return Container(
      width: isSmall ? 52 : 64,
      height: isSmall ? 52 : 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: isSmall ? 22 : 30),
        onPressed: onTap,
      ),
    );
  }
}

class _DiscoveryProfileCard extends StatelessWidget {
  final dynamic profile;
  final VoidCallback onViewProfile;

  const _DiscoveryProfileCard({
    required this.profile,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final String username = profile['username'] ?? 'User';
    final String displayName = profile['display_name'] ?? username;
    final String? photoUrl = profile['profile_photo_url'] ?? profile['avatar_url'];
    final String bio = profile['bio'] ?? '';
    final String country = profile['country'] ?? 'Global';
    final int? age = profile['age'];
    final List interests = profile['interests'] as List? ?? [];
    final bool isPrivate = profile['is_private'] == true;
    final int matchScore = profile['compatibility_score'] ?? 85;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Top Image / Avatar Stack
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SafeAvatar(
                    avatarUrl: photoUrl,
                    username: username,
                    radius: 120,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, const Color(0xFF1A1A2E).withOpacity(0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        "$matchScore% Match",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  if (isPrivate)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 12),
                            SizedBox(width: 4),
                            Text("Private Account", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Body Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (age != null)
                          Text(
                            "$age",
                            style: const TextStyle(fontSize: 22, color: Colors.white70, fontWeight: FontWeight.w300),
                          ),
                      ],
                    ),
                    Text(
                      "@$username • $country",
                      style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio.isNotEmpty ? bio : "Exploring Zenvora ✨",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                    const Spacer(),
                    if (interests.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: interests.take(4).map((i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                            child: Text(i.toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onViewProfile,
                      icon: const Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      label: const Text("VIEW FULL PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
