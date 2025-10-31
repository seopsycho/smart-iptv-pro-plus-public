import 'package:flutter/material.dart';

void showError(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  if (message.trim().isEmpty) return;
  _show(context,
      message: message,
      background: const Color(0xFFB00020),
      icon: Icons.error_outline,
      duration: duration ?? const Duration(seconds: 4),
      actionLabel: actionLabel,
      onAction: onAction);
}

void showInfo(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  if (message.trim().isEmpty) return;
  _show(context,
      message: message,
      background: const Color(0xFF1F2937),
      icon: Icons.info_outline,
      duration: duration ?? const Duration(seconds: 3),
      actionLabel: actionLabel,
      onAction: onAction);
}

void showSuccess(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  if (message.trim().isEmpty) return;
  _show(context,
      message: message,
      background: const Color(0xFF166534),
      icon: Icons.check_circle_outline,
      duration: duration ?? const Duration(seconds: 2),
      actionLabel: actionLabel,
      onAction: onAction);
}

void _show(BuildContext context,
    {required String message,
    required Color background,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: background,
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(label: actionLabel, onPressed: onAction, textColor: Colors.white)
        : null,
  ));
}
