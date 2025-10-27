import 'package:flutter/material.dart';

class CorrectionModal extends StatelessWidget {
  final String originalUrl;
  final String correctedUrl;
  final List<String> changes;
  const CorrectionModal(
      {super.key,
      required this.originalUrl,
      required this.correctedUrl,
      required this.changes});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Fix URL"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Original"),
          const SizedBox(height: 4),
          SelectableText(originalUrl,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text("Will be corrected to"),
          const SizedBox(height: 4),
          SelectableText(correctedUrl,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text("Changes"),
          const SizedBox(height: 4),
          ...changes.map((c) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• "),
                  Expanded(child: Text(c)),
                ],
              )),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Proceed anyway")),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Use corrected URL"))
      ],
    );
  }
}
