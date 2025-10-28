import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class BottomNav extends StatefulWidget {
  final Function(int) onTabSelected;
  final int startingIndex;
  const BottomNav({
    super.key,
    required this.onTabSelected,
    this.startingIndex = 0,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    setState(() {
      _selectedIndex = widget.startingIndex;
    });
  }

  void onBarTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onTabSelected(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceBright,
            border: Border(
                top: BorderSide(
                    color: Theme.of(context).colorScheme.surfaceBright,
                    width: 1))),
        child: BottomNavigationBar(
          showUnselectedLabels: false,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(FeatherIcons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(FeatherIcons.star),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Icon(FeatherIcons.tv),
              label: 'Live TV',
            ),
            BottomNavigationBarItem(
              icon: Icon(FeatherIcons.monitor),
              label: 'Series',
            ),
            BottomNavigationBarItem(
              icon: Icon(FeatherIcons.film),
              label: 'Movies',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: onBarTapped,
          type: BottomNavigationBarType.fixed,
        ));
  }
}
