import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:zenvora/services/socket_service.dart';
import 'package:zenvora/services/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://wtqoyndapmzwgoghruab.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0cW95bmRhcG16d2dvZ2hydWFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5NTkwOTMsImV4cCI6MjA4ODUzNTA5M30.QOV6C3XVFywoX43l3se97zrhK5owP_XgLJOhtU8AQCI',
  );

  // Request Permissions
  await _requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SocketService()..initSocket()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
      ],
      child: const ZenvoraApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.microphone,
    Permission.storage,
  ].request();
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
