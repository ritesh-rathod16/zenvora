import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../services/socket_service.dart';
import '../../services/voice_service.dart';
import 'dart:convert';
import '../../core/services/api_service.dart';

class VoiceRoomScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  const VoiceRoomScreen({super.key, required this.room});

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> with TickerProviderStateMixin {
  late SocketService _socketService;
  late VoiceService _voiceService;
  late ApiService _apiService;
  
  bool _isHandRaised = false;
  bool _isSpeakerOn = true;
  bool _showChat = false;
  
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  
  late AnimationController _bgController;
  final List<FloatingEmoji> _floatingEmojis = [];

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _voiceService = Provider.of<VoiceService>(context, listen: false);
    _apiService = ApiService();
    
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    
    _connectToSFU();
    _setupSocketListeners();
  }

  Future<void> _connectToSFU() async {
    final roomId = widget.room['_id']?.toString();
    if (roomId == null) {
       debugPrint("VoiceRoom: Missing room ID");
       return;
    }
    
    try {
      final response = await _apiService.get("/rooms/$roomId/token");
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final token = data['token']?.toString();
        final sfuUrl = data['url']?.toString() ?? "ws://localhost:7880";
        
        if (token != null) {
          await _voiceService.joinRoom(roomId, token, sfuUrl);
        }
      }
    } catch (e) {
      debugPrint("Error joining SFU room: $e");
    }
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;
    final roomId = widget.room['_id']?.toString();
    if (roomId == null) return;
    
    final username = _voiceService.room?.localParticipant?.identity ?? "You";
    final msg = {
      'room_id': roomId,
      'username': username,
      'text': _chatController.text.trim(),
      'time': DateTime.now().toIso8601String(),
    };
    
    try {
      _socketService.socket.emit('room_message', msg);
      if (mounted) {
        setState(() => _messages.add(msg));
      }
      _chatController.clear();
    } catch (e) {
      debugPrint("Send Chat Error: $e");
    }
  }

  void _sendReaction(String emoji) {
    final roomId = widget.room['_id']?.toString();
    if (roomId == null) return;
    
    try {
      _socketService.socket.emit('room_reaction', {'room_id': roomId, 'emoji': emoji});
      _showReactionOverlay(emoji);
    } catch (e) {
      debugPrint("Send Reaction Error: $e");
    }
  }

  void _showReactionOverlay(String emoji) {
    setState(() {
      _floatingEmojis.add(FloatingEmoji(
        emoji: emoji,
        x: 0.2 + (0.6 * (DateTime.now().millisecond / 1000)),
        y: 0.8,
        controller: AnimationController(
          vsync: this,
          duration: const Duration(seconds: 3),
        )..forward().then((_) {
          _floatingEmojis.removeWhere((e) => e.emoji == emoji);
        }),
      ));
    });
  }

  void _toggleHand() {
    setState(() => _isHandRaised = !_isHandRaised);
    _socketService.socket.emit('hand_raised', {'room_id': widget.room['_id'], 'raised': _isHandRaised});
  }

  void _leaveRoom() async {
    final roomId = widget.room['_id']?.toString();
    
    try {
      await _voiceService.leaveRoom();
      if (roomId != null) {
        _socketService.socket.emit('room_leave', {'room_id': roomId});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Leave Room Error: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  void _setupSocketListeners() {
    final roomId = widget.room['_id']?.toString();
    if (roomId == null) return;

    try {
      _socketService.socket.on('room_message', (data) {
        if (mounted && data != null) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(data));
          });
        }
      });

      _socketService.socket.on('room_reaction', (data) {
        if (mounted && data != null) {
          final emoji = data['emoji']?.toString();
          if (emoji != null) _showReactionOverlay(emoji);
        }
      });

      _socketService.socket.on('hand_raised', (data) {
        if (mounted && data != null) {
          debugPrint("Socket: Hand raised event");
          setState(() {}); 
        }
      });

      _socketService.socket.on('room_joined', (data) {
        if (mounted && data != null) {
          debugPrint("Socket: User joined - ${data['username']}");
        }
      });

      _socketService.socket.on('room_left', (data) {
        if (mounted && data != null) {
          debugPrint("Socket: User left - ${data['user_id']}");
        }
      });

      _socketService.socket.on('participant_muted', (data) {
        if (mounted && data != null) {
          debugPrint("Socket: Participant muted status changed");
          setState(() {}); 
        }
      });

      _socketService.socket.on('participant_speaking', (data) {
        if (mounted && data != null) {
          // Additional UI logic for speaking can go here
        }
      });

      _socketService.socket.on('room_ended', (data) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("The room has been ended.")),
          );
          _leaveRoom();
        }
      });

      _socketService.socket.on('moderator_action', (data) {
        if (mounted && data != null) {
          final action = data['action']?.toString();
          if (action == 'mute_all' && !_voiceService.isMuted) {
            _voiceService.toggleMute();
          }
        }
      });

    } catch (e) {
      debugPrint("Socket Listener Error: $e");
    }
  }

  @override
  void dispose() {
    _socketService.socket.off('room_message');
    _socketService.socket.off('room_reaction');
    _socketService.socket.off('hand_raised');
    _socketService.socket.off('room_joined');
    _socketService.socket.off('room_left');
    _socketService.socket.off('participant_muted');
    _socketService.socket.off('participant_speaking');
    _socketService.socket.off('room_ended');
    _socketService.socket.off('moderator_action');

    _bgController.dispose();
    _chatController.dispose();
    for (var e in _floatingEmojis) {
      e.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceService>();
    final participants = voice.participants;
    final localParticipant = voice.room?.localParticipant;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Stack(
        children: [
          _buildAmbientBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(participants.length + 1),
                Expanded(
                  child: Stack(
                    children: [
                      _buildParticipantsGrid(voice, participants, localParticipant),
                      if (_showChat) _buildChatOverlay(),
                    ],
                  ),
                ),
                _buildBottomControls(voice),
              ],
            ),
          ),
          
          ..._floatingEmojis.map((e) => _buildFloatingEmoji(e)),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                0.3 * (0.5 - _bgController.value),
                -0.4 * (0.5 - _bgController.value),
              ),
              radius: 1.8,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF0F0F1A),
                Colors.black,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Column(
            children: [
              Text(
                widget.room['title']?.toString() ?? "Voice Room",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    "LIVE • $count PARTICIPANTS",
                    style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: Icon(_showChat ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, color: Colors.white),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid(voice, participants, localParticipant) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 30,
        childAspectRatio: 0.7,
      ),
      itemCount: participants.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildParticipantCard(
            localParticipant?.identity ?? "You",
            voice.isMuted,
            true,
            _isHandRaised,
            localParticipant?.isSpeaking ?? false,
          );
        }
        final p = participants[index - 1];
        return _buildParticipantCard(
          p.identity,
          !p.isMicrophoneEnabled(),
          false,
          false,
          p.isSpeaking,
        );
      },
    );
  }

  Widget _buildParticipantCard(String name, bool muted, bool isMe, bool handRaised, bool isSpeaking) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isSpeaking)
              _VoicePulseRing(isMe: isMe),
            
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: handRaised ? Colors.amber : isMe ? const Color(0xFF6C63FF) : Colors.white12,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF1A1A2E),
                child: ClipOval(
                  child: Image.network(
                    "https://api.dicebear.com/7.x/bottts-neutral/png?seed=$name",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            if (muted)
              Positioned(
                bottom: 2, right: 2,
                child: _buildStatusIndicator(Icons.mic_off_rounded, Colors.redAccent),
              ),
            if (handRaised)
              Positioned(
                top: 2, left: 2,
                child: _buildStatusIndicator(Icons.front_hand_rounded, Colors.amber, isEmoji: true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            color: isMe ? const Color(0xFF6C63FF) : Colors.white70,
            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(IconData icon, Color color, {bool isEmoji = false}) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: isEmoji 
        ? const Text("✋", style: TextStyle(fontSize: 10))
        : Icon(icon, size: 10, color: Colors.white),
    );
  }

  Widget _buildChatOverlay() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15),
              child: Text("CHAT", style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['username'], style: const TextStyle(fontSize: 10, color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                        Text(m['text'], style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type something...",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
                    onPressed: _sendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(VoiceService voice) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReactionRow(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildControlCircle(
                voice.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                voice.isMuted ? Colors.redAccent : const Color(0xFF6C63FF),
                voice.toggleMute,
              ),
              _buildControlCircle(
                Icons.front_hand_rounded,
                _isHandRaised ? Colors.amber : Colors.white38,
                _toggleHand,
              ),
              _buildLeaveButton(),
              _buildControlCircle(
                _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                Colors.white38,
                () => setState(() => _isSpeakerOn = !_isSpeakerOn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ["🔥", "😂", "👏", "❤️", "😮", "🙌", "💯"].map((emoji) => 
          GestureDetector(
            onTap: () => _sendReaction(emoji),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          )
        ).toList(),
      ),
    );
  }

  Widget _buildControlCircle(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  Widget _buildLeaveButton() {
    return GestureDetector(
      onTap: _leaveRoom,
      child: Container(
        height: 56, width: 110,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text(
            "LEAVE",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingEmoji(FloatingEmoji emoji) {
    return AnimatedBuilder(
      animation: emoji.controller,
      builder: (context, child) {
        final progress = emoji.controller.value;
        return Positioned(
          left: MediaQuery.of(context).size.width * emoji.x,
          bottom: MediaQuery.of(context).size.height * (emoji.y + progress * 0.4),
          child: Opacity(
            opacity: 1 - progress,
            child: Transform.scale(
              scale: 0.8 + progress * 0.8,
              child: Text(emoji.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
        );
      },
    );
  }
}

class FloatingEmoji {
  final String emoji;
  final double x;
  final double y;
  final AnimationController controller;
  FloatingEmoji({required this.emoji, required this.x, required this.y, required this.controller});
}

class _VoicePulseRing extends StatefulWidget {
  final bool isMe;
  const _VoicePulseRing({required this.isMe});
  @override
  State<_VoicePulseRing> createState() => _VoicePulseRingState();
}

class _VoicePulseRingState extends State<_VoicePulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(2, (index) {
            final progress = (_controller.value + index * 0.5) % 1.0;
            return Container(
              width: 85 + (progress * 40), height: 85 + (progress * 40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: (widget.isMe ? const Color(0xFF6C63FF) : Colors.cyanAccent).withOpacity(1 - progress), width: 2),
              ),
            );
          }),
        );
      },
    );
  }
}
