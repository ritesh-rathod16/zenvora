import 'package:flutter/material.dart';
import '../models/music_track_model.dart';

class AudioTrimmerWidget extends StatefulWidget {
  final MusicTrackModel track;
  final Function(double startTime, double duration) onTrimChanged;

  const AudioTrimmerWidget({
    super.key,
    required this.track,
    required this.onTrimChanged,
  });

  @override
  State<AudioTrimmerWidget> createState() => _AudioTrimmerWidgetState();
}

class _AudioTrimmerWidgetState extends State<AudioTrimmerWidget> {
  double _startTime = 0.0;
  double _duration = 30.0;

  @override
  void initState() {
    super.initState();
    _duration = widget.track.duration < 30 ? widget.track.duration.toDouble() : 30.0;
  }

  String _formatTime(double seconds) {
    int mins = seconds ~/ 60;
    int secs = (seconds % 60).toInt();
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Trim Audio Clip", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text("${_formatTime(_startTime)} - ${_formatTime(_startTime + _duration)}", style: const TextStyle(color: Color(0xFF00D2FF), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          // Waveform simulation bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(28, (index) {
                final height = (index % 5 == 0 ? 32.0 : (index % 3 == 0 ? 24.0 : 16.0));
                return Container(
                  width: 3,
                  height: height,
                  decoration: BoxDecoration(
                    color: index >= 4 && index <= 20 ? const Color(0xFF6C63FF) : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _startTime,
              min: 0.0,
              max: (widget.track.duration - _duration).clamp(0.0, widget.track.duration.toDouble()),
              onChanged: (val) {
                setState(() => _startTime = val);
                widget.onTrimChanged(_startTime, _duration);
              },
            ),
          ),
        ],
      ),
    );
  }
}
