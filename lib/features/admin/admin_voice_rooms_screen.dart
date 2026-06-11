import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import '../rooms/voice_room_screen.dart';

class AdminVoiceRoomsScreen extends StatefulWidget {
  const AdminVoiceRoomsScreen({super.key});

  @override
  State<AdminVoiceRoomsScreen> createState() => _AdminVoiceRoomsScreenState();
}

class _AdminVoiceRoomsScreenState extends State<AdminVoiceRoomsScreen> {
  final _apiService = ApiService();
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  bool _isAuthorized = false;

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
        _fetchRooms();
      } else {
        if (mounted) context.go('/home');
      }
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/rooms');
      if (response.statusCode == 200) {
        setState(() {
          _rooms = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
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
          Positioned(top: -100, right: -100, child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.05))),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                    : RefreshIndicator(
                        onRefresh: _fetchRooms,
                        color: const Color(0xFF6C63FF),
                        child: _rooms.isEmpty 
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: _rooms.length,
                              itemBuilder: (context, index) => _AdminRoomCard(
                                room: _rooms[index],
                                onUpdate: _fetchRooms,
                              ),
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
      width: 400, height: 400,
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 15),
              Text("AUDIO INFRASTRUCTURE", style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 4)),
            ],
          ),
          const SizedBox(height: 10),
          Text("LIVE VOICE ROOMS", style: GoogleFonts.poppins(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
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
            const Icon(Icons.mic_off_rounded, size: 64, color: Colors.white12),
            const SizedBox(height: 20),
            Text("QUIET ON SET", style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2)),
            Text("No active voice rooms currently", style: GoogleFonts.poppins(color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}

class _AdminRoomCard extends StatelessWidget {
  final dynamic room;
  final VoidCallback onUpdate;
  const _AdminRoomCard({required this.room, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final listeners = room['listener_count'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(room['category']?.toString().toUpperCase() ?? "GENERAL", style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                   const Icon(Icons.people_alt_rounded, color: Colors.white24, size: 14),
                   const SizedBox(width: 5),
                   Text("$listeners", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(room['title'] ?? "Untitled Room", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("CREATOR: @${room['creator_id']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton("SURVEILLANCE", Colors.greenAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: room)));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton("TERMINATE", Colors.redAccent, () => _handleTerminate(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.orbitron(fontSize: 10, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  void _handleTerminate(BuildContext context) async {
     final api = ApiService();
     await api.post('/admin/rooms/${room['id']}/end', {});
     onUpdate();
  }
}
