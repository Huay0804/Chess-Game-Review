import 'package:flutter/material.dart';

/// Help remains available to touch, keyboard and screen-reader users.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.label, required this.message});
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    icon: const Icon(Icons.info_outline, size: 18),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    ),
  );
}
