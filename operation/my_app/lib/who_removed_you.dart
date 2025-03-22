import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class WhoRemovedYouScreen extends StatefulWidget {
  @override
  _WhoRemovedYouScreenState createState() => _WhoRemovedYouScreenState();
}

class _WhoRemovedYouScreenState extends State<WhoRemovedYouScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _unfollowedUsers = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchUnfollowedUsers();
  }

  Future<void> _fetchUnfollowedUsers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) throw Exception('Access token not found');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}api/get-who-removed-you/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _unfollowedUsers = (data['results'] as List)
              .map((user) => User.fromJson(user))
              .toList();
        });
      } else {
        throw Exception('Failed to fetch data');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _hasError = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeUser(String id) async {
    String url = "${AppConfig.baseUrl}api/remove-removed-you/";
    String? token = await _secureStorage.read(key: 'access_token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Access token not found.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"user_id": id}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _unfollowedUsers.removeWhere((user) => user.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User removed successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to remove user: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _showRemoveConfirmationDialog(String userId, String username) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $username?'),
        content: Text('Are you sure you want to remove $username?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove'),
            onPressed: () {
              Navigator.of(context).pop();
              _removeUser(userId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Who Unfollowed You")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Failed to load data"),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _fetchUnfollowedUsers,
                        child: Text("Retry"),
                      ),
                    ],
                  ),
                )
              : _unfollowedUsers.isEmpty
                  ? Center(child: Text("No one has unfollowed you yet!"))
                  : RefreshIndicator(
                      onRefresh: _fetchUnfollowedUsers,
                      child: ListView.builder(
                        itemCount: _unfollowedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _unfollowedUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(user.profilePicUrl),
                              backgroundColor: Colors.grey,
                            ),
                            title: Text(user.username),
                            subtitle: Text(user.fullName),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              onPressed: () {
                                _showRemoveConfirmationDialog(user.id, user.username);
                              },
                              child: Text('Remove'),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class User {
  final String id;
  final String username;
  final String fullName;
  final bool isPrivate;
  final bool isVerified;
  final String profilePicUrl;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.isPrivate,
    required this.isVerified,
    required this.profilePicUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      username: json['username'],
      fullName: json['full_name'] ?? '',
      isPrivate: json['is_private'] ?? false,
      isVerified: json['is_verified'] ?? false,
      profilePicUrl: json['profile_pic_url'] ?? '',
    );
  }
}