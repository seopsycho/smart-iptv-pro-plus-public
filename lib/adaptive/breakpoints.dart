import 'package:flutter/widgets.dart';

enum WindowSizeClass { compact, medium, expanded }

WindowSizeClass sizeClassOf(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 840) return WindowSizeClass.expanded;
  if (w >= 600) return WindowSizeClass.medium;
  return WindowSizeClass.compact;
}

bool isCompact(BuildContext context) => sizeClassOf(context) == WindowSizeClass.compact;
bool isMedium(BuildContext context) => sizeClassOf(context) == WindowSizeClass.medium;
bool isExpanded(BuildContext context) => sizeClassOf(context) == WindowSizeClass.expanded;
