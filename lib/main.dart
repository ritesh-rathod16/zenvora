import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zenvora/core/theme/app_theme.dart';
import 'package:zenvora/features/splash/splash_screen.dart';
import 'package:zenvora/features/auth/login/login_screen.dart';
import 'package:zenvora/features/auth/register/register_screen.dart';
import 'package:zenvora/features/auth/verification/otp_screen.dart';
import 'package:zenvora/features/home/home_screen.dart';
import 'package:zenvora/features/random_chat/matchmaking_screen.dart';
import 'package:zenvora/features/random_chat/video_chat_screen.dart';
import 'package:zenvora/features/admin/admin_dashboard_screen.dart';
import 'package:zenvora/features/admin/admin_users_screen.dart';
import 'package:zenvora/features/admin/admin_reports_screen.dart';
import 'package:zenvora/features/admin/admin_posts_screen.dart';
import 'package:zenvora/features/admin/admin_broadcast_screen.dart';
import 'package:zenvora/features/admin/admin_settings_screen.dart';
import 'package:zenvora/features/admin/admin_analytics_screen.dart';
import 'package:zenvora/features/admin/admin_chats_screen.dart';
import 'package:zenvora/features/rooms/voice_rooms_screen.dart';
import 'package:zenvora/features/stories/providers/story_camera_provider.dart';
import 'package:zenvora/features/stories/screens/story_camera_screen.dart';
import 'package:zenvora/services/socket_service.dart';
import 'package:zenvora/services/voice_service.dart';
import 'package:zenvora/core/providers/social_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => StoryCameraProvider()),
      ],
      child: const ZenvoraApp(),
    ),
  );

  // Initialize background services and permissions after the first frame renders
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initBackgroundServices();
  });
}

void _initBackgroundServices() {
  [
    Permission.camera,
    Permission.microphone,
  ].request().ignore();
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/verify-otp', builder: (context, state) => OtpScreen(email: state.extra as String)),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/matchmaking', builder: (context, state) => const MatchmakingScreen()),
    GoRoute(path: '/video-chat', builder: (context, state) => const VideoChatScreen()),
    GoRoute(path: '/rooms', builder: (context, state) => const VoiceRoomsScreen()),
    GoRoute(path: '/stories/camera', builder: (context, state) => const StoryCameraScreen()),
    
    // Admin Routes
    GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
    GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersScreen()),
    GoRoute(path: '/admin/reports', builder: (context, state) => const AdminReportsScreen()),
    GoRoute(path: '/admin/posts', builder: (context, state) => const AdminPostsScreen()),
    GoRoute(path: '/admin/broadcast', builder: (context, state) => const AdminBroadcastScreen()),
    GoRoute(path: '/admin/settings', builder: (context, state) => const AdminSettingsScreen()),
    GoRoute(path: '/admin/analytics', builder: (context, state) => const AdminAnalyticsScreen()),
    GoRoute(path: '/admin/chats', builder: (context, state) => const AdminChatsScreen()),
  ],
);

class ZenvoraApp extends StatelessWidget {
  const ZenvoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zenvora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
