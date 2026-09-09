import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/task.dart';

class StatusBadge extends StatelessWidget {
  final dynamic status;
  final bool showIcon;

  const StatusBadge({super.key, required this.status, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    String statusStr = '';
    if (status is String) {
      statusStr = status as String;
    } else if (status is TaskStatus) {
      statusStr = (status as TaskStatus).value;
    } else if (status is ProjectStatus) {
      statusStr = (status as ProjectStatus).value;
    } else if (status != null) {
      statusStr = status.toString();
    }

    final lower = statusStr.toLowerCase();

    if (lower == 'active' || lower == 'in_progress') {
      bg = const Color(0xFFDBEAFE); // Blue 100
      fg = const Color(0xFF1E40AF); // Blue 800
      icon = lower == 'active' ? Icons.play_circle_outline : Icons.autorenew;
      label = lower == 'active' ? 'Active' : 'In Progress';
    } else if (lower == 'completed') {
      bg = const Color(0xFFDCFCE7); // Green 100
      fg = const Color(0xFF166534); // Green 800
      icon = Icons.check_circle_outline;
      label = 'Completed';
    } else if (lower == 'cancelled') {
      bg = const Color(0xFFFEE2E2); // Red 100
      fg = const Color(0xFF991B1B); // Red 800
      icon = Icons.cancel_outlined;
      label = 'Cancelled';
    } else if (lower == 'todo') {
      bg = const Color(0xFFF1F5F9); // Slate 100
      fg = const Color(0xFF475569); // Slate 600
      icon = Icons.radio_button_unchecked;
      label = 'To Do';
    } else {
      bg = const Color(0xFFFEF3C7); // Amber 100
      fg = const Color(0xFF92400E); // Amber 800
      icon = Icons.schedule;
      label = 'Planned';
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
            label,
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
