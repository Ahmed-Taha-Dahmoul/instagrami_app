import 'dart:async'; // Added for Timer in SuccessOverlay if needed later
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
  bool _isLoading = true; // Start loading initially
  bool _hasError = false;
  String _errorMessage = ''; // Store specific error message

  // Add ScrollController even if not used for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch users when the screen initializes
    // Using addPostFrameCallback to avoid issues if fetch completes instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) {
          _fetchUnfollowedUsers();
       }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }

  // Fetches the list of users who unfollowed you
  Future<void> _fetchUnfollowedUsers() async {
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = ''; // Clear previous error
    });

    try {
      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
         throw Exception('Access token not found. Please log in again.');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}api/get-who-removed-you/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return; // Check again after await

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Assuming 'results' is the key containing the list
        List<dynamic> usersJson = data['results'] ?? [];

        setState(() {
          _unfollowedUsers = usersJson
              .map((userJson) => User.fromJson(userJson))
              .toList();
          _isLoading = false;
        });
      } else {
         // Throw exception with more details
         throw Exception('Failed to fetch data. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching unfollowed users: $e');
      if (mounted) {
         setState(() {
           _isLoading = false;
           _hasError = true;
           _errorMessage = e.toString(); // Store the error message
         });
      }
    }
    // No finally block needed for setting isLoading = false here,
    // as it's handled in both success and error paths within mounted checks.
  }

  // Removes a user from the 'who unfollowed you' list (backend action)
  Future<void> _removeUserFromList(String userId) async {
    String url = "${AppConfig.baseUrl}api/remove-removed-you/";
    String? token = await _secureStorage.read(key: 'access_token');

    if (token == null) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Authentication error. Please log in again.')),
          );
      }
      return; // Exit early
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        // Ensure backend expects 'user_id' key
        body: jsonEncode({"user_id": userId}),
      );

       if (!mounted) return; // Check after await

      if (response.statusCode == 200 || response.statusCode == 204) { // 204 No Content is also success
        setState(() {
          // Remove user locally for immediate UI update
          _unfollowedUsers.removeWhere((user) => user.id == userId);
        });
        // Show success feedback (using custom overlay or SnackBar)
         _showSuccessOverlay("User removed from this list.");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("User removed from this list."), backgroundColor: Colors.green),
        // );
      } else {
         // Try to parse backend error
         String errorMsg = "Failed to remove user. Status: ${response.statusCode}";
         try {
            final errorData = json.decode(response.body);
            errorMsg += ": ${errorData['detail'] ?? errorData['error'] ?? response.body}";
         } catch (_) {
            // Keep the basic error message if parsing fails
         }
         print("Backend remove error: $errorMsg");
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
         );
      }
    } catch (e) {
      print("Error removing user from list: $e");
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("An error occurred: ${e.toString()}"), backgroundColor: Colors.red),
          );
      }
    }
  }

  // Confirmation Dialog
  Future<Future<Object?>> _showRemoveConfirmationDialog(String userId, String username) async {
    // Using the consistent AlertDialog style from previous examples
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
              title: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
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
                'Are you sure you want to remove $username from this list? This action cannot be undone.',
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
                    backgroundColor: Colors.red, // Keep red for removal confirmation
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text('Remove', style: TextStyle(fontSize: 15)),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog first
                    _removeUserFromList(userId); // Call the backend removal function
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
      appBar: AppBar(
        title: Text("Who Unfollowed You"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1.0,
      ),
      body: RefreshIndicator( // Added RefreshIndicator
        onRefresh: _fetchUnfollowedUsers, // Calls fetch function on pull
        child: _buildBody(), // Delegate body building
      ),
    );
  }

  // Helper method to build the main body content
  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Error state
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 50),
              SizedBox(height: 16),
              Text(
                "Failed to load data",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                 _errorMessage, // Show specific error
                 style: TextStyle(color: Colors.grey[600]),
                 textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchUnfollowedUsers, // Retry button
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (_unfollowedUsers.isEmpty) {
      // Make sure it's scrollable for RefreshIndicator
      return LayoutBuilder(builder: (context, constraints) {
         return SingleChildScrollView(
           physics: AlwaysScrollableScrollPhysics(),
           child: ConstrainedBox(
             constraints: BoxConstraints(minHeight: constraints.maxHeight),
             child: Center(
               child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Text(
                   "No one has unfollowed you recently,\nor the list has been cleared.\nPull down to refresh.",
                   textAlign: TextAlign.center,
                   style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                 ),
               ),
             ),
           ),
         );
      });
    }

    // Data loaded state - List view with Scrollbar
    return Scrollbar( // ***** WRAP WITH SCROLLBAR *****
      controller: _scrollController, // ** Link the controller **
      thumbVisibility: true, // ** Make scrollbar always visible **
      thickness: 8.0,
      radius: Radius.circular(4.0),
      child: ListView.builder(
        controller: _scrollController, // ** Keep controller here too **
        physics: AlwaysScrollableScrollPhysics(), // Ensure refresh works
        itemCount: _unfollowedUsers.length,
        itemBuilder: (context, index) {
          final user = _unfollowedUsers[index];
          return Card( // Use Card for better styling
             margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
             elevation: 1.5,
             child: ListTile(
               contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               leading: Stack( // Stack for verified badge
                 alignment: Alignment.bottomRight,
                 children: [
                   CircleAvatar(
                     backgroundImage: NetworkImage(user.profilePicUrl),
                     radius: 25,
                     backgroundColor: Colors.grey[200], // Placeholder color
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
               trailing: Tooltip( // Add tooltip for clarity
                 message: "Remove ${user.username} from this list",
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.redAccent, // Slightly softer red
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(20.0), // Pill shape
                     ),
                     padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                     elevation: 1.0,
                   ),
                   onPressed: () {
                     _showRemoveConfirmationDialog(user.id, user.username);
                   },
                   child: Icon(Icons.delete_sweep_outlined, size: 20), // Use an icon? Or Text('Remove')
                   // child: Text('Remove'),
                 ),
               ),
             ),
           );
        },
      ),
    );
  }

  // Show the custom success overlay message (using the reusable widget)
  void _showSuccessOverlay(String message) {
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
              child: SuccessMessageOverlay( // Use the reusable overlay
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

    // Ensure Overlay is available before inserting
    Overlay.of(context).insert(overlayEntry!);
    }

}

// --- User Data Model ---
// Added null checks and ensured ID is string
class User {
  final String id;
  final String username;
  final String fullName;
  final bool isPrivate; // Included but not currently used in UI
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
      id: json['id']?.toString() ?? '', // Ensure ID is string and handle null
      username: json['username'] ?? 'Unknown User',
      fullName: json['full_name'] ?? '', // Handle potential null full name
      isPrivate: json['is_private'] ?? false, // Default to false if null
      isVerified: json['is_verified'] ?? false, // Default to false if null
      profilePicUrl: json['profile_pic_url'] ?? '', // Provide default or handle missing URL
    );
  }
}


// --- Custom Success Message Overlay Widget --- (Same reusable one as before)
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, duration: Duration(milliseconds: 400),
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
           if (mounted) { widget.onClose(); }
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
            boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: Offset(0, 4),) ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                widget.message,
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}