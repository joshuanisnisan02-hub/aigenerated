import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.activeIndex, required this.onChanged});

  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const modes = [
    ('Magtanong', Icons.chat_bubble_outline_rounded),
    ('Kuwento', Icons.auto_stories_outlined),
    ('Quiz', Icons.psychology_alt_outlined),
    ('Timeline', Icons.timeline_rounded),
    ('Bayani', Icons.person_search_outlined),
    ('Totoo Ba?', Icons.fact_check_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(modes.length, (i) {
        final selected = i == activeIndex;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onChanged(i),
          avatar: Icon(modes[i].$2, size: 17),
          label: Text(modes[i].$1),
          side: BorderSide(color: selected ? const Color(0xFF173A5E) : const Color(0x26173A5E)),
          selectedColor: const Color(0xFFE9EEF4),
          backgroundColor: const Color(0xFFFFFCF5),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF173A5E) : const Color(0xFF4D5360),
          ),
        );
      }),
    );
  }
}
