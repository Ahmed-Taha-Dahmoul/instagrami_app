// who_unfollowed_you.dart

import 'package:flutter/material.dart';

class UnfollowedYouScreen extends StatefulWidget {
  @override
  _UnfollowedYouScreenState createState() => _UnfollowedYouScreenState();
}

class _UnfollowedYouScreenState extends State<UnfollowedYouScreen> {
  // Sample data (replace with your actual data fetching)
  final List<String> unfollowedUsers = [
    "user1",
    "user2",
    "user3",
    "anotherUser",
    "somebodyElse",
    "user4",
    "user5",
    "user6",
    "user7",
    "user8",
    "user9",
    "user10",
    "longUsername123",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Who Unfollowed You"),
      ),
      body: unfollowedUsers.isEmpty
          ? Center(child: Text("No one has unfollowed you yet!"))
          : ListView.builder(
              itemCount: unfollowedUsers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    // You'd ideally load the user's profile picture here
                    backgroundColor: Colors.grey, // Placeholder
                    child: Text(unfollowedUsers[index][0]
                        .toUpperCase()), // Show first letter
                  ),
                  title: Text(unfollowedUsers[index]),
                  trailing: Icon(Icons.arrow_forward_ios), // Add a > icon
                  onTap: () {
                    // Handle tapping on a user (e.g., view their profile)
                    print("Tapped on ${unfollowedUsers[index]}");
                    // You could navigate to a user profile screen here:
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(username: unfollowedUsers[index])));
                  },
                );
              },
            ),
    );
  }
}
