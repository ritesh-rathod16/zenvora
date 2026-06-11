import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/socket_service.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  @override
  void initState() {
    super.initState();
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    socketService.onMatchFound = () {
      if (mounted) {
        context.push('/video-chat');
      }
    };

    // Start searching automatically when entering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socketService.joinQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text("Finding Someone..."),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            socketService.leaveQueue();
            context.pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                Icon(Icons.person_search, size: 80, color: Colors.white24),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              "Searching for a random stranger...",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "Keep it friendly and anonymous!",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 64),
            ElevatedButton(
              onPressed: () {
                socketService.leaveQueue();
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              child: const Text("CANCEL SEARCH"),
            ),
          ],
        ),
      ),
    );
  }
}
