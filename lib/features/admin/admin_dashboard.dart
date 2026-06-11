import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100, right: -100,
            child: _buildGlow(const Color(0xFF6C63FF).withOpacity(0.15)),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: _buildGlow(const Color(0xFF00F2FE).withOpacity(0.1)),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStatGrid(),
                        const SizedBox(height: 25),
                        _buildLiveTrafficChart(),
                        const SizedBox(height: 25),
                        _buildSectionHeader("ACTIVE ROOMS", Icons.record_voice_over_rounded),
                        const SizedBox(height: 15),
                        _buildActiveRoomsList(),
                        const SizedBox(height: 25),
                        _buildSectionHeader("USER MODERATION", Icons.security_rounded),
                        const SizedBox(height: 15),
                        _buildModerationQueue(),
                      ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ZENVORA", style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w900, letterSpacing: 4)),
              Text("COMMAND CENTER", style: GoogleFonts.poppins(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.red),
                const SizedBox(width: 8),
                Text("LIVE MONITOR", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard("ACTIVE USERS", "1,284", Icons.people_rounded, const Color(0xFF6C63FF)),
        _buildStatCard("LIVE ROOMS", "42", Icons.mic_rounded, const Color(0xFF00F2FE)),
        _buildStatCard("REPORTS", "08", Icons.warning_rounded, Colors.orange),
        _buildStatCard("SFU LOAD", "14%", Icons.speed_rounded, Colors.greenAccent),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
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
              Text("+12%", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.greenAccent)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.orbitron(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrafficChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("VOICE TRAFFIC (Kbps)", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 3), const FlSpot(2, 4), const FlSpot(4, 3.5), const FlSpot(6, 5),
                      const FlSpot(8, 4), const FlSpot(10, 6), const FlSpot(12, 5),
                    ],
                    isCurved: true,
                    color: const Color(0xFF6C63FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(colors: [const Color(0xFF6C63FF).withOpacity(0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildActiveRoomsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.waves_rounded, color: Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Late Night Vibing", style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                    Text("8 Speakers • 124 Listeners", style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModerationQueue() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.report_problem_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text("3 NEW TOXICITY ALERTS", style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {},
            child: Text("VIEW", style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
