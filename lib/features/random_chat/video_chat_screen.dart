import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../services/socket_service.dart';
import '../../services/webrtc_service.dart';

class _ChatMessage {
  final String sender; // 'you', 'stranger', 'system'
  final String text;
  final DateTime time;

  _ChatMessage({required this.sender, required this.text, required this.time});
}

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
  bool _isRemoteVideoOff = false;
  bool _isRemoteMuted = false;
  bool _isConnecting = true;
  bool _isChatOpen = false;
  int _unreadCount = 0;

  Timer? _callTimer;
  int _callDurationSeconds = 0;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  String _partnerName = "Stranger";
  String _partnerCountry = "Global";
  List<String> _commonInterests = [];

  @override
  void initState() {
    super.initState();
    _initVideoCall();
  }

  Future<void> _initVideoCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _startWebRTC();
  }

  Future<void> _startWebRTC() async {
    final socketService = Provider.of<SocketService>(context, listen: false);

    _webrtcService = WebRTCService(socketService: socketService);

    // 1. Local video stream
    _webrtcService!.onLocalStream = (stream) {
      if (!mounted) return;
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    // 2. Remote video stream
    _webrtcService!.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isConnecting = false;
      });
      _startCallTimer();
    };

    // 3. Match found (e.g. after Skip)
    socketService.onMatchFound = (data) async {
      if (!mounted) return;
      setState(() {
        _partnerName = data['partner_username'] ?? 'Stranger';
        _partnerCountry = data['partner_country'] ?? 'Global';
        if (data['common_interests'] is List) {
          _commonInterests = List<String>.from(data['common_interests']);
        } else {
          _commonInterests = [];
        }
        _isConnecting = true;
        _isRemoteVideoOff = false;
        _isRemoteMuted = false;
      });

      _addMessage(
        sender: 'system',
        text: "Connected to $_partnerName from $_partnerCountry.",
      );

      if (_commonInterests.isNotEmpty) {
        _addMessage(
          sender: 'system',
          text: "You both like: ${_commonInterests.join(', ')}.",
        );
      }

      await _webrtcService!.resetPeerConnection();

      if (socketService.isCaller) {
        await _webrtcService!.createOffer();
      }
    };

    // 4. Partner disconnected / skipped
    socketService.onPartnerDisconnected = (data) {
      if (!mounted) return;

      final reason = data['reason'] ?? "Stranger disconnected.";
      _stopCallTimer();

      setState(() {
        _remoteRenderer.srcObject = null;
        _isConnecting = true;
      });

      _addMessage(sender: 'system', text: reason);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: "NEXT",
            textColor: const Color(0xFF00F0FF),
            onPressed: _skipPartner,
          ),
        ),
      );
    };

    // 5. In-call chat message
    socketService.onChatMessage = (data) {
      if (!mounted) return;
      final text = data['text']?.toString() ?? '';
      if (text.isNotEmpty) {
        _addMessage(sender: 'stranger', text: text);
        if (!_isChatOpen) {
          setState(() => _unreadCount++);
        }
      }
    };

    // 6. Partner media state (video / mic toggle)
    socketService.onPartnerMediaState = (data) {
      if (!mounted) return;
      setState(() {
        if (data.containsKey('is_video_off')) {
          _isRemoteVideoOff = data['is_video_off'] == true;
        }
        if (data.containsKey('is_muted')) {
          _isRemoteMuted = data['is_muted'] == true;
        }
      });
    };

    // 7. Report confirmed
    socketService.onReportConfirmed = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    };

    // 8. Searching status
    socketService.onSearching = () {
      if (!mounted) return;
      setState(() {
        _isConnecting = true;
        _remoteRenderer.srcObject = null;
      });
    };

    await _webrtcService!.initWebRTC();

    // Pull current partner info from socketService if already matched
    setState(() {
      _partnerName = socketService.partnerUsername ?? 'Stranger';
      _partnerCountry = socketService.partnerCountry ?? 'Global';
      _commonInterests = socketService.commonInterests;
    });

    _addMessage(
      sender: 'system',
      text: "You are now chatting with $_partnerName. Say hello!",
    );

    if (_commonInterests.isNotEmpty) {
      _addMessage(
        sender: 'system',
        text: "You both like: ${_commonInterests.join(', ')}.",
      );
    }

    if (socketService.isCaller) {
      await _webrtcService!.createOffer();
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  void _addMessage({required String sender, required String text}) {
    setState(() {
      _messages.add(_ChatMessage(
        sender: sender,
        text: text,
        time: DateTime.now(),
      ));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Action: SKIP / NEXT Stranger
  void _skipPartner() {
    final socketService = Provider.of<SocketService>(context, listen: false);

    _stopCallTimer();
    setState(() {
      _isConnecting = true;
      _remoteRenderer.srcObject = null;
      _partnerName = "Stranger";
      _commonInterests = [];
    });

    _addMessage(sender: 'system', text: "Skipping... finding next stranger.");

    _webrtcService?.resetPeerConnection();
    socketService.skip();
  }

  // Action: Toggle Microphone
  void _toggleMute() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    final newMute = !_isMuted;
    setState(() => _isMuted = newMute);
    _webrtcService?.setMicrophoneEnabled(!newMute);
    socketService.sendMediaState(isMuted: newMute, isVideoOff: _isVideoOff);
  }

  // Action: Toggle Video Camera
  void _toggleVideo() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    final newVideoOff = !_isVideoOff;
    setState(() => _isVideoOff = newVideoOff);
    _webrtcService?.setCameraEnabled(!newVideoOff);
    socketService.sendMediaState(isMuted: _isMuted, isVideoOff: newVideoOff);
  }

  // Action: Flip Camera (Front / Rear)
  Future<void> _flipCamera() async {
    await _webrtcService?.switchCamera();
  }

  // Action: Send Text Message
  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final socketService = Provider.of<SocketService>(context, listen: false);
    socketService.sendChatMessage(text);
    _addMessage(sender: 'you', text: text);
    _chatController.clear();
  }

  // Action: Report Stranger
  void _showReportDialog() {
    String selectedReason = "Inappropriate / NSFW Content";
    final detailsController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161626),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final reasons = [
              "Inappropriate / NSFW Content",
              "Harassment or Hate Speech",
              "Spam, Bot or Advertising",
              "Underage User",
              "Other Violation",
            ];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.redAccent, size: 24),
                      SizedBox(width: 10),
                      Text(
                        "Report Stranger",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Select a reason. Reporting will instantly disconnect you and find someone new.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r;
                    return RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      activeColor: Colors.redAccent,
                      title: Text(
                        r,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => selectedReason = val!);
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Optional details...",
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F0F1A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final socketService = Provider.of<SocketService>(context, listen: false);
                        _stopCallTimer();
                        setState(() {
                          _isConnecting = true;
                          _remoteRenderer.srcObject = null;
                        });
                        socketService.reportPartner(
                          reason: selectedReason,
                          details: detailsController.text.trim(),
                        );
                        _webrtcService?.resetPeerConnection();
                      },
                      icon: const Icon(Icons.report_problem_rounded, color: Colors.white),
                      label: const Text(
                        "REPORT & SKIP",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Action: Clean End Call
  void _endCall() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    _stopCallTimer();
    socketService.sendEndCall();
    _webrtcService?.dispose();

    if (mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _stopCallTimer();
    _chatController.dispose();
    _chatScrollController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtcService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. REMOTE STRANGER VIDEO (Full Canvas)
            Positioned.fill(
              child: _remoteRenderer.srcObject != null && !_isRemoteVideoOff
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _buildRemotePlaceholder(),
            ),

            // 2. REMOTE VIDEO OFF OVERLAY
            if (_remoteRenderer.srcObject != null && _isRemoteVideoOff)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F0F1A),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1A2E),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(
                            Icons.videocam_off_rounded,
                            size: 48,
                            color: Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "$_partnerName paused their camera",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. TOP HEADER BAR & STRANGER BADGES
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildHeaderOverlay(),
            ),

            // 4. FLOATING LOCAL VIDEO PREVIEW (PIP)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: _buildLocalPip(),
            ),

            // 5. LIVE IN-CALL TEXT CHAT OVERLAY
            Positioned(
              left: 16,
              right: _isChatOpen ? 16 : 140,
              bottom: 110,
              height: _isChatOpen ? 260 : 140,
              child: _buildChatOverlay(),
            ),

            // 6. BOTTOM CONTROL DOCK (Omegle controls)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildControlDock(),
            ),
          ],
        ),
      ),
    );
  }

  // Header overlay with stranger info, common interests & quick actions
  Widget _buildHeaderOverlay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // LIVE pill + Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isConnecting ? Colors.amber : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnecting ? "CONNECTING" : "LIVE",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  if (!_isConnecting) ...[
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_callDurationSeconds),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFeatures: [],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Stranger name & country
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Color(0xFF00F0FF)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "$_partnerName ($_partnerCountry)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isRemoteMuted) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.mic_off, size: 12, color: Colors.redAccent),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Flip camera
            _smallIconButton(
              icon: Icons.flip_camera_ios_rounded,
              color: Colors.white,
              onTap: _flipCamera,
              tooltip: "Flip camera",
            ),

            const SizedBox(width: 6),

            // Report
            _smallIconButton(
              icon: Icons.flag_rounded,
              color: Colors.redAccent,
              onTap: _showReportDialog,
              tooltip: "Report stranger",
            ),

            const SizedBox(width: 6),

            // Close
            _smallIconButton(
              icon: Icons.close_rounded,
              color: Colors.white70,
              onTap: _endCall,
              tooltip: "End call",
            ),
          ],
        ),

        // Common Interests Banner
        if (_commonInterests.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.interests_rounded, size: 12, color: Color(0xFF00F0FF)),
                const SizedBox(width: 6),
                Text(
                  "You both like: ${_commonInterests.join(', ')}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Floating local PIP (Picture-In-Picture)
  Widget _buildLocalPip() {
    return Container(
      width: 105,
      height: 155,
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!_isVideoOff && _localRenderer.srcObject != null)
            RTCVideoView(
              _localRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: true,
            )
          else
            Container(
              color: const Color(0xFF1E1E38),
              child: const Center(
                child: Icon(Icons.videocam_off, color: Colors.white30, size: 28),
              ),
            ),

          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "You",
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (_isMuted)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_off, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // Remote placeholder while searching / connecting
  Widget _buildRemotePlaceholder() {
    return Container(
      color: const Color(0xFF0A0A14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF00F0FF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Searching for a random stranger...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Keep it friendly and respectful.",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Live in-call text chat overlay
  Widget _buildChatOverlay() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isChatOpen
            ? const Color(0xFF0F0F1E).withValues(alpha: 0.9)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: _isChatOpen ? Border.all(color: Colors.white12) : null,
      ),
      child: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: EdgeInsets.zero,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                if (msg.sender == 'system') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: Colors.amberAccent.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }

                final isMe = msg.sender == 'you';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMe
                            ? const Color(0xFFB8B3FF).withValues(alpha: 0.3)
                            : Colors.white24,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: isMe ? "You: " : "Stranger: ",
                            style: TextStyle(
                              color: isMe ? const Color(0xFF00F0FF) : Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: msg.text,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Chat input field (visible when open)
          if (_isChatOpen) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendChatMessage(),
                      decoration: const InputDecoration(
                        hintText: "Say something...",
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF00F0FF), size: 20),
                  onPressed: _sendChatMessage,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Bottom Control Dock
  Widget _buildControlDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. SKIP / NEXT BUTTON (Omegle's primary button)
          ElevatedButton.icon(
            onPressed: _skipPartner,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
            label: const Text(
              "NEXT",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
            ),
          ),

          // 2. MUTE BUTTON
          _circleDockButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _isMuted ? Colors.redAccent : Colors.white,
            backgroundColor: _isMuted
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            onTap: _toggleMute,
            tooltip: _isMuted ? "Unmute" : "Mute",
          ),

          // 3. VIDEO BUTTON
          _circleDockButton(
            icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            color: _isVideoOff ? Colors.redAccent : Colors.white,
            backgroundColor: _isVideoOff
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            onTap: _toggleVideo,
            tooltip: _isVideoOff ? "Turn Video On" : "Turn Video Off",
          ),

          // 4. CHAT TOGGLE BUTTON
          Stack(
            clipBehavior: Clip.none,
            children: [
              _circleDockButton(
                icon: _isChatOpen ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                color: _isChatOpen ? const Color(0xFF00F0FF) : Colors.white,
                backgroundColor: _isChatOpen
                    ? const Color(0xFF00F0FF).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                onTap: () {
                  setState(() {
                    _isChatOpen = !_isChatOpen;
                    if (_isChatOpen) _unreadCount = 0;
                  });
                },
                tooltip: "In-Call Chat",
              ),
              if (_unreadCount > 0 && !_isChatOpen)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$_unreadCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 5. END CALL BUTTON
          _circleDockButton(
            icon: Icons.call_end_rounded,
            color: Colors.white,
            backgroundColor: Colors.redAccent,
            onTap: _endCall,
            tooltip: "Leave Chat",
          ),
        ],
      ),
    );
  }

  Widget _circleDockButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _smallIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}
