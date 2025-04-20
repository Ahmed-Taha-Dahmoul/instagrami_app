import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config.dart'; // Ensure this import points to your config file

class UnfollowedYouScreen extends StatefulWidget {
  @override
  _UnfollowedYouScreenState createState() => _UnfollowedYouScreenState();
}

class _UnfollowedYouScreenState extends State<UnfollowedYouScreen> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<User> _unfollowedUsers = [];
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
        _fetchUnfollowedUsers(); // Fetch initial data
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

  // Fetches the *first* page of users you unfollowed
  Future<void> _fetchUnfollowedUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _unfollowedUsers = [];
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
        Uri.parse('${AppConfig.baseUrl}api/get-unfollowed-you/'),
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
        _totalUserCount = data['count'] ?? data['total_count'] ?? 0;

        setState(() {
          _unfollowedUsers =
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
      print('Error fetching users you unfollowed: $e');
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
          _unfollowedUsers.addAll(
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
        setState(() {
          _nextPageUrl = null;
        }); // Stop trying
      }
    } catch (e) {
      print('Error loading more users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading more users.'),
              duration: Duration(seconds: 2)),
        );
        setState(() {
          _nextPageUrl = null;
        }); // Stop trying
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // Renamed for clarity: Hides user from this specific list
  Future<void> _hideUserFromList(String userId) async {
    // ***** USE CORRECT API ENDPOINT FOR REMOVING FROM *THIS* LIST *****
    String url = "${AppConfig.baseUrl}api/remove-unfollowed-you/";
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
        body: jsonEncode({
          "user_id": userId
        }), // Adjust key if backend expects something else
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _unfollowedUsers.removeWhere((user) => user.id == userId);
          if (_totalUserCount > 0) {
            _totalUserCount--;
          }
        });
        _showSuccessOverlay(
            "User hidden from this list."); // Use consistent success message
      } else {
        String errorMsg = "Failed to hide user. Status: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg +=
              ": ${errorData['detail'] ?? errorData['error'] ?? response.body}";
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
          SnackBar(
              content: Text("An error occurred: ${e.toString()}"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Renamed for clarity: Confirmation Dialog for Hiding
  Future<Future<Object?>> _showHideConfirmationDialog(
      String userId, String username) async {
    // Use the same styled dialog as before
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
              // Consistent Dialog Text
              title: Text(
                'Hide ${username}?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
              content: Text(
                'Are you sure you want to hide $username from this list?',
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
                    backgroundColor: Colors.orange, // Orange for hide action
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Hide', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _hideUserFromList(userId); // Call the correct hide function
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        // *** UPDATED AppBar Title ***
        title: Text("Users Unfollowed You"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUnfollowedUsers,
        child: _buildBody(),
      ),
    );
  }

  // --- Header Widget ---
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
                    color: Colors.blue,
                    fontWeight: FontWeight.bold), // Use blue or another color?
              ),
              // *** UPDATED Header Text Context ***
              TextSpan(text: ' who unfollowed you recently'),
            ],
          ),
        ),
      ),
    );
  }

  // --- Body Builder ---
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
                onPressed: _fetchUnfollowedUsers,
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
    if (!_isLoading && _unfollowedUsers.isEmpty && !_hasError) {
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
                    Icon(Icons.person_remove_outlined,
                        size: 60, color: Colors.grey[400]), // Different Icon
                    SizedBox(height: 16),
                    // *** UPDATED Empty State Text ***
                    Text(
                      "No users found in this list.",
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
        _buildHeader(),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            thickness: 6.0,
            radius: Radius.circular(3.0),
            child: ListView.separated(
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(),
              itemCount: _unfollowedUsers.length +
                  (_isLoadingMore || _nextPageUrl != null ? 1 : 0),
              itemBuilder: (context, index) {
                // --- Loading Indicator Logic ---
                if (index == _unfollowedUsers.length) {
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

                // --- Build User List Item ---
                final user = _unfollowedUsers[index];
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
                  // --- Trailing Button (Using same style as requested) ---
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      _showHideConfirmationDialog(user.id, user.username);
                    },
                    // NOTE: Text kept as "Unfollow" to match UI request, but action is "Hide".
                    child: Text('Unfollow'),
                  ),
                );
              },
              // --- Divider ---
              separatorBuilder: (context, index) {
                if (index == _unfollowedUsers.length - 1 &&
                    (_isLoadingMore || _nextPageUrl != null)) {
                  return SizedBox.shrink();
                }
                return Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16.0,
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

  // --- Success Overlay ---
  void _showSuccessOverlay(String message) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: SuccessMessageOverlay(
              // Use the same reusable overlay
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
    Overlay.of(context).insert(overlayEntry!);
  }
} // End of _UnfollowedYouScreenState

// --- User Data Model --- (Should be identical)
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
    T? _safeCast<T>(dynamic value) => value is T ? value : null;
    return User(
      id: _safeCast<int>(json['id'])?.toString() ??
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

// --- Custom Success Message Overlay Widget --- (Should be identical)
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
    _slideAnimation = Tween<Offset>(begin: Offset(0.0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeOutBack)); // Slide from top
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
              color: Color(0xFF00A98F), // Keep consistent color
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
