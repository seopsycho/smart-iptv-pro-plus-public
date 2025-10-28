import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:shimmer/shimmer.dart';

class Loading extends StatelessWidget {
  final Widget child;
  const Loading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayWidgetBuilder: (_) {
        final base = const Color(0xFF1E1E24);
        final highlight = const Color(0xFF2A2A30);
        return Center(
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 240, height: 20, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 12),
                Container(width: 280, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 8),
                Container(width: 200, height: 14, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
        );
      },
      child: child,
    );
  }
}
