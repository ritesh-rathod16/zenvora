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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
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
      // Ensure smooth branding visibility for at least 1.2 seconds
      await Future.delayed(const Duration(milliseconds: 1200));
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6C63FF),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.blur_on_rounded,
                      size: 72,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'ZENVORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Stay Anonymous. Stay Connected.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 64),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                      strokeWidth: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
