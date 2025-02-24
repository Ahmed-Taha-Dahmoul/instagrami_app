import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final int initialIndex; // Add initialIndex
  final Function(int) onTabSelected;

  BottomNavBar(
      {required this.onTabSelected, this.initialIndex = 0}); // Default to 0

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex; // Use late initialization

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // Initialize with initialIndex
  }

  void _onItemTapped(int index) {
    // No need to setState here, as the parent will handle navigation
    widget.onTabSelected(index); // Notify the parent widget
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed, // Important for > 3 items
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blue, // Or your preferred color
      unselectedItemColor: Colors.grey, // Or your preferred color
      onTap: _onItemTapped,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.star),
          label: 'Followed',
        ),
      ],
    );
  }
}
