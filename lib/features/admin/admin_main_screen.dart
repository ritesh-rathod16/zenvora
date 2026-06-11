import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_posts_screen.dart';
import 'admin_chats_screen.dart';
import 'admin_voice_rooms_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  bool _isAuthorized = false;
  bool _checkingAuth = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      if (user['email'] == 'zenvora@gmail.com' && (user['role'] == 'super_admin' || user['is_admin'] == true)) {
        setState(() {
          _isAuthorized = true;
          _checkingAuth = false;
        });
      } else {
        if (mounted) context.go('/home');
      }
    } else {
      if (mounted) context.go('/login');
    }
  }

  final List<Widget> _pages = [
    const AdminDashboardScreen(),
    const AdminUsersScreen(),
    const AdminBroadcastScreen(),
    const AdminAnalyticsScreen(),
    const AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    "DASHBOARD",
    "USER MANAGEMENT",
    "BROADCAST CENTER",
    "PLATFORM ANALYTICS",
    "SYSTEM SETTINGS"
  ];

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    if (!_isAuthorized) return const SizedBox.shrink();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        toolbarHeight: 80,
        centerTitle: true,
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          children: [
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            Container(
              height: 2,
              width: 40,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          ],
        ),
      ),
      drawer: _buildAdminDrawer(context),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF1A1A2E),
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: Colors.white24,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: "DASHBOARD",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_outlined),
              activeIcon: Icon(Icons.people_alt_rounded),
              label: "USERS",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              activeIcon: Icon(Icons.campaign_rounded),
              label: "BROADCAST",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics_rounded),
              label: "ANALYTICS",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: "SETTINGS",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F1A),
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _buildDrawerSectionTitle("MODERATION"),
                _buildDrawerItem(
                  Icons.flag_rounded, 
                  "Reports Queue", 
                  Colors.redAccent, 
                  () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsScreen()));
                  }
                ),
                _buildDrawerItem(
                  Icons.forum_rounded, 
                  "Flagged Chats", 
                  Colors.orangeAccent, 
                  () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminChatsScreen()));
                  }
                ),
                _buildDrawerItem(
                  Icons.mic_rounded, 
                  "Live Voice Rooms", 
                  const Color(0xFF00F2FE), 
                  () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVoiceRoomsScreen()));
                  }
                ),
                const SizedBox(height: 24),
                _buildDrawerSectionTitle("CONTENT"),
                _buildDrawerItem(
                  Icons.article_rounded, 
                  "Global Posts", 
                  Colors.blueAccent, 
                  () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPostsScreen()));
                  }
                ),
                const SizedBox(height: 24),
                _buildDrawerSectionTitle("SECURITY"),
                _buildDrawerItem(Icons.history_edu_rounded, "System Logs", Colors.tealAccent, () {}),
                _buildDrawerItem(Icons.security_rounded, "Access Control", Colors.greenAccent, () {}),
              ],
            ),
          ),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF6C63FF), size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            "ZENVORA",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const Text(
            "ADMINISTRATOR HUB",
            style: TextStyle(fontSize: 10, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.2), fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white10, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ElevatedButton.icon(
        onPressed: () async {
          const storage = FlutterSecureStorage();
          await storage.delete(key: 'token');
          await storage.delete(key: 'user');
          if (mounted) context.go('/login');
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text("EXIT TERMINAL"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          foregroundColor: Colors.redAccent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
          elevation: 0,
        ),
      ),
    );
  }
}
