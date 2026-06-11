import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../posts/feed_screen.dart';
import '../discover/discovery_screen.dart';
import '../search/search_people_screen.dart';
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
  bool? _isAdmin;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkRole();
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
          });
        }
      } else {
        if (mounted) setState(() => _isAdmin = false);
      }
    } catch (e) {
      debugPrint("Check Role Error: $e");
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  final List<Widget> _pages = [
    const FeedScreen(),
    const DiscoveryScreen(),
    const SearchPeopleScreen(),
    const NotificationsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isAdmin == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    if (_isAdmin!) {
      return const AdminMainScreen();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text("ZENVORA", style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFF6C63FF)),
            onPressed: () => context.push('/matchmaking'),
          ),
          IconButton(
            icon: const Icon(Icons.message_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatInboxScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
      ),
      drawer: _buildUserDrawer(context),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white30,
        showSelectedLabels: true,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: "Discover"),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: "Activity"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildUserDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F1A),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF6C63FF)),
            child: Center(
              child: Text("ZENVORA", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mic_rounded, color: Colors.white70),
            title: const Text("Voice Rooms", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceRoomsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: Colors.white70),
            title: const Text("Blocked Users", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white70),
            title: const Text("Settings", style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              const storage = FlutterSecureStorage();
              await storage.deleteAll();
              if (!mounted) return;
              context.go('/login');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
