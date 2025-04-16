import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart'; // Ensure this import points to your config file

// --- Reusable User Model (Use the same one defined previously) ---
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
    this.isPrivate = false,
    required this.isVerified,
    required this.profilePicUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    T? _safeCast<T>(dynamic value) => value is T ? value : null;
    return User(
      id: _safeCast<int>(json['pk'])?.toString() ??
          _safeCast<int>(json['pk_id'])?.toString() ??
          _safeCast<int>(json['id'])?.toString() ??
          _safeCast<String>(json['pk']) ??
          _safeCast<String>(json['pk_id']) ??
          _safeCast<String>(json['id']) ??
          '',
      username: _safeCast<String>(json['username']) ?? 'Unknown User',
      fullName: _safeCast<String>(json['full_name']) ?? '',
      isPrivate: _safeCast<bool>(json['is_private']) ?? false,
      isVerified: _safeCast<bool>(json['is_verified']) ?? false,
      profilePicUrl: _safeCast<String>(json['profile_pic_url']) ??
          'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=?',
    );
  }
}

class NotFollowedButFollowingMeScreen extends StatefulWidget {
  @override
  _NotFollowedButFollowingMeScreenState createState() =>
      _NotFollowedButFollowingMeScreenState();
}

class _NotFollowedButFollowingMeScreenState
    extends State<NotFollowedButFollowingMeScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _users = []; // Renamed for clarity
  bool _isLoading = true; // For initial load or refresh
  bool _isLoadingMore = false; // For loading subsequent pages
  bool _hasError = false;
  String _errorMessage = '';
  String? _nextPageUrl; // URL for the next page of results
  int _totalUserCount = 0; // Total number of users in this list

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchInitialUsers(); // Fetch initial data using the new method
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  // Listener to detect when user scrolls near the bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _nextPageUrl != null) {
      if (mounted) {
        _loadMoreUsers(); // Use the new pagination method
      }
    }
  }

  // Fetches the *first* page of users
  Future<void> _fetchInitialUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _users = [];
      _nextPageUrl = null;
      _totalUserCount = 0;
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      // ***** USE CORRECT API ENDPOINT FOR THIS SCREEN *****
      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}api/get-dont-follow-back-you/'), // Correct endpoint
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'] ?? [];
        _nextPageUrl = data['next'];
        _totalUserCount =
            data['count'] ?? data['total_count'] ?? usersJson.length;

        setState(() {
          _users =
              usersJson.map((userJson) => User.fromJson(userJson)).toList();
          _isLoading = false;
        });
      } else {
        String errorBody = response.body;
        try {
          final errorData = json.decode(response.body);
          errorBody =
              errorData['detail'] ?? errorData['error'] ?? response.body;
        } catch (_) {}
        throw Exception(
            'Failed to fetch data. Status: ${response.statusCode}, Response: $errorBody');
      }
    } catch (e) {
      print('Error fetching followers you don\'t follow: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e is TimeoutException
              ? 'The request timed out. Please check your connection and try again.'
              : 'An error occurred: ${e.toString()}';
        });
      }
    }
  }

  // Fetches subsequent pages of users
  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || _nextPageUrl == null || !mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Authentication token missing.');
      }

      final response = await http.get(
        Uri.parse(_nextPageUrl!),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'] ?? [];
        String? nextPageFromResponse = data['next'];

        setState(() {
          _users.addAll(
              usersJson.map((userJson) => User.fromJson(userJson)).toList());
          _nextPageUrl = nextPageFromResponse;
        });
      } else {
        print(
            'Failed to load more data. Status: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load more users.'),
              duration: Duration(seconds: 2)),
        );
        // Consider setting _nextPageUrl = null to stop trying on failure
      }
    } catch (e) {
      print('Error loading more users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading more users.'),
              duration: Duration(seconds: 2)),
        );
        // Consider setting _nextPageUrl = null
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // --- REMOVE FOLLOWER LOGIC (Adapted from your original code) ---

  // Remove a follower directly on Instagram
  Future<bool> _removeFollowerOnInstagram(String userId) async {
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
          SnackBar(
              content: Text("Missing required Instagram authentication data.")),
        );
      }
      return false;
    }

    // Use a consistent mobile user agent
    String userAgent =
        'Instagram 279.0.0.18.110 (iPhone13,3; iOS 15.0; en_US; en-US; scale=3.00; 1170x2532; 465661478) AppleWebKit/605.1.15';

    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$user1Id; sessionid=$sessionId",
      "referer":
          "https://www.instagram.com/$user1Id/followers/", // Referer for followers page
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      'Content-Type': 'application/x-www-form-urlencoded',
      "user-agent": userAgent,
      // "x-instagram-ajax": "100...", // Value might change, sometimes optional
    };

    // Body for remove follower endpoint
    final body = {
      'user_id': userId, // ID of follower to remove
      '_uid': user1Id, // Your user ID
      // '_uuid': generateUuid(), // Generate if needed
      '_csrftoken': csrftoken,
    };

    try {
      // Endpoint for removing a follower
      final response = await http.post(
        Uri.parse(
            'https://www.instagram.com/api/v1/friendships/remove_follower/$userId/'),
        headers: headers,
        body: body,
      );

      print(
          'Instagram Remove Follower Response Status Code: ${response.statusCode}');
      print('Instagram Remove Follower Response Body: ${response.body}');

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          print('Successfully removed follower $userId on Instagram.');
          return true;
        } else {
          print('Instagram API indicated failure: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Instagram Error: ${responseData['message'] ?? 'Remove follower failed'}")),
          );
          return false;
        }
      } else {
        String errorMsg =
            "Failed to remove follower. Status: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg += ": ${errorData['message'] ?? response.body}";
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print("Error calling Instagram remove follower API: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Network error during follower removal."),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // Remove the user from your backend's 'followers' list
  Future<bool> _removeFollowerFromBackend(String userId) async {
    String url =
        "${AppConfig.baseUrl}api/remove-follower/"; // Correct backend endpoint
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
          // Match backend expectation ('user_id', 'id', 'pk'?)
          "user_id": userId
        }),
      );

      print('Backend Remove Follower Response Status: ${response.statusCode}');

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Successfully removed follower $userId from backend.');
        return true;
      } else {
        String errorMsg =
            "Failed to update backend records. Status: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg +=
              ": ${errorData['detail'] ?? errorData['error'] ?? response.body}";
        } catch (_) {}
        print("Backend remove error: $errorMsg");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      print("Error calling backend remove-follower API: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Network error updating backend."),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // Combined remove follower logic
  Future<void> _handleRemoveFollower(String userId, String username) async {
    // 1. Try removing follower on Instagram
    bool instagramSuccess = await _removeFollowerOnInstagram(userId);

    if (!mounted) return;

    if (instagramSuccess) {
      // 2. If IG removal succeeded, try removing from backend
      bool backendSuccess = await _removeFollowerFromBackend(userId);

      if (backendSuccess) {
        // 3. If both succeeded, update UI state and show standard overlay
        setState(() {
          _users.removeWhere((user) => user.id == userId);
          if (_totalUserCount > 0) {
            _totalUserCount--; // Decrement count
          }
        });
        _showSuccessOverlay(
            "User removed successfully!"); // Use standard success message
      } else {
        // Backend failed, but IG succeeded. Remove from UI anyway.
        setState(() {
          _users.removeWhere((user) => user.id == userId);
          if (_totalUserCount > 0) {
            _totalUserCount--; // Decrement count
          }
        });
        _showSuccessOverlay(
            "Removed on Instagram!"); // Indicate partial success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to update backend records. Refresh may be needed later.'),
              backgroundColor: Colors.orange),
        );
      }
    } else {
      // Instagram removal failed, error already shown.
    }
  }

  // Refreshes the user list from scratch
  Future<void> _refreshUsers() async {
    await _fetchInitialUsers(); // Call the initial fetch function
  }

  // --- UI Elements (Adapted from UnfollowedYouScreen) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // *** UPDATED AppBar Title ***
        title: Text("Followers You Don't Follow"), // Specific title
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: _buildBody(),
      ),
    );
  }

  // --- Header Widget (Adapted) ---
  Widget _buildHeader() {
    if (_totalUserCount <= 0 && !_isLoading) return SizedBox.shrink();
    if (_isLoading) return SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            children: <TextSpan>[
              TextSpan(
                text: '$_totalUserCount user${_totalUserCount != 1 ? 's' : ''}',
                style: TextStyle(
                    color: Colors.blue, // Match target color
                    fontWeight: FontWeight.bold),
              ),
              // *** UPDATED Header Text Context ***
              TextSpan(text: ' follow you, but you don\'t follow them back'),
            ],
          ),
        ),
      ),
    );
  }

  // --- Body Builder (Adapted) ---
  Widget _buildBody() {
    // --- Initial Loading State ---
    if (_isLoading && _users.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    // --- Error State ---
    if (_hasError && _users.isEmpty) {
      // Use the standard error widget
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: Colors.grey[400], size: 60),
              SizedBox(height: 16),
              Text(
                "Couldn't load data",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchInitialUsers,
                child: Text("Retry"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // --- Empty State ---
    if (!_isLoading && _users.isEmpty && !_hasError) {
      // Use the standard empty state structure
      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        Icons
                            .people_outline, // Icon suggesting followers/people
                        size: 60,
                        color: Colors.grey[400]),
                    SizedBox(height: 16),
                    // *** UPDATED Empty State Text ***
                    Text(
                      "No users found in this list.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "It seems you follow back everyone who follows you, or the list is empty.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Pull down to refresh.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      });
    }

    // --- Data Loaded State (List View - Adapted) ---
    return Column(
      children: [
        _buildHeader(), // Include the header
        Expanded(
          child: Scrollbar(
            // Add Scrollbar
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 6.0,
            radius: Radius.circular(3.0),
            child: ListView.separated(
              // Use ListView.separated
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: _users.length +
                  (_isLoadingMore || _nextPageUrl != null ? 1 : 0),
              itemBuilder: (context, index) {
                // --- Loading Indicator Logic ---
                if (index == _users.length) {
                  if (_isLoadingMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (_nextPageUrl != null) {
                    return SizedBox(height: 40);
                  } else {
                    return SizedBox.shrink();
                  }
                }

                // --- Build User List Item (Adapted Style) ---
                final user = _users[index];
                return ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePicUrl),
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                  ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: user.username,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (user.isVerified)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.verified,
                                  color: Colors.blue, size: 16),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user.fullName.isNotEmpty ? user.fullName : ' ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // --- Trailing Button (Use OutlinedButton style, but for Remove action) ---
                  trailing: OutlinedButton(
                    // Use the OutlinedButton style
                    style: OutlinedButton.styleFrom(
                      // Use orange/red for remove action, similar to unfollow but distinct?
                      foregroundColor: Colors.orange.shade800,
                      side:
                          BorderSide(color: Colors.orange.shade200, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      // Call the remove confirmation dialog
                      _showRemoveConfirmationDialog(user.id, user.username);
                    },
                    child: Text('Remove'), // Text indicates action
                  ),
                );
              },
              // --- Divider (Match style) ---
              separatorBuilder: (context, index) {
                if (index == _users.length - 1 &&
                    (_isLoadingMore || _nextPageUrl != null)) {
                  return SizedBox.shrink();
                }
                return Divider(
                  height: 1,
                  thickness: 1,
                  indent: 72.0, // Indent past avatar+padding
                  endIndent: 16.0,
                  color: Colors.grey[200],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Confirmation Dialog (Styled like target, but for Remove action) ---
  Future<Future<Object?>> _showRemoveConfirmationDialog(
      String userId, String username) async {
    return showGeneralDialog(
      // Use the standard dialog structure
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, a1, a2, widget) {
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
              // Consistent Dialog Text - Adjusted for Remove context
              title: Text(
                // Simple title
                'Remove $username?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              content: Text(
                // Adjust content text for remove action
                'Are you sure you want to remove $username from your followers list on Instagram?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              actionsPadding:
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 15)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // Use a distinct warning color for Remove
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Remove', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _handleRemoveFollower(
                        userId, username); // Call REMOVE handler
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Success Overlay (Using the shared widget) ---
  void _showSuccessOverlay(String message) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Position consistently (top, centered)
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: SuccessMessageOverlay(
              // Use the *SAME* overlay widget
              message: message, // Pass the specific message
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
} // End of _NotFollowedButFollowingMeScreenState

// --- Custom Success Message Overlay Widget (Should be identical to the one defined before) ---
// Make sure this widget is defined only once in your project, perhaps in a shared file,
// or ensure the definition here is exactly the same as in the other files.
class SuccessMessageOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final String message;

  SuccessMessageOverlay({required this.onClose, required this.message});

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
    // Slide from top animation
    _slideAnimation = Tween<Offset>(begin: Offset(0.0, -1.5), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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
              color: Color(0xFF00A98F), // Consistent success color
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
