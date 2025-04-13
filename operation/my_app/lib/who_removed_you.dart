import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart'; // Ensure this import points to your config file




class WhoRemovedYouScreen extends StatefulWidget {
  @override
  _WhoRemovedYouScreenState createState() => _WhoRemovedYouScreenState();
}

class _WhoRemovedYouScreenState extends State<WhoRemovedYouScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _unfollowedUsers = [];
  bool _isLoading = true; // For initial load or refresh
  bool _isLoadingMore = false; // For loading subsequent pages
  bool _hasError = false;
  String _errorMessage = '';
  String? _nextPageUrl; // URL for the next page of results
  int _totalUserCount = 0; // Total number of users who unfollowed

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add listener to scroll controller for pagination trigger
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchUnfollowedUsers(); // Fetch initial data
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener); // Remove listener
    _scrollController.dispose();
    super.dispose();
  }

  // Listener to detect when user scrolls near the bottom
  void _scrollListener() {
    // Check if near bottom, not already loading more, and there is a next page URL
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 && // 90% threshold
        !_isLoadingMore &&
        _nextPageUrl != null) {
       if (mounted) {
          _loadMoreUsers();
       }
    }
  }

  // Fetches the *first* page of users or refreshes the list
  Future<void> _fetchUnfollowedUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Show initial loading indicator
      _hasError = false;
      _errorMessage = '';
      _unfollowedUsers = []; // Clear existing users on refresh/initial load
      _nextPageUrl = null; // Reset next page URL
      _totalUserCount = 0; // Reset total count
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        throw Exception('Access token not found. Please log in again.');
      }

      // Use the base URL for the initial fetch
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}api/get-who-removed-you/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // --- Parse Paginated Data ---
        List<dynamic> usersJson = data['results'] ?? [];
        _nextPageUrl = data['next']; // Get the URL for the next page
        _totalUserCount = data['count'] ?? data['total_count'] ?? 0; // Use 'count' or 'total_count'
        // --- End Parse ---

        setState(() {
          _unfollowedUsers = usersJson
              .map((userJson) => User.fromJson(userJson))
              .toList();
          _isLoading = false; // Hide initial loading indicator
        });
      } else {
          String errorBody = response.body;
          try {
             final errorData = json.decode(response.body);
             errorBody = errorData['detail'] ?? errorData['error'] ?? response.body;
          } catch(_) {}
          throw Exception('Failed to fetch data. Status: ${response.statusCode}, Response: $errorBody');
      }
    } catch (e) {
      print('Error fetching unfollowed users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide initial loading indicator even on error
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
      _isLoadingMore = true; // Show loading indicator at the bottom
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
          _unfollowedUsers.addAll(
            usersJson.map((userJson) => User.fromJson(userJson)).toList()
          );
          _nextPageUrl = nextPageFromResponse; // Update the next page URL
        });
      } else {
        print('Failed to load more data. Status: ${response.statusCode}, Body: ${response.body}');
         ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Could not load more users.'), duration: Duration(seconds: 2)),
         );
         setState(() {
           _nextPageUrl = null; // Stop trying on error
         });
      }
    } catch (e) {
      print('Error loading more users: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error loading more users.'), duration: Duration(seconds: 2)),
          );
          setState(() {
            _nextPageUrl = null; // Stop trying on error
          });
       }
    } finally {
       if (mounted) {
          setState(() {
             _isLoadingMore = false;
          });
       }
    }
  }


  // --- Backend Action: Hide user from this list ---
  Future<void> _hideUserFromList(String userId) async {
    String url = "${AppConfig.baseUrl}api/remove-removed-you/";
    String? token = await _secureStorage.read(key: 'access_token');

    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error. Please log in again.')),
        );
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"user_id": userId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          // Remove user locally
          _unfollowedUsers.removeWhere((user) => user.id == userId);
          // Decrement total count for the header
          if (_totalUserCount > 0) {
            _totalUserCount--;
          }
        });
        _showSuccessOverlay("User hidden from this list.");
      } else {
        String errorMsg = "Failed to hide user. Status: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg += ": ${errorData['detail'] ?? errorData['error'] ?? response.body}";
        } catch (_) {}
        print("Backend remove error: $errorMsg");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print("Error hiding user from list: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Confirmation Dialog ---
  Future<Future<Object?>> _showHideConfirmationDialog(String userId, String username) async {
     return showGeneralDialog(
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
                    title: Text(
                        'Hide ${username}?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                    ),
                    content: Text(
                        'Are you sure you want to hide $username from this list?',
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
                              backgroundColor: Colors.orange, // Keep orange for hide confirmation
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text('Hide', style: TextStyle(fontSize: 15)),
                          onPressed: () {
                              Navigator.of(context).pop();
                              _hideUserFromList(userId); // Calls the hide function
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background for the screen
      appBar: AppBar(
        title: Text("Who Unfollowed You"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87, // Dark text for title
        elevation: 0.5, // Subtle shadow below AppBar
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87), // Standard back arrow
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUnfollowedUsers, // Trigger initial fetch on pull-to-refresh
        child: _buildBody(),
      ),
    );
  }

  // --- Header Widget (with Alignment) ---
  Widget _buildHeader() {
    // Use _totalUserCount for display, show only if > 0 and not loading initial data
    if (_totalUserCount <= 0 && !_isLoading) return SizedBox.shrink();
    if (_isLoading) return SizedBox.shrink(); // Don't show during initial load

    // ***** WRAP with Align for left alignment *****
    return Align(
      alignment: Alignment.centerLeft, // Force content to the left
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            children: <TextSpan>[
              TextSpan(
                // Use _totalUserCount here
                text: '$_totalUserCount user${_totalUserCount != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold), // Highlight count
              ),
              TextSpan(text: ' unfollowed you recently'),
            ],
          ),
        ),
      ),
    );
  }


  // --- Body Builder (with Button and Divider updates) ---
  Widget _buildBody() {
    // --- Initial Loading State ---
    if (_isLoading && _unfollowedUsers.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    // --- Error State ---
    if (_hasError && _unfollowedUsers.isEmpty) {
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
                onPressed: _fetchUnfollowedUsers, // Retry button
                child: Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- Empty State ---
    if (!_isLoading && _unfollowedUsers.isEmpty && !_hasError) {
        return LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(), // Allow pull-to-refresh
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_disabled_outlined, size: 60, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        "No recent unfollowers found.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
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

    // --- Data Loaded State (List View) ---
    return Column(
      children: [
        _buildHeader(), // Header is now left-aligned
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 6.0,
            radius: Radius.circular(3.0),
            child: ListView.separated(
              controller: _scrollController, // Important for pagination trigger
              physics: AlwaysScrollableScrollPhysics(), // Needed for RefreshIndicator
              // Add 1 to item count if we are loading more or have a next page URL
              itemCount: _unfollowedUsers.length + (_isLoadingMore || _nextPageUrl != null ? 1 : 0),
              itemBuilder: (context, index) {
                // --- Loading Indicator Logic ---
                if (index == _unfollowedUsers.length) {
                   if (_isLoadingMore) {
                      // Currently loading more: Show spinner
                      return Padding(
                         padding: const EdgeInsets.symmetric(vertical: 16.0),
                         child: Center(child: CircularProgressIndicator()),
                      );
                   } else if (_nextPageUrl != null) {
                      // Not currently loading, but there IS a next page.
                      // Show empty space at the bottom.
                      return SizedBox(height: 40);
                   } else {
                      // Should not happen if itemCount logic is correct.
                      return SizedBox.shrink();
                   }
                }

                // --- Build User List Item ---
                final user = _unfollowedUsers[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  leading: CircleAvatar(
                    // Consider adding errorBuilder for NetworkImage
                    backgroundImage: NetworkImage(user.profilePicUrl),
                    radius: 24,
                    backgroundColor: Colors.grey[200], // Placeholder color
                  ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: user.username,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (user.isVerified) // Add verified badge if applicable
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle, // Align icon nicely
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.verified, color: Colors.blue, size: 16),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user.fullName.isNotEmpty ? user.fullName : ' ', // Show full name or empty space
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // ***** UPDATED TRAILING BUTTON STYLE *****
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87, // Standard dark text color
                      side: BorderSide(color: Colors.grey.shade300, width: 1.0), // Lighter grey border
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0), // Rounded corners
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Button padding
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap area slightly
                    ),
                    onPressed: () {
                      // Show confirmation before hiding
                      _showHideConfirmationDialog(user.id, user.username);
                    },
                    child: Text('Unfollow'), // Text matches the desired UI
                  ),
                );
              },
              // ***** UPDATED SEPARATOR BUILDER STYLE *****
              separatorBuilder: (context, index) {
                 // Avoid adding a divider after the last actual user item if loading indicator/placeholder is shown
                 if (index == _unfollowedUsers.length - 1 && (_isLoadingMore || _nextPageUrl != null)) {
                   return SizedBox.shrink(); // No divider before the final element
                 }
                 return Divider(
                   height: 1, // Minimal height
                   thickness: 1, // Standard thickness
                   // Indent aligns divider with content start/end
                   indent: 16.0, // Match ListTile content padding start
                   endIndent: 16.0, // Match ListTile content padding end
                   color: Colors.grey[200], // Subtle divider color
                 );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Success Overlay ---
  void _showSuccessOverlay(String message) {
      OverlayEntry? overlayEntry;

      overlayEntry = OverlayEntry(
         builder: (context) => Positioned(
            // Positioned near the top, below the AppBar
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
            left: 0,
            right: 0,
            child: Align(
               alignment: Alignment.center,
               child: Material(
                  color: Colors.transparent,
                  child: SuccessMessageOverlay( // Reusable success message widget
                     message: message,
                     onClose: () {
                        overlayEntry?.remove();
                        overlayEntry = null;
                     },
                  ),
               ),
            ),
         ),
      );
      // Insert the overlay into the overlay stack.
      Overlay.of(context).insert(overlayEntry!);
   }

} // End of _WhoRemovedYouScreenState

// --- User Data Model ---
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

  // Factory constructor for creating a new User instance from a map.
  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function for safely casting dynamic values.
    T? _safeCast<T>(dynamic value) => value is T ? value : null;

    // Return a new User instance, handling potential nulls and type mismatches.
    return User(
      // Safely handle ID which might be int or string in JSON.
      id: _safeCast<int>(json['id'])?.toString() ?? _safeCast<String>(json['id']) ?? '',
      username: _safeCast<String>(json['username']) ?? 'Unknown User', // Default if null
      fullName: _safeCast<String>(json['full_name']) ?? '', // Default if null
      isPrivate: _safeCast<bool>(json['is_private']) ?? false, // Default if null
      isVerified: _safeCast<bool>(json['is_verified']) ?? false, // Default if null
      // Provide a default placeholder image URL if profile pic URL is missing or null.
      profilePicUrl: _safeCast<String>(json['profile_pic_url']) ??
                     'https://via.placeholder.com/150/CCCCCC/FFFFFF?text=?',
    );
  }
}

// --- Custom Success Message Overlay Widget ---
class SuccessMessageOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final String message;

  SuccessMessageOverlay({
    required this.onClose,
    required this.message,
  });

  @override
  _SuccessMessageOverlayState createState() => _SuccessMessageOverlayState();
}

class _SuccessMessageOverlayState extends State<SuccessMessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer; // Timer to auto-dismiss the overlay

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: Duration(milliseconds: 400), // Animation duration
    );
    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    // Slide animation (from top)
    _slideAnimation = Tween<Offset>(begin: Offset(0.0, -1.5), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );
    _controller.forward(); // Start the animation

    // Set a timer to automatically close the overlay after 3 seconds
    _timer = Timer(Duration(seconds: 3), () {
      if (mounted) {
         // Reverse the animation before closing
         _controller.reverse().then((_) {
           if (mounted) { widget.onClose(); } // Call the onClose callback
         });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer if the widget is disposed
    _controller.dispose(); // Dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apply fade and slide transitions
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          // Styling for the overlay container
          margin: EdgeInsets.symmetric(horizontal: 20), // Horizontal margin
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Inner padding
          decoration: BoxDecoration(
            color: Color(0xFF00A98F), // Custom green color
            borderRadius: BorderRadius.circular(10), // Rounded corners
            boxShadow: [ // Subtle shadow for depth
              BoxShadow( color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: Offset(0, 3),)
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Fit content size horizontally
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 22), // Check icon
              SizedBox(width: 10), // Spacing between icon and text
              Flexible( // Allow text to wrap if too long
                child: Text(
                  widget.message, // Display the success message
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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