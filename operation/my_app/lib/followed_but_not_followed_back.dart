import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart'; // Ensure this import points to your config file

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
  bool _isInitialized = false; // To track if initial fetch has happened
  // Map<String, dynamic>? instagramData; // Keep if needed elsewhere, otherwise remove

  @override
  void initState() {
    super.initState();
    // Add listener to scroll controller for pagination
    _scrollController.addListener(_scrollListener);
    // Trigger initial fetch after the first frame is built
    // This prevents calling fetchUsers during the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) { // Check if the widget is still in the tree
         _fetchUsers(); // Call the initial fetch
       }
    });
  }

  // Renamed fetchUsers to _fetchUsers for consistency (private method)
  Future<void> _fetchUsers() async {
    // Prevent concurrent fetches or fetching when no more data
    if (_isLoading || !_hasMoreData) return;

    setState(() {
      _isLoading = true;
      // Don't set _isInitialized here, set it only after successful fetch
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
          // Handle missing token - maybe navigate to login?
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Authentication error. Please log in again.')),
             );
          }
          throw Exception('Access token not found');
      }

      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}api/get-followed-but-not-followed-back/?page=$_currentPage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json', // Good practice
        },
      );

      if (!mounted) return; // Check if widget is still mounted before processing response

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'] ?? []; // Handle potential null

        setState(() {
          _users.addAll(usersJson.map((user) => User.fromJson(user)).toList());
          _hasMoreData = data['next'] != null;
          if (_hasMoreData) {
            _currentPage++;
          }
          _isInitialized = true; // Mark as initialized AFTER successful fetch
        });
      } else {
         // Provide more context on failure
         print('Failed to load users. Status: ${response.statusCode}, Body: ${response.body}');
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load users. Status: ${response.statusCode}')),
         );
        // Consider setting _hasMoreData to false on certain errors if needed
      }
    } catch (e) {
      print('Error fetching users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
       // Optionally set _hasMoreData = false or retry logic here
    } finally {
      // Ensure isLoading is set to false even if errors occur
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

  // Unfollow user directly on Instagram
  Future<bool> _unfollowUserOnInstagram(String userId) async {
    String? user1Id = await _secureStorage.read(key: 'user1_id');
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

    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$user1Id; sessionid=$sessionId",
      "referer":
          "https://www.instagram.com/api/v1/friendships/destroy/$userId/", // Referer might be important
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      'Content-Type': 'application/x-www-form-urlencoded', // Standard for IG API posts
      'User-Agent': 'Instagram 10.3.2 (iPhone7,2; iPhone OS 9_3_3; en_US; en-US; scale=2.00; 750x1334) AppleWebKit/420+', // Example User-Agent
    };

    // Instagram API might require an empty body or specific parameters depending on endpoint version
    final body = {
     // 'user_id': userId, // Sometimes required, sometimes part of URL
     // '_uuid': 'GENERATED_UUID', // Often needed
     // '_uid': user1Id, // Often needed
     // '_csrftoken': csrftoken // Often needed in body too
    };

    try {
        final response = await http.post(
          Uri.parse(
              'https://www.instagram.com/api/v1/friendships/destroy/$userId/'), // Check exact endpoint
          headers: headers,
          body: body, // Send body if needed, otherwise send {} or remove body parameter
        );

        print('Instagram Unfollow Response Status Code: ${response.statusCode}');
        print('Instagram Unfollow Response Body: ${response.body}');

        if (!mounted) return false;

        if (response.statusCode == 200) {
           final responseData = json.decode(response.body);
           // Check Instagram's specific success response structure
           if (responseData['status'] == 'ok') {
              print('Successfully unfollowed $userId on Instagram.');
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
                    "Failed to unfollow on Instagram. Status: ${response.statusCode}")),
          );
          return false; // Indicate failure
        }
    } catch (e) {
       print("Error calling Instagram unfollow API: $e");
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Network error during unfollow: $e")),
           );
       }
       return false;
    }
  }

  // Remove the user from your backend's 'following' list
  Future<bool> _removeFollowingFromBackend(String id) async {
    String url = "${AppConfig.baseUrl}api/remove-following/";
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
          "id": id, // Send the user ID to remove
        }),
      );

      print('Backend Remove Following Response Status: ${response.statusCode}');
      print('Backend Remove Following Response Body: ${response.body}');

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 204) { // 204 No Content is also success
        print('Successfully removed following $id from backend.');
        return true;
      } else {
        // Try to parse error message from backend if available
        String errorMsg = "Failed to remove following from backend. Status: ${response.statusCode}";
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
      print("Error calling backend remove-following API: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Network error removing following: $e")),
         );
      }
      return false;
    }
  }

  // Combined unfollow logic: Tries Instagram first, then backend
  Future<void> _handleUnfollow(String userId, String username) async {
     // 1. Try unfollowing on Instagram
     bool instagramSuccess = await _unfollowUserOnInstagram(userId);

     if (!mounted) return; // Check if widget is still mounted

     if (instagramSuccess) {
        // 2. If Instagram unfollow succeeded, try removing from backend
        bool backendSuccess = await _removeFollowingFromBackend(userId);

        if (backendSuccess) {
           // 3. If both succeeded, update UI and show success message
           setState(() {
             _users.removeWhere((user) => user.id == userId);
           });
           _showSuccessOverlay(); // Show custom success overlay
        } else {
           // Backend removal failed, inform user, but keep UI state as unfollowed on IG
           // Maybe add the user back visually or show a specific error?
           // For now, just show error. User is unfollowed on IG.
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unfollowed on Instagram, but failed to update our records. Please try refreshing.')),
           );
           // Optionally, refetch the list here to ensure consistency if backend failed
           // _refreshUsers();
        }
     } else {
        // Instagram unfollow failed, do nothing more. Error message already shown.
     }
  }

  // Refreshes the user list from scratch
  Future<void> _refreshUsers() async {
    setState(() {
      _users = [];
      _currentPage = 1;
      _hasMoreData = true;
      _isInitialized = false; // Reset initialization flag
      _isLoading = false; // Reset loading flag in case it was stuck
    });
    await _fetchUsers(); // Fetch the first page again
  }

  // Confirmation Dialog
  Future<Future<Object?>> _showUnfollowConfirmationDialog(String userId, String username) async {
     return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.6), // Darker overlay
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        // Needs a placeholder, but the actual content is in transitionBuilder
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        // Simple scale and fade transition
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
              title: Row( // Use Row for icon and text alignment
                children: [
                  Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 28),
                  SizedBox(width: 12),
                  Expanded( // Prevent overflow if username is long
                    child: Text(
                      'Unfollow $username?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to unfollow this user on Instagram and remove them from this list?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              actionsPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel', style: TextStyle(color: Colors.blueGrey, fontSize: 15)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Keep red for confirmation
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Unfollow', style: TextStyle(fontSize: 15)),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close the dialog first
                    // Initiate the combined unfollow process
                    await _handleUnfollow(userId, username);
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
    _scrollController.removeListener(_scrollListener); // Remove listener
    _scrollController.dispose(); // Dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Not Following Back'),
        backgroundColor: Colors.white, // Example styling
        foregroundColor: Colors.black87, // Example styling
        elevation: 1.0, // Subtle shadow
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers, // Use the refresh function
        child: _buildBody(), // Delegate body building to a separate method
      ),
    );
  }

  // Helper method to build the main body content
  Widget _buildBody() {
    // Initial loading state (before first successful fetch)
    if (!_isInitialized && _isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Empty state (after fetch, if no users found)
    if (_isInitialized && _users.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No users found who don\'t follow you back.\nPull down to refresh.',
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
      thickness: 8.0, // Optional: customize thickness
      radius: Radius.circular(4.0), // Optional: customize radius
      child: ListView.builder(
        controller: _scrollController, // ** Keep controller here too for listener **
        physics: AlwaysScrollableScrollPhysics(), // Ensure scrollable even if content fits screen (for RefreshIndicator)
        itemCount: _users.length + (_hasMoreData ? 1 : 0), // +1 for loading indicator
        itemBuilder: (context, index) {
          // Loading indicator at the bottom
          if (index == _users.length) {
            // Only show if loading and there's potentially more data
            return (_isLoading && _hasMoreData)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SizedBox.shrink(); // Return empty space otherwise
          }

          // Display user item
          final user = _users[index];
          return Card( // Wrap ListTile in Card for better visual separation
            margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
            elevation: 1.5,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: Stack(
                alignment: Alignment.bottomRight, // Align badge easily
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePicUrl),
                    radius: 25,
                    backgroundColor: Colors.grey[200], // Placeholder color
                  ),
                  if (user.isVerified)
                    Container(
                      padding: EdgeInsets.all(1), // Padding around the icon
                      decoration: BoxDecoration(
                        color: Colors.white, // White background for contrast
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.blue,
                        size: 16,
                      ),
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
                  backgroundColor: Colors.redAccent, // Consistent red
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0), // Pill shape
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  elevation: 1.0, // Subtle elevation
                ),
                onPressed: () {
                  _showUnfollowConfirmationDialog(user.id, user.username);
                },
                child: Text('Unfollow'),
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 60.0, // Position above keyboard/nav bar
        left: 0, // Take full width
        right: 0,
        child: Align( // Center the overlay content horizontally
            alignment: Alignment.center,
            child: Material( // Needed for elevation and theming
              color: Colors.transparent, // Let child handle color/shape
              child: SuccessMessageOverlay(
                onClose: () {
                  overlayEntry?.remove(); // Safely remove
                  overlayEntry = null; // Clear reference
                },
              ),
            ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry!);
  }
}

// --- User Data Model ---
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
    // Add null checks for robustness
    return User(
      id: json['id']?.toString() ?? '', // Ensure ID is string and handle null
      username: json['username'] ?? 'Unknown',
      fullName: json['full_name'] ?? '',
      isVerified: json['is_verified'] ?? false,
      profilePicUrl: json['profile_pic_url'] ?? '', // Provide default or handle missing URL
    );
  }
}

// --- Custom Success Message Overlay Widget ---
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
  late Animation<Offset> _slideAnimation; // Added for slide effect
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400), // Animation duration
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Slide in from bottom
    _slideAnimation = Tween<Offset>(begin: Offset(0.0, 0.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack) // Nice bouncy effect
    );

    _controller.forward(); // Start animations

    // Automatically close after 3 seconds
    _timer = Timer(Duration(seconds: 3), () {
      if (mounted) { // Check if still mounted before reversing
         _controller.reverse().then((_) {
           if (mounted) { // Check again before calling onClose
              widget.onClose(); // Remove the overlay
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
      child: SlideTransition( // Add slide transition
        position: _slideAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20), // Add horizontal margin
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green[700], // Slightly darker green
            borderRadius: BorderRadius.circular(10),
            boxShadow: [ // Add subtle shadow
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                )
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Fit content width
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                "User unfollowed successfully!",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}