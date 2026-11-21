import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/socket_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Initialize socket and check auth after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<SocketService>(context, listen: false).initSocket();
      } catch (_) {}
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    if (_isNavigating || !mounted) return;

    String? token;

    try {
      token = await _storage.read(key: 'token');
    } catch (e) {
      debugPrint('Secure storage read failed: $e');
      token = null;
    }

    if (!mounted || _isNavigating) return;

    _isNavigating = true;

    if (token != null && token.trim().isNotEmpty) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6C63FF),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.blur_on_rounded,
                  size: 64,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ZENVORA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stay Anonymous. Stay Connected.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
