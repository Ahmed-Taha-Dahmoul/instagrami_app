import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart'; // Ensure this import points to your config file

// --- Reusable User Model (Assuming it's the same as in UnfollowedYouScreen) ---
class User {
  final String id;
  final String username;
  final String fullName;
  final bool isPrivate; // Added to match target model structure if needed
  final bool isVerified;
  final String profilePicUrl;

  User({
    required this.id,
    required this.username,
    required this.fullName,
    this.isPrivate = false, // Default if not provided by this specific endpoint
    required this.isVerified,
    required this.profilePicUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    T? _safeCast<T>(dynamic value) => value is T ? value : null;
    return User(
      // Use Instagram's pk/pk_id if available, fallback to 'id'
      id: _safeCast<int>(json['pk'])?.toString() ??
          _safeCast<int>(json['pk_id'])?.toString() ??
          _safeCast<int>(json['id'])?.toString() ?? // Fallback to 'id'
          _safeCast<String>(json['pk']) ??
          _safeCast<String>(json['pk_id']) ??
          _safeCast<String>(json['id']) ?? // Fallback to 'id' as string
          '', // Final fallback
      username: _safeCast<String>(json['username']) ?? 'Unknown User',
      fullName: _safeCast<String>(json['full_name']) ?? '',
      isPrivate: _safeCast<bool>(json['is_private']) ?? false,
      isVerified: _safeCast<bool>(json['is_verified']) ?? false,
      profilePicUrl: _safeCast<String>(json['profile_pic_url']) ??
          'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=?', // Placeholder
    );
  }
}

class FollowedButNotFollowedBackScreen extends StatefulWidget {
  @override
  _FollowedButNotFollowedBackScreenState createState() =>
      _FollowedButNotFollowedBackScreenState();
}

class _FollowedButNotFollowedBackScreenState
    extends State<FollowedButNotFollowedBackScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _users = []; // Renamed for clarity on this screen
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
        _fetchInitialUsers(); // Fetch initial data
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
        _loadMoreUsers();
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
      _users = []; // Reset user list
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
        // Use the base endpoint for the initial fetch
        Uri.parse(
            '${AppConfig.baseUrl}api/get-followed-but-not-followed-back/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> usersJson = data['results'] ?? [];
        _nextPageUrl = data['next']; // Get the next page URL from response
        // Get total count, checking multiple possible keys
        _totalUserCount = data['count'] ??
            data['total_count'] ??
            usersJson.length; // Fallback if count not present

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
      print('Error fetching users not following back: $e');
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
        Uri.parse(_nextPageUrl!), // Use the stored next page URL
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
          _users.addAll(// Add new users to the existing list
              usersJson.map((userJson) => User.fromJson(userJson)).toList());
          _nextPageUrl = nextPageFromResponse; // Update the next page URL
        });
      } else {
        print(
            'Failed to load more data. Status: ${response.statusCode}, Body: ${response.body}');
        // Show temporary message instead of setting error state for pagination
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load more users.'),
              duration: Duration(seconds: 2)),
        );
        // Optionally set _nextPageUrl = null here if errors should stop pagination
        // setState(() { _nextPageUrl = null; });
      }
    } catch (e) {
      print('Error loading more users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading more users.'),
              duration: Duration(seconds: 2)),
        );
        // Optionally set _nextPageUrl = null here
        // setState(() { _nextPageUrl = null; });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // --- UNFOLLOW LOGIC (Adapted from your original code) ---

  // Unfollow user directly on Instagram
  Future<bool> _unfollowUserOnInstagram(String userId) async {
    // Ensure user ID is numeric if required by IG API (though it might accept string)
    String? userPk = userId; // Use the ID directly, assuming it's the PK

    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId =
        await _secureStorage.read(key: 'x_ig_app_id'); // Read X-IG-App-ID

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

    // Construct headers as before
    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$user1Id; sessionid=$sessionId",
      "referer": "https://www.instagram.com/", // General referer often works
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId, // Include X-IG-App-ID
      'Content-Type': 'application/x-www-form-urlencoded',
      // Use a common mobile user agent
      'User-Agent':
          'Instagram 279.0.0.18.110 (iPhone13,3; iOS 15.0; en_US; en-US; scale=3.00; 1170x2532; 465661478) AppleWebKit/605.1.15',
    };

    // Instagram unfollow often requires the user ID in the URL and specific form data
    final body = {
      'user_id': userPk, // The ID of the user to unfollow
      // '_uuid': generateUuid(), // Generate a version 4 UUID if needed
      '_uid': user1Id, // Your own user ID
      '_csrftoken': csrftoken,
    };

    try {
      // Use the standard v1 unfollow endpoint
      final response = await http.post(
        Uri.parse(
            'https://www.instagram.com/api/v1/friendships/destroy/$userPk/'),
        headers: headers,
        body: body, // Send the form data
      );

      print('Instagram Unfollow Response Status Code: ${response.statusCode}');
      print('Instagram Unfollow Response Body: ${response.body}');

      if (!mounted) return false;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Check Instagram's specific success response structure (often status: 'ok')
        if (responseData['status'] == 'ok') {
          print('Successfully unfollowed $userId on Instagram.');
          return true; // Indicate success
        } else {
          print('Instagram API indicated failure: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    "Instagram Error: ${responseData['message'] ?? 'Unfollow failed'}")),
          );
          return false;
        }
      } else {
        // Handle common errors like 403 (Forbidden/CSRF issue), 400 (Bad Request), 429 (Rate Limit)
        String errorMsg =
            "Failed to unfollow on Instagram. Status: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg += ": ${errorData['message'] ?? response.body}";
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
        return false; // Indicate failure
      }
    } catch (e) {
      print("Error calling Instagram unfollow API: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Network error during unfollow."),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // Remove the user from your backend's 'following' list (if applicable for this screen)
  // NOTE: This screen lists users *who don't follow you back*. Unfollowing them doesn't change *that* status.
  // You likely ONLY need to call the Instagram unfollow API.
  // If you *also* track who *you* are following in your backend and want to remove them there too, use this.
  Future<bool> _removeFollowingFromBackend(String userId) async {
    // ***** VERIFY IF THIS ACTION IS NEEDED FOR THIS SCREEN *****
    // If your backend only tracks *followers*, this might not be necessary here.
    // If it tracks *who the logged-in user follows*, then it IS necessary.

    String url =
        "${AppConfig.baseUrl}api/remove-following/"; // Assuming this is the correct endpoint
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
          // Backend might expect 'user_id' or 'id' or 'pk' - match backend API spec
          "user_id": userId
        }),
      );

      print('Backend Remove Following Response Status: ${response.statusCode}');
      // print('Backend Remove Following Response Body: ${response.body}'); // Optional: Log for debug

      if (!mounted) return false;

      if (response.statusCode == 200 || response.statusCode == 204) {
        // 204 No Content is also success
        print(
            'Successfully removed following $userId from backend (if applicable).');
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
      print("Error calling backend remove-following API: $e");
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

  // Combined unfollow logic: Tries Instagram first, then backend (if needed)
  Future<void> _handleUnfollow(String userId, String username) async {
    // 1. Try unfollowing on Instagram
    bool instagramSuccess = await _unfollowUserOnInstagram(userId);

    if (!mounted) return; // Check if widget is still mounted

    if (instagramSuccess) {
      // 2. If Instagram unfollow succeeded, try removing from backend *if necessary*
      // Decide if backend removal is needed for this screen's logic.
      // For "Not Following Back", the primary action is IG unfollow.
      // Let's assume backend update IS desired for consistency across app lists.
      bool backendSuccess = await _removeFollowingFromBackend(userId);

      if (backendSuccess) {
        // 3. If both succeeded (or just IG if backend wasn't needed), update UI
        setState(() {
          _users.removeWhere((user) => user.id == userId);
          if (_totalUserCount > 0) {
            _totalUserCount--; // Decrement count
          }
        });
        // Show success overlay using the consistent style
        _showSuccessOverlay("User unfollowed successfully!");
      } else {
        // Backend removal failed, but IG succeeded.
        // Keep the user removed from the UI list as they *are* unfollowed on IG.
        setState(() {
          _users.removeWhere((user) => user.id == userId);
          if (_totalUserCount > 0) {
            _totalUserCount--; // Decrement count
          }
        });
        // Show a specific overlay or message indicating partial success?
        _showSuccessOverlay(
            "Unfollowed on Instagram!"); // Or show specific error SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to update backend records. Refresh may be needed later.'),
              backgroundColor: Colors.orange),
        );
      }
    } else {
      // Instagram unfollow failed, do nothing more. Error message already shown by _unfollowUserOnInstagram.
    }
  }

  // Refreshes the user list from scratch
  Future<void> _refreshUsers() async {
    // Use the initial fetch function which already resets state
    await _fetchInitialUsers();
  }

  // --- UI Elements (Adapted from UnfollowedYouScreen) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match background
      appBar: AppBar(
        // *** UPDATED AppBar Title ***
        title: Text("Not Following Back"), // Screen specific title
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5, // Match elevation
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUsers, // Use the refresh function
        child: _buildBody(),
      ),
    );
  }

  // --- Header Widget (Adapted) ---
  Widget _buildHeader() {
    if (_totalUserCount <= 0 && !_isLoading) return SizedBox.shrink();
    if (_isLoading) return SizedBox.shrink(); // Don't show during initial load

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
                    color: Colors.blue, // Or match target screen's color
                    fontWeight: FontWeight.bold),
              ),
              // *** UPDATED Header Text Context ***
              TextSpan(text: ' you follow who don\'t follow you back'),
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
                onPressed: _fetchInitialUsers, // Retry calls initial fetch
                child: Text("Retry"),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).primaryColor, // Use theme color
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // --- Empty State ---
    if (!_isLoading && _users.isEmpty && !_hasError) {
      // Use LayoutBuilder to ensure SingleChildScrollView fills height for pull-to-refresh
      return LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics:
              AlwaysScrollableScrollPhysics(), // Always allow scroll for refresh
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
                            .person_search_outlined, // Different icon relevant to "not found"
                        size: 60,
                        color: Colors.grey[400]),
                    SizedBox(height: 16),
                    // *** UPDATED Empty State Text ***
                    Text(
                      "No users found in this list.", // Clear message
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Everyone you follow seems to follow you back, or the list is empty.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Pull down to refresh.", // Refresh instruction
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
            thumbVisibility: true, // Make it visible
            thickness: 6.0,
            radius: Radius.circular(3.0),
            child: ListView.separated(
              // Use ListView.separated
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: _users.length +
                  (_isLoadingMore || _nextPageUrl != null
                      ? 1
                      : 0), // Count for loader
              itemBuilder: (context, index) {
                // --- Loading Indicator Logic ---
                if (index == _users.length) {
                  if (_isLoadingMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (_nextPageUrl != null) {
                    // Optionally show a small spacer if more can be loaded but isn't currently
                    return SizedBox(height: 40);
                  } else {
                    // No more data and not loading
                    return SizedBox.shrink();
                  }
                }

                // --- Build User List Item (Adapted Style) ---
                final user = _users[index];
                return ListTile(
                  // Match padding and style of UnfollowedYouScreen
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user.profilePicUrl),
                    radius: 24, // Match avatar size
                    backgroundColor: Colors.grey[200],
                  ),
                  title: Text.rich(
                    // Match title style with verified icon
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
                    // Match subtitle style
                    user.fullName.isNotEmpty
                        ? user.fullName
                        : ' ', // Handle empty name
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // --- Trailing Button (Use OutlinedButton style, but keep Unfollow action) ---
                  trailing: OutlinedButton(
                    // Use OutlinedButton styling
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Colors.redAccent, // Red for unfollow action
                      side: BorderSide(
                          color: Colors.red.shade100,
                          width: 1.0), // Lighter red border
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      // Call the unfollow confirmation dialog
                      _showUnfollowConfirmationDialog(user.id, user.username);
                    },
                    child: Text('Unfollow'), // Keep text as "Unfollow"
                  ),
                );
              },
              // --- Divider (Match style) ---
              separatorBuilder: (context, index) {
                // Avoid divider after the last actual item if loader is present
                if (index == _users.length - 1 &&
                    (_isLoadingMore || _nextPageUrl != null)) {
                  return SizedBox.shrink();
                }
                return Divider(
                  height: 1,
                  thickness: 1,
                  indent:
                      72.0, // Indent past avatar + padding (16 + 48 + 8 approx)
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

  // --- Confirmation Dialog (Styled like target, but for Unfollow action) ---
  Future<Future<Object?>> _showUnfollowConfirmationDialog(
      String userId, String username) async {
    // Use the same styled dialog as UnfollowedYouScreen
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) =>
          Container(), // Placeholder
      transitionBuilder: (context, a1, a2, widget) {
        // Use the same animations
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
                  // Match shape
                  borderRadius: BorderRadius.circular(16.0)),
              // Consistent Dialog Text - Adjusted for Unfollow context
              title: Text(
                // Keep title simple or add icon if desired
                'Unfollow ${username}?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              content: Text(
                // Adjust content text for unfollow action
                'Are you sure you want to unfollow $username on Instagram?',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              actionsPadding: // Match padding
                  EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  // Match Cancel button style
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.blueGrey, fontSize: 15)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  // Match Confirm button style (using red for unfollow)
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Red for unfollow confirm
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Unfollow', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    _handleUnfollow(
                        userId, username); // Call the UNFOLOW handler
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
    OverlayEntry? overlayEntry; // Make nullable
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        // Position like in UnfollowedYouScreen (top, centered)
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
} // End of _FollowedButNotFollowedBackScreenState

// --- Custom Success Message Overlay Widget (Should be identical to UnfollowedYouScreen's one) ---
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
    // Slide from top animation (matching UnfollowedYouScreen)
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
              // Use the *same* success color and style
              color: Color(0xFF00A98F), // Teal color from UnfollowedYouScreen
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
                // Use Flexible for long messages
                child: Text(
                  widget.message, // Display the passed message
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
