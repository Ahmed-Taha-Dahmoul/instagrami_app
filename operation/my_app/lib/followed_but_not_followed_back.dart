import 'dart:async';
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
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _users = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  Map<String, dynamic>? instagramData;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> fetchUsers() async {
    // ... (same as before, no changes needed here) ...
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
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

  void _scrollListener() {
    // ... (same as before, no changes needed here) ...
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !_isLoading) {
      fetchUsers();
    }
  }

  Future<void> _unfollowUser(String userId) async {
    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');
    
    if (csrftoken == null ||
        user1Id == null ||
        sessionId == null ||
        xIgAppId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Missing required authentication data.")),
      );
      return;
    }

    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$user1Id; sessionid=$sessionId",
      "referer":
          "https://www.instagram.com/api/v1/friendships/destroy/$userId/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final response = await http.post(
      Uri.parse(
          'https://www.instagram.com/api/v1/friendships/destroy/$userId/'),
      headers: headers,
      body: {},
    );

    print('Unfollow Response Status Code: ${response.statusCode}');
    print('Unfollow Response Body: ${response.body}');

    if (response.statusCode == 200) {
      setState(() {
        _users.removeWhere((user) => user.id == userId);
      });
      // Show the custom success overlay
      _showSuccessOverlay(); // Call our new function!
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Failed to unfollow user. Status code: ${response.statusCode}")),
      );
    }
  }


  Future<Map<String, dynamic>> _removeFollowing(
    String pk) async {
    String url = "${AppConfig.baseUrl}api/remove-following/";
    String? token = await _secureStorage.read(key: 'access_token');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "pk": pk, // Send the pk in the request body
        }),
      );

      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "error": "Failed to remove following: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      return {"error": "Exception occurred", "details": e.toString()};
    }
  }

  // The dramatically improved dialog!
  Future<Future<Object?>> _showUnfollowConfirmationDialog(
      String userId, String username) async {
    // Corrected return type: Future<void>
    return showGeneralDialog(
      // No need to await or store the result.
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        final curvedValue = Curves.easeInOutBack.transform(a1.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
          child: Opacity(
            opacity: a1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_remove,
                          color: Colors.redAccent, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Unfollow $username?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to unfollow $username?',
                style: TextStyle(fontSize: 16),
              ),
              actions: <Widget>[
                TextButton(
                  child:
                      Text('Cancel', style: TextStyle(color: Colors.blueGrey)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Just close the dialog.
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child:
                      Text('Unfollow', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog first.
                    _unfollowUser(userId); // Then unfollow.
                    _removeFollowing(userId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(user.profilePicUrl),
                          radius: 25,
                        ),
                        if (user.isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: Colors.white),
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.fullName),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Red background
                        foregroundColor: Colors.white, // White text
                        shape: RoundedRectangleBorder(
                          // Add this
                          borderRadius:
                              BorderRadius.circular(8.0), // Adjust radius
                        ),
                      ),
                      onPressed: () {
                        _showUnfollowConfirmationDialog(
                            user.id, user.username); // Show confirmation
                      },
                      child: Text('Unfollow'),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showSuccessOverlay() {
    late OverlayEntry overlayEntry; // Declare it here

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 50.0, // Adjust as needed
        left: 20,
        right: 20,
        child: Material(
          // Wrap with Material for elevation
          elevation: 8.0,
          borderRadius: BorderRadius.circular(10),
          child: SuccessMessageOverlay(
            onClose: () {
              overlayEntry.remove();
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}

class User {
  final String id;
  final String username;
  final String fullName;
  final bool isVerified;
  final String profilePicUrl;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    required this.isVerified,
    required this.profilePicUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      isVerified: json['is_verified'],
      profilePicUrl: json['profile_pic_url'],
    );
  }
}

// Custom Success Message Widget
class SuccessMessageOverlay extends StatefulWidget {
  final VoidCallback onClose;

  SuccessMessageOverlay({required this.onClose});

  @override
  _SuccessMessageOverlayState createState() => _SuccessMessageOverlayState();
}

class _SuccessMessageOverlayState extends State<SuccessMessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500), // Fade in/out duration
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward(); // Start fade-in

    // Automatically remove after 3 seconds
    _timer = Timer(Duration(seconds: 3), () {
      _controller.reverse().then((_) {
        widget.onClose(); // Remove the overlay
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel(); // Cancel the timer if the widget is disposed early
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[600], // Darker green
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Important for wrapping content
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              "User unfollowed successfully!",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
