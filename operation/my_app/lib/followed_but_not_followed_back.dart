import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

class FollowedButNotFollowedBackScreen extends StatefulWidget {
  @override
  _FollowedButNotFollowedBackScreenState createState() =>
      _FollowedButNotFollowedBackScreenState();
}

class _FollowedButNotFollowedBackScreenState
    extends State<FollowedButNotFollowedBackScreen> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  List<User> _users = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false; // Flag for data persistence

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Don't fetch data here.  Check _isInitialized in build.
  }

  // Fetch users from API with pagination
  Future<void> fetchUsers() async {
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception('Access token not found');

      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}api/get-followed-but-not-followed-back/?page=$_currentPage'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'];

        setState(() {
          _users.addAll(usersJson.map((user) => User.fromJson(user)).toList());
          _hasMoreData = data['next'] != null;
          if (_hasMoreData) _currentPage++;
          _isInitialized = true; // Set the flag after successful fetch
        });
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Scroll listener
  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoading) {
      fetchUsers();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch data only if it hasn't been initialized yet
    if (!_isInitialized) {
      fetchUsers();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Followed But Not Followed Back'),
      ),
      body: _users.isEmpty && _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Reset ONLY for pull-to-refresh
                setState(() {
                  _users = [];
                  _currentPage = 1;
                  _hasMoreData = true;
                  _isInitialized = false; // Reset for refresh
                });
                await fetchUsers();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _users.length + (_hasMoreData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _users.length) {
                    return _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : Container();
                  }
                  final user = _users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user.profilePicUrl),
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.fullName),
                    trailing: Icon(
                      user.isVerified ? Icons.check_circle : Icons.cancel,
                      color: user.isVerified ? Colors.blue : Colors.grey,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// User Model (No changes needed)
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
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      isPrivate: json['is_private'],
      isVerified: json['is_verified'],
      profilePicUrl: json['profile_pic_url'],
    );
  }
}
