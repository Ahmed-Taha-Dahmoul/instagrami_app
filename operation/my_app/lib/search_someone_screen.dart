import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'search_someone_api_service.dart'; // Your existing API service
import 'dart:async'; // For Timer (if needed for dialogs)

// --- Define Colors (Matching the target image and previous styles) ---
const Color primaryBlue =
    Color(0xFF3897F0); // From other screens, used for focus highlight
const Color selectButtonColor =
    Color(0xFFE83E8C); // Pink/Magenta button from image
const Color lightGreyBackground =
    Color(0xFFF8F9FA); // Very light grey for overall background
const Color whiteBackground = Colors.white; // For cards and AppBar
const Color borderColor = Color(0xFFE0E0E0); // Border for search input
const Color darkGreyText = Color(0xFF262626); // For titles, usernames
const Color mediumGreyText =
    Color(0xFF757575); // For subtitle text, results count, private indicator
const Color lightGreyText = Color(0xFF9E9E9E); // Lighter grey for hints
// ---

class SearchSomeoneScreen extends StatefulWidget {
  const SearchSomeoneScreen({super.key});

  @override
  _SearchSomeoneScreenState createState() => _SearchSomeoneScreenState();
}

class _SearchSomeoneScreenState extends State<SearchSomeoneScreen>
    with SingleTickerProviderStateMixin {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false; // For loading followers/following AFTER selection
  bool _isDataLoaded = false; // True when followers/following are loaded
  bool _isSearchLoading = false; // Specifically for the search API call
  List<Map<String, dynamic>> _followedUsers = [];
  List<Map<String, dynamic>> _followerUsers = [];
  late TabController _tabController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- API Calls and Data Handling (Keep your existing logic) ---
  Future<void> performSearch() async {
    FocusScope.of(context).unfocus();
    if (_searchController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _isSearchLoading = true;
      _errorMessage = null;
      _isDataLoaded = false;
      _followedUsers = [];
      _followerUsers = [];
      _searchResults = [];
    });
    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');
    if (user1Id == null ||
        csrftoken == null ||
        sessionId == null ||
        xIgAppId == null) {
      if (mounted)
        setState(() {
          _isSearchLoading = false;
          _errorMessage = "Authentication error.";
        });
      return;
    }
    try {
      List<Map<String, dynamic>> results =
          await SearchSomeoneApiService.instagramSearch(
              _searchController.text, user1Id, csrftoken, sessionId, xIgAppId);
      if (mounted)
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isSearchLoading = false;
          _errorMessage = "Search failed: $e";
        });
    }
  }

  void _selectUser(Map<String, dynamic> user) async {
    bool isPrivate = user['is_private'] ?? false;
    bool isFollowing = user['following'] ?? false;
    if (isPrivate && !isFollowing) {
      _showPrivateAccountDialog(user['username'] ?? 'this user');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDataLoaded = false;
      _searchResults = [];
    }); // Clear search results when loading selected user
    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');
    if (user1Id == null ||
        csrftoken == null ||
        sessionId == null ||
        xIgAppId == null) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = "Authentication error.";
        });
      return;
    }
    String userAgent = SearchSomeoneApiService.generateRandomUserAgent();
    String userPk = user['pk']?.toString() ?? '';
    if (userPk.isEmpty) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = "Selected user has no valid ID.";
        });
      return;
    }
    try {
      final followingData =
          await SearchSomeoneApiService.fetchInstagramFollowing(
              userPk, user1Id, 50, sessionId, csrftoken, xIgAppId, userAgent);
      final followerData =
          await SearchSomeoneApiService.fetchInstagramFollowers(
              userPk, user1Id, 50, sessionId, csrftoken, xIgAppId, userAgent);
      List<Map<String, dynamic>> followingUsers =
          _extractUsers(followingData, 'edge_follow');
      List<Map<String, dynamic>> followerUsers =
          _extractUsers(followerData, 'edge_followed_by');
      if (mounted)
        setState(() {
          _followedUsers = followingUsers;
          _followerUsers = followerUsers;
          _isDataLoaded = true;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to fetch data: $e";
        });
    }
  }

  List<Map<String, dynamic>> _extractUsers(
      Map<String, dynamic> data, String edgeKey) {
    List<Map<String, dynamic>> users = [];
    if (data.containsKey('data') &&
        data['data'].containsKey('user') &&
        data['data']['user'].containsKey(edgeKey)) {
      var edges = data['data']['user'][edgeKey]['edges'];
      if (edges is List) {
        for (var edge in edges) {
          if (edge is Map && edge.containsKey('node')) {
            var node = edge['node'];
            if (node is Map<String, dynamic>) {
              users.add(node);
            }
          }
        }
      }
    }
    return users;
  }

  void _showPrivateAccountDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Private Account"),
        content: Text(
            "You need to follow @$username to access their profile details."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          lightGreyBackground, // Use very light grey for the main background
      // --- AppBar ---
      appBar: AppBar(
        title: const Text('Profile Checker',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: darkGreyText,
                fontSize: 18)),
        backgroundColor: whiteBackground, // White AppBar
        foregroundColor: darkGreyText, // Dark icon/text color
        elevation: 1.0, // Line below AppBar
        centerTitle: true, // Centered title
        leading: IconButton(
          // Explicit back button
          icon: const Icon(Icons.arrow_back, color: darkGreyText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // --- Body ---
      body: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align count header left
          children: [
            // --- Search Input ---
            // Always show search bar unless followers/following data is loaded
            if (!_isDataLoaded) _buildSearchInputNew(),

            // --- Conditional Content Area ---
            Expanded(
              child: _buildContentArea(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper to build the main content area below search ---
  Widget _buildContentArea() {
    // Show loading indicator for the search API call
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Show loading indicator while fetching followers/following
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Show error message if any occurred
    if (_errorMessage != null) {
      return _buildErrorMessage();
    }
    // Show Tabs and follower/following lists if data IS loaded
    if (_isDataLoaded) {
      return Column(
        children: [
          _buildTabBar(), // Your existing tab bar
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildUserList(_followedUsers, "Not following anyone."),
                _buildUserList(_followerUsers, "No followers found."),
              ],
            ),
          ),
        ],
      );
    }
    // Show search results if available
    if (_searchResults.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResultsCountHeader(), // Show count above list
          // Needs Expanded here if it's the primary scrolling content
          Expanded(child: _buildSearchResultsNew()), // Show results list
        ],
      );
    }
    // Show "No results" state if search was performed but found nothing
    if (_searchController.text.isNotEmpty) {
      return _buildNoResultsState();
    }
    // Show initial "Enter username" state
    return _buildEmptySearchStateNew();
  }

  // --- Search Input Widget (Style matches image) ---
  Widget _buildSearchInputNew() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => performSearch(),
        style: const TextStyle(fontSize: 15), // Control input text style
        decoration: InputDecoration(
          hintText: 'Enter Instagram username',
          hintStyle: const TextStyle(color: lightGreyText, fontSize: 15),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search,
                color: mediumGreyText), // Use grey for icon
            onPressed: performSearch,
            splashRadius: 20, // Reduce splash effect area
          ),
          filled: true,
          fillColor: whiteBackground, // White field background
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            // Default border
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: borderColor, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            // Border when enabled
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: borderColor, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            // Border when focused
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(
                color: primaryBlue, width: 1.5), // Highlight with blue
          ),
        ),
      ),
    );
  }

  // --- Results Count Header ---
  Widget _buildResultsCountHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 10.0, top: 4.0),
      child: Text(
        "${_searchResults.length} ${_searchResults.length == 1 ? 'profile' : 'profiles'} found",
        style: const TextStyle(
            color: mediumGreyText, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // --- Search Results List Widget (UPDATED for Private Indicator) ---
  Widget _buildSearchResultsNew() {
    // Removed Expanded from here, handled by parent Column in _buildContentArea
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 0), // Adjust vertical padding if needed
      itemCount: _searchResults.length,
      // shrinkWrap: true, // Only use if parent Column isn't Expanded and causes issues
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final profilePicUrl = user['profile_pic_url'] ?? '';
        final username = user['username'] ?? 'Unknown';
        final fullName = user['full_name'] ?? '';
        final bool isPrivate = user['is_private'] ?? false; // Get the flag

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 1.5,
          shadowColor: Colors.grey.withOpacity(0.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          clipBehavior: Clip.antiAlias,
          color: whiteBackground,
          child: ListTile(
            contentPadding: const EdgeInsets.only(
                left: 12.0, right: 10.0, top: 8.0, bottom: 8.0),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              backgroundImage:
                  profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
              child: profilePicUrl.isEmpty
                  ? const Icon(Icons.person, size: 28, color: Colors.grey)
                  : null,
            ),
            title: RichText(
              // Use RichText for conditional styling
              text: TextSpan(
                // Use default text style from theme or define explicitly
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 15, color: darkGreyText),
                children: [
                  TextSpan(
                      text: '@$username',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)), // Bold username
                  if (isPrivate) // Conditionally add Private text
                    const TextSpan(
                      text: ' (Private)',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: mediumGreyText, // Grey color for indicator
                        fontSize: 13, // Slightly smaller
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              fullName,
              style: const TextStyle(color: mediumGreyText, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ElevatedButton(
              onPressed: () => _selectUser(user),
              style: ElevatedButton.styleFrom(
                  backgroundColor: selectButtonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              child: const Text("Select"),
            ),
          ),
        );
      },
    );
  }

  // --- TabBar and UserList (Keep your existing implementation) ---
  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[100],
      child: TabBar(
        controller: _tabController,
        indicatorColor: primaryBlue,
        labelColor: primaryBlue,
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(text: 'Following'),
          Tab(text: 'Followers'),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(emptyMessage, style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }
    return ListView.separated(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Divider(
          color: Colors.grey[300],
          height: 1,
          thickness: 0.5,
        ),
      ),
      itemBuilder: (context, index) {
        final user = users[index];
        final profilePicUrl = user['profile_pic_url'] ?? '';
        final username = user['username'] ?? 'Unknown';
        final fullName = user['full_name'] ?? '';
        final isPrivate = user['is_private'] ?? false;
        return ListTile(
          leading: profilePicUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(profilePicUrl),
                )
              : const CircleAvatar(
                  radius: 24, child: Icon(Icons.person, size: 28)),
          title: Text(username,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('$fullName ${isPrivate ? '(Private)' : ''}',
              style: TextStyle(color: Colors.grey[600])),
        );
      },
    );
  }

  // --- Error Message Widget ---
  Widget _buildErrorMessage() {
    return Center(
      // Center error message
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red[600]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // --- Initial Empty State Widget ---
  Widget _buildEmptySearchStateNew() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Enter an Instagram username above\nto find profiles.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- No Results State Widget ---
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "No profiles found for '${_searchController.text}'.\nTry a different username.",
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- SnackBar Helpers ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
} // End of _SearchSomeoneScreenState
