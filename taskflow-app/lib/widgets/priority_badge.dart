import 'package:flutter/material.dart';
import '../models/task.dart';

class PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  final bool showIcon;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;

    switch (priority) {
      case TaskPriority.urgent:
        bg = const Color(0xFFFEE2E2); // Red 100
        fg = const Color(0xFF991B1B); // Red 800
        icon = Icons.error_outline;
        break;
      case TaskPriority.high:
        bg = const Color(0xFFFFEDD5); // Orange 100
        fg = const Color(0xFF9A3412); // Orange 800
        icon = Icons.keyboard_double_arrow_up;
        break;
      case TaskPriority.medium:
        bg = const Color(0xFFFEF9C3); // Yellow 100
        fg = const Color(0xFF854D0E); // Yellow 800
        icon = Icons.drag_handle;
        break;
      case TaskPriority.low:
        bg = const Color(0xFFF1F5F9); // Slate 100
        fg = const Color(0xFF475569); // Slate 600
        icon = Icons.keyboard_arrow_down;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            priority.label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
