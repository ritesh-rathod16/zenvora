import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';
import 'admin_voice_rooms_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isAuthorized = false;
  Map<String, dynamic>? _stats;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  Future<void> _checkAuthorization() async {
    const storage = FlutterSecureStorage();
    final userJson = await storage.read(key: 'user');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      if (user['email'] == 'zenvora@gmail.com' && (user['role'] == 'super_admin' || user['is_admin'] == true)) {
        setState(() => _isAuthorized = true);
        _fetchStats();
      } else {
        if (mounted) context.go('/home');
      }
    } else {
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/stats');
      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
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
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF050505), body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))));

    final metrics = _stats?['metrics'] ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          Positioned(top: -100, right: -100, child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.1))),
          Positioned(bottom: -50, left: -50, child: _buildGlow(const Color(0xFF00F2FE).withOpacity(0.05))),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(),
              _buildLiveTelemetry(),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildStatCard("ACTIVE USERS", metrics['active_users']?.toString() ?? "0", Icons.bolt_rounded, const Color(0xFF6C63FF)),
                    _buildStatCard("LIVE ROOMS", metrics['active_rooms']?.toString() ?? "0", Icons.mic_rounded, const Color(0xFF00F2FE), onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminVoiceRoomsScreen()));
                    }),
                    _buildStatCard("REPORTS", metrics['pending_reports']?.toString() ?? "0", Icons.warning_rounded, Colors.redAccent),
                    _buildStatCard("SFU LOAD", "14%", Icons.speed_rounded, Colors.greenAccent),
                  ]),
                ),
              ),
              _buildSection("VOICE TRAFFIC (Kbps)"),
              _buildActivityChart(),
              _buildSection("SYSTEM CONTROL PANEL"),
              _buildSystemStatus(),
              _buildSection("REAL-TIME SERVER CLUSTERS"),
              _buildServerClusters(),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("ZENVORA TERMINAL", style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 4)),
             const SizedBox(height: 5),
             Text("COMMAND CENTER", style: GoogleFonts.poppins(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTelemetry() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent.withOpacity(0.3 + (_pulseController.value * 0.7)),
                    boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5 * _pulseController.value), blurRadius: 10)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("LIVE TELEMETRY STREAMING", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("V1.6.2-PROD", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                const Icon(Icons.arrow_outward_rounded, color: Colors.white24, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.orbitron(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
        child: Row(
          children: [
            Container(width: 4, height: 12, decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.orbitron(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [const FlSpot(0, 2), const FlSpot(2, 5), const FlSpot(4, 3.5), const FlSpot(6, 7), const FlSpot(8, 4), const FlSpot(10, 6)],
                isCurved: true,
                color: const Color(0xFF6C63FF),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(colors: [const Color(0xFF6C63FF).withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Column(
            children: [
              _buildSystemRow("REDIS CACHE", "OPTIMAL", Colors.greenAccent),
              const Divider(color: Colors.white10, height: 30),
              _buildSystemRow("SFU INSTANCES", "4 ACTIVE", Colors.blueAccent),
              const Divider(color: Colors.white10, height: 30),
              _buildSystemRow("MATCHMAKER", "LOW LATENCY", Colors.greenAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemRow(String label, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: GoogleFonts.robotoMono(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildServerClusters() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_rounded, color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("us-east-1a-sfu-${index + 1}", style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
                      Text("Load: ${10 + index * 5}% • CPU: 0.${index + 1}s", style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ),
                const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
              ],
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }
}
