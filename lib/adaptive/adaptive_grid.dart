import 'package:flutter/material.dart';
import 'breakpoints.dart';

SliverGridDelegateWithMaxCrossAxisExtent channelsGridDelegate(BuildContext context) {
  final cls = sizeClassOf(context);
  switch (cls) {
    case WindowSizeClass.expanded:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 130,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      );
    case WindowSizeClass.medium:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 125,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      );
    case WindowSizeClass.compact:
      return const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 315,
        mainAxisExtent: 120,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      );
  }
}
