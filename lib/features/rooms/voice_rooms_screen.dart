import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/services/api_service.dart';
import './voice_room_screen.dart';

class VoiceRoomsScreen extends StatefulWidget {
  const VoiceRoomsScreen({super.key});

  @override
  State<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends State<VoiceRoomsScreen> {
  final _apiService = ApiService();
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _selectedCategory = "All";
  final List<String> _categories = ["All", "General", "Gaming", "Music", "Tech", "Support", "Night Owls"];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    try {
      final response = await _apiService.get('/rooms/');
      if (response.statusCode == 200) {
        setState(() {
          _rooms = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToRoom(Map<String, dynamic> room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VoiceRoomScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: -100, left: -50,
            child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.12)),
          ),
          Positioned(
            bottom: 50, right: -50,
            child: _buildGlow(const Color(0xFF00F2FE).withOpacity(0.08)),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                _buildCategoryList(),
                _buildRoomsGrid(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCreateButton(),
    );
  }

  Widget _buildGlow(Color color) {
    return Container(
      width: 350, height: 350,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("DISCOVER", style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 3)),
                Text("VOICE ROOMS", style: GoogleFonts.poppins(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Icon(Icons.search_rounded, color: Colors.white70, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                  boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.robotoMono(fontSize: 10, color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoomsGrid() {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8),
          delegate: SliverChildBuilderDelegate((context, index) => _buildShimmerCard(), childCount: 6),
        ),
      );
    }

    final filteredRooms = _selectedCategory == "All" 
      ? _rooms 
      : _rooms.where((r) => r['category'] == _selectedCategory).toList();

    if (filteredRooms.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mic_none_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 15),
              Text("No rooms in this category", style: GoogleFonts.poppins(color: Colors.white24)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 25, childAspectRatio: 0.8),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _RoomCard(room: filteredRooms[index], onTap: () => _navigateToRoom(filteredRooms[index])),
          childCount: filteredRooms.length,
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A2E),
      highlightColor: const Color(0xFF252545),
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3F37C9)]),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent,
        elevation: 0,
        onPressed: _showCreateRoomSheet,
        label: Text("START A ROOM", style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        icon: const Icon(Icons.add_rounded, size: 24),
      ),
    );
  }

  void _showCreateRoomSheet() {
    // Implement refined Gen-Z room creation sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateRoomSheet(onCreated: _fetchRooms),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final participantsCount = (room['participants'] as List?)?.length ?? 0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Subtle gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF6C63FF).withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        (room['category'] ?? "General").toUpperCase(),
                        style: GoogleFonts.robotoMono(fontSize: 8, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      room['title'] ?? "Untitled Room",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildAvatars(participantsCount),
                        const SizedBox(width: 8),
                        Text(
                          "$participantsCount+",
                          style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Live Badge
              Positioned(
                top: 20, right: 20,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 6)]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatars(int count) {
    return SizedBox(
      width: 45,
      height: 20,
      child: Stack(
        children: List.generate(3, (index) {
          return Positioned(
            left: index * 12.0,
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1A1A2E), width: 2)),
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Colors.white12,
                backgroundImage: NetworkImage("https://api.dicebear.com/7.x/bottts-neutral/svg?seed=$index${room['_id']}"),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CreateRoomSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateRoomSheet({required this.onCreated});

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = "General";
  bool _isPublic = true;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 40, left: 30, right: 30, top: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A).withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 30),
            Text("LAUNCH NEW ROOM", style: GoogleFonts.orbitron(fontSize: 12, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Give it a catchy title...",
                hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 20, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionRow("Category", _category, Icons.category_rounded, () {
               // Show category picker
            }),
            _buildOptionRow("Visibility", _isPublic ? "Public" : "Private", Icons.visibility_rounded, () {
              setState(() => _isPublic = !_isPublic);
            }),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 10,
                  shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                ),
                child: Text("LAUNCH LIVE", style: GoogleFonts.orbitron(fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(String label, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 15),
            Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14)),
            const Spacer(),
            Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    if (_titleController.text.isEmpty) return;
    
    final api = ApiService();
    final response = await api.post('/rooms/create', {
      'title': _titleController.text,
      'description': _descController.text,
      'category': _category,
      'is_public': _isPublic,
    });

    if (response.statusCode == 200) {
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    }
  }
}
