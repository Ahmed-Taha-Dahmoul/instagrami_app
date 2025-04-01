import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:faker/faker.dart'; // Keep if you actually need Faker for other things, otherwise remove
import 'config.dart'; // Ensure this import points to your config file

class NotFollowedButFollowingMeScreen extends StatefulWidget {
  @override
  _NotFollowedButFollowingMeScreenState createState() =>
      _NotFollowedButFollowingMeScreenState();
}

class _NotFollowedButFollowingMeScreenState
    extends State<NotFollowedButFollowingMeScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _users = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false; // To track if initial fetch has happened
  // Map<String, dynamic>? instagramData; // Keep if needed elsewhere

  @override
  void initState() {
    super.initState();
    // Add listener to scroll controller for pagination
    _scrollController.addListener(_scrollListener);
    // Trigger initial fetch after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if the widget is still in the tree
        _fetchUsers(); // Call the initial fetch
      }
    });
  }

  // Fetch users who follow you but you don't follow back
  Future<void> _fetchUsers() async {
    // Prevent concurrent fetches or fetching when no more data
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Authentication error. Please log in again.')),
             );
          }
          throw Exception('Access token not found');
      }

      final response = await http.get(
        // Ensure endpoint matches backend route for "users following me but I don't follow back"
        Uri.parse(
            '${AppConfig.baseUrl}api/get-dont-follow-back-you/?page=$_currentPage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return; // Check if widget is still mounted

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'] ?? [];

        setState(() {
          _users.addAll(usersJson.map((user) => User.fromJson(user)).toList());
          _hasMoreData = data['next'] != null;
          if (_hasMoreData) {
            _currentPage++;
          }
          _isInitialized = true; // Mark as initialized AFTER successful fetch
        });
      } else {
         print('Failed to load users. Status: ${response.statusCode}, Body: ${response.body}');
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load users. Status: ${response.statusCode}')),
         );
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
         setState(() {
           _isLoading = false;
         });
      }
    }
  }

  // Scroll listener for infinite scrolling
  void _scrollListener() {
    // Check if scrolled close to the bottom and not currently loading
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 && // Threshold
        !_isLoading && _hasMoreData) {
      _fetchUsers(); // Fetch next page
    }
  }

  // --- Instagram API Call ---
  // Remove a follower directly on Instagram
  Future<bool> _removeFollowerOnInstagram(String userId) async {
    String? user1Id = await _secureStorage.read(key: 'user1_id'); // Your IG User ID
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');

    if (csrftoken == null ||
        user1Id == null ||
        sessionId == null ||
        xIgAppId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Missing required Instagram authentication data.")),
        );
      }
      return false;
    }

    // Use a consistent or semi-realistic User-Agent if possible
    // String userAgent = _generateRandomUserAgent(); // Can be risky if too random
    String userAgent = 'Instagram 150.0.0.0.000 Android (28/9; 480dpi; 1080x2137; OnePlus; ONEPLUS A6013; OnePlus6T; qcom; en_US; 123456789)'; // Example

    final headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$user1Id; sessionid=$sessionId",
      "referer": "https://www.instagram.com/$user1Id/following/", // Common referer
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      'Content-Type': 'application/x-www-form-urlencoded',
      "user-agent": userAgent,
      "x-instagram-ajax": "1", // Often required
    };

    // Body parameters might be required for this endpoint
    final body = {
      'user_id': userId, // The ID of the user to remove
      // '_uuid': 'GENERATED_UUID', // Sometimes needed
      // '_uid': user1Id,
      // '_csrftoken': csrftoken
    };

    try {
        final response = await http.post(
          // Double-check the exact endpoint for removing a follower
          // It might be under /friendships/remove_follower/ or similar
          Uri.parse(
              'https://www.instagram.com/api/v1/friendships/remove_follower/$userId/'),
          headers: headers,
          body: body, // Send necessary body parameters
        );

        print('Instagram Remove Follower Response Status Code: ${response.statusCode}');
        print('Instagram Remove Follower Response Body: ${response.body}');

        if (!mounted) return false;

        if (response.statusCode == 200) {
           final responseData = json.decode(response.body);
           if (responseData['status'] == 'ok') {
              print('Successfully removed follower $userId on Instagram.');
              return true; // Indicate success
           } else {
              print('Instagram API indicated failure: ${response.body}');
              ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text("Instagram API Error: ${responseData['message'] ?? 'Unknown error'}")),
              );
              return false;
           }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Failed to remove follower on Instagram. Status: ${response.statusCode}")),
          );
          return false; // Indicate failure
        }
    } catch (e) {
       print("Error calling Instagram remove follower API: $e");
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Network error during follower removal: $e")),
           );
       }
       return false;
    }
  }

  // --- Backend API Call ---
  // Remove the user from your backend's 'followers' list
  Future<bool> _removeFollowerFromBackend(String id) async {
    String url = "${AppConfig.baseUrl}api/remove-follower/"; // Ensure endpoint matches backend
    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Authentication error. Please log in again.')),
          );
       }
       return false;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "id": id, // Send the user ID to remove from backend follower list
        }),
      );

      print('Backend Remove Follower Response Status: ${response.statusCode}');
      print('Backend Remove Follower Response Body: ${response.body}');

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 204) { // 204 No Content is also success
        print('Successfully removed follower $id from backend.');
        return true;
      } else {
        String errorMsg = "Failed to remove follower from backend. Status: ${response.statusCode}";
        try {
           final errorData = json.decode(response.body);
           errorMsg += ": ${errorData['detail'] ?? errorData['error'] ?? response.body}";
        } catch (_) {
           errorMsg += ". Could not parse error details.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
        return false;
      }
    } catch (e) {
      print("Error calling backend remove-follower API: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Network error removing follower: $e")),
         );
      }
      return false;
    }
  }

  // --- Combined Action Handler ---
  // Handles removing the follower from Instagram and then the backend
  Future<void> _handleRemoveFollower(String userId, String username) async {
     // 1. Try removing follower on Instagram
     bool instagramSuccess = await _removeFollowerOnInstagram(userId);

     if (!mounted) return; // Check mount status

     if (instagramSuccess) {
        // 2. If Instagram removal succeeded, try removing from backend
        bool backendSuccess = await _removeFollowerFromBackend(userId);

        if (backendSuccess) {
           // 3. If both succeeded, update UI and show success message
           setState(() {
             _users.removeWhere((user) => user.id == userId);
           });
           _showSuccessOverlay(); // Show custom success overlay
        } else {
           // Backend removal failed, inform user
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Removed on Instagram, but failed to update our records. Please try refreshing.')),
           );
           // Optionally refetch list here: _refreshUsers();
        }
     } else {
        // Instagram removal failed, error already shown by _removeFollowerOnInstagram
     }
  }


  // --- UI Methods ---

  // Refreshes the user list from scratch
  Future<void> _refreshUsers() async {
    setState(() {
      _users = [];
      _currentPage = 1;
      _hasMoreData = true;
      _isInitialized = false;
      _isLoading = false;
    });
    await _fetchUsers();
  }

  // Confirmation Dialog for removing a follower
  Future<Future<Object?>> _showRemoveConfirmationDialog(String userId, String username) async {
     return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, a1, a2, widget) {
        // Use the same scale/fade transition as before
        final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: a1, curve: Curves.easeOutCubic),
        );
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
           CurvedAnimation(parent: a1, curve: Curves.easeIn),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0)),
              title: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.orange[800], size: 28), // Use orange for removal warning
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Remove $username?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Text(
                'This will remove $username from your followers list on Instagram and update our records. Are you sure?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              actionsPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.blueGrey, fontSize: 15)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[900], // Stronger orange/red for confirmation
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Remove', style: TextStyle(fontSize: 15)),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close dialog
                    // Initiate the combined remove follower process
                    await _handleRemoveFollower(userId, username);
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
    _scrollController.removeListener(_scrollListener); // Clean up listener
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Followers You Don\'t Follow'), // Clearer title
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: _buildBody(), // Delegate body building
      ),
    );
  }

  // Helper method to build the main body content
  Widget _buildBody() {
    // Initial loading state
    if (!_isInitialized && _isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Empty state
    if (_isInitialized && _users.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No users found who follow you but you don\'t follow back.\nPull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
      );
    }

    // List view with Scrollbar
    return Scrollbar( // ***** WRAP WITH SCROLLBAR *****
      controller: _scrollController, // ** Link the controller **
      thumbVisibility: true, // ** Make scrollbar always visible **
      thickness: 8.0,
      radius: Radius.circular(4.0),
      child: ListView.builder(
        controller: _scrollController, // ** Keep controller here too **
        physics: AlwaysScrollableScrollPhysics(), // For RefreshIndicator
        itemCount: _users.length + (_hasMoreData ? 1 : 0), // +1 for loading indicator
        itemBuilder: (context, index) {
          // Loading indicator at the bottom
          if (index == _users.length) {
            return (_isLoading && _hasMoreData)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SizedBox.shrink();
          }

          // Display user item
          final user = _users[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            elevation: 1.5,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePicUrl),
                    radius: 25,
                    backgroundColor: Colors.grey[200],
                  ),
                  if (user.isVerified)
                    Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, color: Colors.blue, size: 16),
                    ),
                ],
              ),
              title: Text(
                user.username,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                user.fullName,
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800], // Orange for 'Remove' action
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 1.0,
                ),
                onPressed: () {
                  _showRemoveConfirmationDialog(user.id, user.username);
                },
                child: Text('Remove'), // Button text clearly indicates action
              ),
            ),
          );
        },
      ),
    );
  }


  // Show the custom success overlay message
  void _showSuccessOverlay() {
     OverlayEntry? overlayEntry; // Make nullable

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 60.0,
        left: 0,
        right: 0,
        child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: SuccessMessageOverlay( // Use the updated overlay widget
                message: "User removed successfully!", // Pass specific message
                onClose: () {
                  overlayEntry?.remove();
                  overlayEntry = null;
                },
              ),
            ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }
}

// --- User Data Model --- (Same as before)
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
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? 'Unknown',
      fullName: json['full_name'] ?? '',
      isVerified: json['is_verified'] ?? false,
      profilePicUrl: json['profile_pic_url'] ?? '',
    );
  }
}


// --- Custom Success Message Overlay Widget ---
// Updated to accept a message parameter
class SuccessMessageOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final String message; // Added message parameter

  SuccessMessageOverlay({
      required this.onClose,
      required this.message, // Make message required
  });

  @override
  _SuccessMessageOverlayState createState() => _SuccessMessageOverlayState();
}

class _SuccessMessageOverlayState extends State<SuccessMessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0.0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );

    _controller.forward();

    _timer = Timer(Duration(seconds: 3), () {
      if (mounted) {
         _controller.reverse().then((_) {
           if (mounted) {
              widget.onClose();
           }
         });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                )
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                widget.message, // Use the passed message
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}