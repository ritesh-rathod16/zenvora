import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/api_service.dart';

class GhostSettingsScreen extends StatefulWidget {
  const GhostSettingsScreen({super.key});

  @override
  State<GhostSettingsScreen> createState() => _GhostSettingsScreenState();
}

class _GhostSettingsScreenState extends State<GhostSettingsScreen> {
  bool _ghostMode = false;
  bool _invisibleListening = false;
  bool _voiceMasking = false;
  String _currentAura = "Cyber Purple";
  String _currentMood = "neutral";

  final List<String> _auras = ["Cyber Purple", "Ghost Blue", "Neon Pink", "Void Black", "Dreamcore"];
  final List<Map<String, dynamic>> _moods = [
    {"id": "lonely", "icon": "🌙", "label": "Lonely"},
    {"id": "anxious", "icon": "🌊", "label": "Anxious"},
    {"id": "chaotic", "icon": "🔥", "label": "Chaotic"},
    {"id": "comfort", "icon": "☁️", "label": "Comfort"},
    {"id": "sleepy", "icon": "💤", "label": "Sleepy"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(top: -100, right: -50, child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.1))),
          
          SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionHeader("GHOST PRIVACY CENTER", Icons.security_rounded),
                      const SizedBox(height: 20),
                      _buildGhostToggle("Ghost Mode", "Enables complete public anonymity.", _ghostMode, (v) => setState(() => _ghostMode = v)),
                      _buildGhostToggle("Invisible Listening", "Join rooms without appearing in the participant list.", _invisibleListening, (v) => setState(() => _invisibleListening = v)),
                      _buildGhostToggle("Voice Masking", "AI-powered voice frequency modulation.", _voiceMasking, (v) => setState(() => _voiceMasking = v)),
                      
                      const SizedBox(height: 40),
                      _buildSectionHeader("EMOTIONAL STATE", Icons.auto_awesome_rounded),
                      const SizedBox(height: 20),
                      _buildMoodSelector(),
                      
                      const SizedBox(height: 40),
                      _buildSectionHeader("VOICE AURA CUSTOMIZATION", Icons.waves_rounded),
                      const SizedBox(height: 20),
                      _buildAuraPicker(),
                      
                      const SizedBox(height: 60),
                      _buildPanicButton(),
                      const SizedBox(height: 100),
                    ]),
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 120,
      floating: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
        title: Text(
          "TERMINAL SETTINGS",
          style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildGhostToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.poppins(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6C63FF),
            activeTrackColor: const Color(0xFF6C63FF).withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _moods.length,
        itemBuilder: (context, index) {
          final mood = _moods[index];
          final isSelected = _currentMood == mood['id'];
          return GestureDetector(
            onTap: () => setState(() => _currentMood = mood['id']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(mood['icon'], style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text(mood['label'], style: GoogleFonts.poppins(fontSize: 10, color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuraPicker() {
    return Column(
      children: _auras.map((aura) {
        final isSelected = _currentAura == aura;
        return GestureDetector(
          onTap: () => setState(() => _currentAura = aura),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6C63FF).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAuraColor(aura),
                    boxShadow: [BoxShadow(color: _getAuraColor(aura).withOpacity(0.5), blurRadius: 10)],
                  ),
                ),
                const SizedBox(width: 15),
                Text(aura, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF6C63FF), size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getAuraColor(String aura) {
    switch (aura) {
      case "Ghost Blue": return const Color(0xFF00F2FE);
      case "Neon Pink": return const Color(0xFFFF00E0);
      case "Void Black": return Colors.grey.shade900;
      case "Dreamcore": return Colors.tealAccent;
      default: return const Color(0xFF6C63FF);
    }
  }

  Widget _buildPanicButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Text("PANIC DISCONNECT", style: GoogleFonts.orbitron(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
