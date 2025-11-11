import 'package:flutter/material.dart';
import 'breakpoints.dart';
import 'adaptive_nav.dart';

class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? phoneBottomNavigationBar;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.appBar,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.phoneBottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact(context)) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: phoneBottomNavigationBar,
        floatingActionButton: floatingActionButton,
      );
    }
    // Tablet & larger: show a Rail on the left
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          SizedBox(
            width: isExpanded(context) ? 256 : 72,
            child: AdaptiveRail(
              selectedIndex: selectedIndex,
              onSelected: onDestinationSelected,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
