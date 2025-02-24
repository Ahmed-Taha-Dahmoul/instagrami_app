import 'package:flutter/material.dart';
//import 'bottom_nav_bar.dart'; // No longer needed

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Add any state variables you need for the settings page here.
  bool _notificationsEnabled = true; // Example setting
  String _selectedTheme = "Light"; // Example setting

  // You can add methods for handling settings changes, etc.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18),
                ),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    // Save the notification setting (e.g., using shared_preferences)
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Theme',
              style: TextStyle(fontSize: 18),
            ),
            DropdownButton<String>(
              value: _selectedTheme,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedTheme = newValue!;
                });
                // Apply the selected theme (you'll need to implement theme switching)
              },
              items: <String>['Light', 'Dark', 'System']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Example: Implement logout functionality
                // You would typically clear user data and navigate to the login/welcome screen:
                // _logoutUser(); // Call your logout function from main.dart (you'll need to handle this)
              },
              child: Text('Logout'),
            ),
          ],
        ),
      ),
      //bottomNavigationBar: BottomNavBar(onTabSelected: _onTabSelected, initialIndex: 2), // NO LONGER NEEDED
    );
  }
// No onTabSelected needed
}
