import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _apiService = ApiService();
  List<dynamic> _reports = [];
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
        _fetchReports();
      } else {
        if (mounted) context.go('/home');
      }
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.get('/admin/reports');
      if (response.statusCode == 200) {
        setState(() {
          _reports = jsonDecode(response.body);
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
          Positioned(top: -100, right: -100, child: _buildGlow(Colors.redAccent.withOpacity(0.05))),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                    : RefreshIndicator(
                        onRefresh: _fetchReports,
                        color: const Color(0xFF6C63FF),
                        backgroundColor: const Color(0xFF1A1A2E),
                        child: _reports.isEmpty 
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) => _ReportCard(
                                report: _reports[index], 
                                onUpdate: _fetchReports,
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
              Text("MODERATION TERMINAL", style: GoogleFonts.orbitron(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ],
          ),
          const SizedBox(height: 10),
          Text("REPORT QUEUE", style: GoogleFonts.poppins(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
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
            const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.greenAccent),
            const SizedBox(height: 20),
            Text("CLEAN RECORD", style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2)),
            Text("No pending violations detected", style: GoogleFonts.poppins(color: Colors.white24)),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final dynamic report;
  final VoidCallback onUpdate;
  const _ReportCard({required this.report, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final severity = (report['severity'] ?? 'LOW').toString().toUpperCase();
    final severityColor = severity == 'CRITICAL' ? Colors.redAccent : severity == 'HIGH' ? Colors.orangeAccent : Colors.blueAccent;
    final isAiFlagged = report['is_ai_flagged'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: severityColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: severityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(severity, style: GoogleFonts.robotoMono(fontSize: 10, color: severityColor, fontWeight: FontWeight.bold)),
                  ),
                  if (isAiFlagged)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 10),
                            const SizedBox(width: 4),
                            Text("AI DETECTED", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Text(report['timestamp'] ?? "Now", style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 15),
          Text("TARGET: @${report['reported_id']}", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("REPORTER: @${report['reporter_id']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['reason'] ?? "Inappropriate behavior",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                ),
                if (isAiFlagged) ...[
                   const SizedBox(height: 10),
                   const Divider(color: Colors.white10),
                   Text("AI ANALYSIS: High probability of harassment (0.92)", style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.purpleAccent.withOpacity(0.7))),
                ]
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildButton("DISMISS", Colors.white24, () => _handleAction('dismiss')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildButton("STRIKE", Colors.redAccent, () => _handleAction('strike')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onTap) {
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

  void _handleAction(String action) async {
    final api = ApiService();
    await api.post('/admin/reports/${report['id']}/resolve', {'action': action});
    onUpdate();
  }
}
