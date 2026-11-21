import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_service.dart';
import '../../services/socket_service.dart';

class VibeMatchingScreen extends StatefulWidget {
  const VibeMatchingScreen({super.key});

  @override
  State<VibeMatchingScreen> createState() => _VibeMatchingScreenState();
}

class _VibeMatchingScreenState extends State<VibeMatchingScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _vibes = [];
  final Set<String> _preferredVibes = {};
  String? _selectedVibe;
  String? _error;
  SocketService? _socketService;
  bool _loading = true;
  bool _saving = false;
  bool _searching = false;
  bool _matched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _socketService = context.read<SocketService>()
        ..addListener(_onSocketChanged)
        ..onMatchFound = _onMatchFound;
      _loadVibes();
    });
  }

  @override
  void dispose() {
    if (_searching && !_matched) _socketService?.leaveQueue();
    _socketService?.removeListener(_onSocketChanged);
    if (_socketService?.onMatchFound == _onMatchFound) {
      _socketService?.onMatchFound = null;
    }
    super.dispose();
  }

  Future<void> _loadVibes() async {
    try {
      final response = await _api.get('/vibes');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw body['detail']?.toString() ?? 'Could not load vibes.';
      }
      final rawVibes = body['vibes'] as List? ?? const [];
      final active = body['active_vibe'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _vibes = rawVibes
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _selectedVibe = active?['vibe_id']?.toString();
        _preferredVibes
          ..clear()
          ..addAll((active?['preferred_vibes'] as List? ?? const [])
              .map((id) => id.toString()));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _onMatchFound(Map<String, dynamic> _) {
    _matched = true;
    if (mounted) context.pushReplacement('/video-chat');
  }

  void _onSocketChanged() {
    final service = _socketService;
    if (!mounted || service == null) return;
    if (service.matchmakingError != null) {
      setState(() {
        _searching = false;
        _error = service.matchmakingError;
      });
    } else if (_searching && !service.isSearching && !service.isConnected) {
      setState(() {
        _searching = false;
        _error = 'Connection lost. Please try again.';
      });
    }
  }

  Future<void> _startSearch() async {
    final selected = _selectedVibe;
    final socket = _socketService;
    if (selected == null || socket == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.put('/vibes/me', {
        'vibe_id': selected,
        'preferred_vibes': _preferredVibes.toList(),
      });
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw body['detail']?.toString() ?? 'Could not set your active vibe.';
      }
      await socket.joinQueue(metadata: const {'match_mode': 'vibe'});
      if (!mounted) return;
      setState(() {
        _searching = true;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Future<void> _clearVibe() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.put('/vibes/me', {
        'vibe_id': null,
        'preferred_vibes': <String>[],
      });
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw body['detail']?.toString() ?? 'Could not clear your active vibe.';
      }
      _socketService?.leaveQueue();
      if (!mounted) return;
      setState(() {
        _selectedVibe = null;
        _preferredVibes.clear();
        _searching = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Map<String, dynamic>? get _selectedVibeData {
    for (final vibe in _vibes) {
      if (vibe['id'] == _selectedVibe) return vibe;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedVibeData;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VIBE MATCHING',
          style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
          onPressed: () {
            if (_searching) _socketService?.leaveQueue();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
            : _searching
                ? _buildSearching(selected)
                : _buildVibePicker(selected),
      ),
    );
  }

  Widget _buildVibePicker(Map<String, dynamic>? selected) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        const Text(
          'How are you feeling right now?',
          style: TextStyle(
              color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick a vibe and we’ll find someone who is open to the same kind of conversation.',
          style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: _vibes.map((vibe) {
            final id = vibe['id'].toString();
            final isSelected = _selectedVibe == id;
            return ChoiceChip(
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedVibe = id;
                  _preferredVibes.remove(id);
                  _error = null;
                });
              },
              avatar: Text(vibe['emoji']?.toString() ?? '✨'),
              label: Text(vibe['label']?.toString() ?? id),
              selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.28),
              backgroundColor: const Color(0xFF1A1A2E),
              side: BorderSide(
                  color: isSelected ? const Color(0xFF8E88FF) : Colors.white12),
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600),
              showCheckmark: false,
            );
          }).toList(),
        ),
        if (_selectedVibe != null) ...[
          const SizedBox(height: 25),
          const Text('ALSO OPEN TO (OPTIONAL)',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _vibes.where((vibe) => vibe['id'] != _selectedVibe).map((vibe) {
              final id = vibe['id'].toString();
              final selectedPreference = _preferredVibes.contains(id);
              return FilterChip(
                selected: selectedPreference,
                onSelected: (value) => setState(() => value
                    ? _preferredVibes.add(id)
                    : _preferredVibes.remove(id)),
                label: Text('${vibe['emoji'] ?? '✨'} ${vibe['label'] ?? id}'),
                selectedColor: const Color(0xFF00D2D8).withValues(alpha: 0.18),
                backgroundColor: const Color(0xFF141424),
                side: BorderSide(
                    color: selectedPreference
                        ? const Color(0xFF00D2D8).withValues(alpha: 0.6)
                        : Colors.white10),
                labelStyle:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            Text(selected['description']?.toString() ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 18),
          Text(_error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _selectedVibe == null || _saving ? null : _startSearch,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_saving ? 'SETTING YOUR VIBE…' : 'FIND MY VIBE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : _clearVibe,
            child: const Text('Clear active vibe',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ],
    );
  }

  Widget _buildSearching(Map<String, dynamic>? selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.55),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    blurRadius: 40)
              ],
            ),
            child: Center(
                child: Text(selected?['emoji']?.toString() ?? '✨',
                    style: const TextStyle(fontSize: 42))),
          ),
          const SizedBox(height: 28),
          Text('Looking for ${selected?['label'] ?? 'your vibe'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 9),
          const Text(
              'We’re finding someone with a compatible vibe and shared interests.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 14, height: 1.4)),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                _socketService?.leaveQueue();
                setState(() => _searching = false);
              },
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.redAccent),
              label: const Text('STOP SEARCHING',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
              onPressed: _saving ? null : _clearVibe,
              child: const Text('Clear my active vibe',
                  style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }
}
