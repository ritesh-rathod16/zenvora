import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../posts/feed_screen.dart';
import '../discover/discovery_screen.dart';
import '../search/search_people_screen.dart';
import '../reels/reels_feed_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_inbox_screen.dart';
import '../notifications/notifications_screen.dart';
import '../rooms/voice_rooms_screen.dart';
import '../admin/admin_main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _checkRole();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    try {
      const storage = FlutterSecureStorage();
      final userJson = await storage.read(key: 'user');
      if (userJson != null) {
        final Map<String, dynamic> user = jsonDecode(userJson);
        final role = user['role']?.toString().toLowerCase() ?? "user";
        if (mounted) {
          setState(() {
            _isAdmin = (role == 'admin' || role == 'super_admin' || user['is_admin'] == true);
            _isLoadingRole = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      debugPrint("Check Role Error: $e");
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  final List<Widget> _pages = [
    const FeedScreen(),           // 0: Home (Feed + Stories)
    const DiscoveryScreen(),      // 1: Discover (Tinder-style Discover People)
    const SearchPeopleScreen(),   // 2: Search (Search Bar + Instagram Explore Grid)
    const ReelsFeedScreen(),      // 3: Reels (Instagram-style Reels)
    const NotificationsScreen(),  // 4: Activity (Likes, Follow Requests, Notifications)
    const ProfileScreen(),        // 5: Profile (User Profile & Stats)
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      // ZENVORA Header appears ONLY on Home page (_selectedIndex == 0)
      appBar: _selectedIndex == 0
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.mic_rounded, color: Color(0xFF6C63FF)),
                tooltip: "Voice Rooms",
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceRoomsScreen()));
                },
              ),
              title: const Text("ZENVORA", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amberAccent),
                    tooltip: "Admin Console",
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminMainScreen()));
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.videocam_rounded, color: Color(0xFF00F0FF)),
                  tooltip: "Omegle Video Chat",
                  onPressed: () => context.push('/matchmaking'),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  tooltip: "Direct Messages",
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatInboxScreen()));
                  },
                ),
                const SizedBox(width: 8),
              ],
              backgroundColor: const Color(0xFF1A1A2E),
              elevation: 0,
            )
          : null,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        physics: _selectedIndex == 1
            ? const NeverScrollableScrollPhysics() // Disable tab swipe on Discover screen to allow Tinder card swiping
            : const BouncingScrollPhysics(),
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white30,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: "Discover"),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.video_collection_rounded), activeIcon: Icon(Icons.video_collection), label: "Reels"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: "Activity"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
