import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/video_view.dart';

class VideoChatScreen extends StatefulWidget {
  const VideoChatScreen({super.key});

  @override
  State<VideoChatScreen> createState() => _VideoChatScreenState();
}

class _VideoChatScreenState extends State<VideoChatScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  WebRTCService? _webrtcService;

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _startWebRTC();
  }

  Future<void> _startWebRTC() async {
    final socketService = Provider.of<SocketService>(context, listen: false);

    _webrtcService = WebRTCService(socketService: socketService);

    /// Local video stream
    _webrtcService!.onLocalStream = (stream) {
      if (!mounted) return;
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    /// Remote video stream
    _webrtcService!.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isLoading = false;
      });
    };

    /// Partner disconnect handler
    socketService.onPartnerDisconnected = () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Partner disconnected")),
      );

      _endCall();
    };

    await _webrtcService!.initWebRTC();

    if (socketService.isCaller) {
      await _webrtcService!.createOffer();
    }
  }

  /// Proper call termination
  void _endCall() {
    final socketService = Provider.of<SocketService>(context, listen: false);

    try {
      socketService.disconnect(); // safe socket disconnect
    } catch (_) {}

    _webrtcService?.dispose();

    if (mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtcService?.dispose();
    super.dispose();
  }

  /// Toggle microphone
  void _toggleMute() {
    final stream = _webrtcService?.localStream;
    if (stream == null) return;

    setState(() => _isMuted = !_isMuted);

    for (var track in stream.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
  }

  /// Toggle camera
  void _toggleVideo() {
    final stream = _webrtcService?.localStream;
    if (stream == null) return;

    setState(() => _isVideoOff = !_isVideoOff);

    for (var track in stream.getVideoTracks()) {
      track.enabled = !_isVideoOff;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          /// Remote Video
          _remoteRenderer.srcObject != null
              ? RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          )
              : Center(
            child: _isLoading
                ? const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                ),
                SizedBox(height: 16),
                Text(
                  "Connecting to partner...",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            )
                : const Text(
              "Waiting for partner...",
              style: TextStyle(color: Colors.white70),
            ),
          ),

          /// Local Video Preview
          Positioned(
            top: 50,
            right: 16,
            child: SizedBox(
              width: 120,
              height: 180,
              child: VideoView(
                renderer: _localRenderer,
                isLocal: true,
                label: "You",
              ),
            ),
          ),

          /// LIVE badge
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record,
                      color: Colors.red, size: 12),
                  SizedBox(width: 8),
                  Text(
                    "LIVE",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          /// Bottom controls
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                /// Mute
                _circleButton(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  _isMuted ? Colors.red : Colors.white,
                  _toggleMute,
                ),

                const SizedBox(width: 24),

                /// End Call
                _circleButton(
                  Icons.call_end,
                  Colors.red,
                  _endCall,
                  isLarge: true,
                ),

                const SizedBox(width: 24),

                /// Camera toggle
                _circleButton(
                  _isVideoOff ? Icons.videocam_off : Icons.videocam,
                  _isVideoOff ? Colors.red : Colors.white,
                  _toggleVideo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
      IconData icon, Color color, VoidCallback onTap,
      {bool isLarge = false}) {
    return Container(
      width: isLarge ? 72 : 56,
      height: isLarge ? 72 : 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == Colors.red ? color : Colors.white12,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color == Colors.red ? Colors.white : color,
          size: isLarge ? 32 : 24,
        ),
        onPressed: onTap,
      ),
    );
  }
}