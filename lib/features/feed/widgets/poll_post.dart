import 'package:flutter/material.dart';
import '../models/post_model.dart';

class PollPostWidget extends StatefulWidget {
  final PostModel post;
  const PollPostWidget({super.key, required this.post});

  @override
  State<PollPostWidget> createState() => _PollPostWidgetState();
}

class _PollPostWidgetState extends State<PollPostWidget> {
  int? selectedOption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.content,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ...?widget.post.pollOptions?.asMap().entries.map((entry) {
          int idx = entry.key;
          PollOption option = entry.value;
          bool isSelected = selectedOption == idx;

          return GestureDetector(
            onTap: () => setState(() => selectedOption = idx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF6C63FF).withOpacity(0.2) 
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
                ),
              ),
              child: Stack(
                children: [
                  if (selectedOption != null)
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      widthFactor: option.percentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(option.label),
                      if (selectedOption != null)
                        Text(
                          "${option.percentage.toInt()}%",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (selectedOption != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "Total Votes: 1,240",
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ),
      ],
    );
  }
}
