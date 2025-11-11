import 'package:flutter/material.dart';
import 'breakpoints.dart';

class TwoPane extends StatelessWidget {
  final Widget primary;
  final Widget? secondary;
  final bool showSecondary;
  final double? secondaryWidth;
  final double dividerWidth;

  const TwoPane({
    super.key,
    required this.primary,
    this.secondary,
    this.showSecondary = false,
    this.secondaryWidth,
    this.dividerWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact(context) || !showSecondary) {
      return primary;
    }
    final isWide = isExpanded(context);
    final paneWidth = (secondaryWidth != null)
        ? secondaryWidth!
        : (isWide ? 420.0 : 360.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: primary),
        VerticalDivider(width: dividerWidth),
        SizedBox(
          width: paneWidth,
          child: secondary ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
