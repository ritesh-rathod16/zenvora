import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../rooms/voice_room_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isAuthorized = false;
  String _searchQuery = "";

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
        setState(() => _isAuthorized = true);
        _fetchUsers();
      } else {
        if (mounted) context.go('/home');
      }
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/users?q=$_searchQuery');
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Positioned(top: -50, left: -50, child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.08))),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                    : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        color: const Color(0xFF6C63FF),
                        child: _users.isEmpty 
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: _users.length,
                              itemBuilder: (context, index) => _AdminUserCard(user: _users[index], onUpdate: _fetchUsers),
                            ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color) {
    return Container(
      width: 300, height: 300,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 15),
              ],
              Text("IDENTITY DATABASE", style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 4)),
            ],
          ),
          const SizedBox(height: 10),
          Text("USER MANAGEMENT", style: GoogleFonts.poppins(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: TextField(
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          onChanged: (v) {
            _searchQuery = v;
            _fetchUsers();
          },
          decoration: InputDecoration(
            hintText: "Search by ID, Alias or Email...",
            hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_rounded, size: 64, color: Colors.white12),
            const SizedBox(height: 20),
            Text("NO MATCHES", style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2)),
            Text("No users found with those credentials", style: GoogleFonts.poppins(color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}

class _AdminUserCard extends StatefulWidget {
  final dynamic user;
  final VoidCallback onUpdate;
  const _AdminUserCard({required this.user, required this.onUpdate});

  @override
  State<_AdminUserCard> createState() => _AdminUserCardState();
}

class _AdminUserCardState extends State<_AdminUserCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isBanned = user['is_banned'] ?? false;
    final currentRoom = user['current_room_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isBanned ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.network(
                    user['avatar_url'] ?? "https://api.dicebear.com/7.x/bottts-neutral/svg?seed=${user['anonymous_username']}",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _revealed ? (user['real_name'] ?? user['email'] ?? "Unknown") : "REDACTED IDENTITY",
                      style: GoogleFonts.robotoMono(
                        fontSize: 14, 
                        color: _revealed ? Colors.white : const Color(0xFF6C63FF),
                        fontWeight: FontWeight.bold,
                        letterSpacing: _revealed ? 0 : 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "@${user['anonymous_username']}",
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              if (currentRoom != null)
                IconButton(
                  icon: const Icon(Icons.remove_red_eye_rounded, color: Colors.greenAccent, size: 20),
                  tooltip: "Invisible Join",
                  onPressed: () => _invisibleJoin(currentRoom),
                ),
              IconButton(
                icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white24, size: 20),
                onPressed: () => setState(() => _revealed = !_revealed),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric("TRUST", "${user['trust_score'] ?? 0}%", user['trust_score'] > 70 ? Colors.greenAccent : Colors.orangeAccent),
              _buildMetric("TOXICITY", user['toxicity_score'] != null ? "${(user['toxicity_score'] * 100).toInt()}%" : "0%", Colors.white38),
              Row(
                children: [
                  _buildActionButton(Icons.history_rounded, Colors.blueAccent, () => _showHistory(user)),
                  const SizedBox(width: 10),
                  _buildActionButton(
                    isBanned ? Icons.refresh_rounded : Icons.block_flipped, 
                    isBanned ? Colors.greenAccent : Colors.redAccent,
                    _toggleBan,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _invisibleJoin(String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: {'_id': roomId, 'title': 'Surveillance Mode'})),
    );
  }

  void _showHistory(dynamic user) {
     showModalBottomSheet(
       context: context,
       backgroundColor: const Color(0xFF0F0F1A),
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
       builder: (context) => Container(
         padding: const EdgeInsets.all(25),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text("SESSION HISTORY", style: GoogleFonts.orbitron(fontSize: 12, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 2)),
             const SizedBox(height: 20),
             Expanded(
               child: ListView.builder(
                 itemCount: 5,
                 itemBuilder: (context, index) => ListTile(
                   title: Text("Joined Room #842", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                   subtitle: Text("Duration: 24m • 2 reactions sent", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                   trailing: Text("2d ago", style: GoogleFonts.robotoMono(color: Colors.white24, fontSize: 10)),
                 ),
               ),
             ),
           ],
         ),
       ),
     );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.robotoMono(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Future<void> _toggleBan() async {
    final api = ApiService();
    final isBanned = widget.user['is_banned'] ?? false;
    final endpoint = isBanned ? '/admin/users/${widget.user['id']}/unban' : '/admin/users/${widget.user['id']}/ban';
    
    await api.post(endpoint, {'reason': 'System Enforcement'});
    widget.onUpdate();
  }
}
