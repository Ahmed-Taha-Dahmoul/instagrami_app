import 'package:flutter/material.dart';
//import 'bottom_nav_bar.dart'; // No longer needed here

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Add any state variables you need for the profile page here.
  String _userName = "Example User"; // Example data
  String _email = "user@example.com"; // Example data

  // You can add methods for fetching user data, updating profile, etc.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Username:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _userName,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Email:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _email,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Example: Implement edit profile functionality
                // You might navigate to an edit profile screen:
                // Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen()));
              },
              child: Text('Edit Profile'),
            ),
          ],
        ),
      ),
      //bottomNavigationBar: BottomNavBar(onTabSelected: _onTabSelected, initialIndex: 1), // NO LONGER NEEDED
    );
  }

  // No _onTabSelected needed here anymore.
}
