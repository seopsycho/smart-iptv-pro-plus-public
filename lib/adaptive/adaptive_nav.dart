import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'breakpoints.dart';

List<NavigationRailDestination> _destinations() => const [
  NavigationRailDestination(icon: Icon(FeatherIcons.home), label: Text('Home')),
  NavigationRailDestination(icon: Icon(FeatherIcons.star), label: Text('Favorites')),
  NavigationRailDestination(icon: Icon(FeatherIcons.tv), label: Text('Live TV')),
  NavigationRailDestination(icon: Icon(FeatherIcons.monitor), label: Text('Series')),
  NavigationRailDestination(icon: Icon(FeatherIcons.film), label: Text('Movies')),
  NavigationRailDestination(icon: Icon(FeatherIcons.download), label: Text('Downloads')),
];

class AdaptiveRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const AdaptiveRail({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final expanded = isExpanded(context);
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: expanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      extended: expanded,
      destinations: _destinations(),
    );
  }
}
