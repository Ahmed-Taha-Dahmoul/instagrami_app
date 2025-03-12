import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'search_someone_api_service.dart';

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
  bool _isLoading = false;
  bool _isDataLoaded = false;
  bool _isSearchLoading = false; // Separate loading state for initial search
  List<Map<String, dynamic>> _followedUsers = [];
  List<Map<String, dynamic>> _followerUsers = [];
  late TabController _tabController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  Future<void> performSearch() async {
    setState(() {
      _isSearchLoading = true; // Set search-specific loading state
      _errorMessage = null;
      _isDataLoaded = false;
      _followedUsers = [];
      _followerUsers = [];
      _searchResults =
          []; // Clear results *before* starting the search, crucial for UX
    });

    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');

    if (user1Id == null ||
        csrftoken == null ||
        sessionId == null ||
        xIgAppId == null) {
      setState(() {
        _isSearchLoading = false; // Reset search-specific loading state
        _errorMessage = "Authentication error. Please log in again.";
      });
      return;
    }

    try {
      List<Map<String, dynamic>> results =
          await SearchSomeoneApiService.instagramSearch(
        _searchController.text,
        user1Id,
        csrftoken,
        sessionId,
        xIgAppId,
      );
      setState(() {
        _searchResults = results;
        _isSearchLoading =
            false; // Reset search-specific loading state after success
      });
    } catch (e) {
      setState(() {
        _isSearchLoading = false; // Reset search-specific loading state on error
        _errorMessage = "Search failed: $e";
      });
    }
  }

  void _selectUser(Map<String, dynamic> user) async {
    setState(() {
      _isLoading =
          true; // This is for loading followers/following, separate from search loading
      _errorMessage = null;
      _isDataLoaded = false;
      _searchResults = [];
    });

    bool isPrivate = user['is_private'] ?? false;
    bool isFollowing = user['following'] ?? false;

    if (isPrivate && !isFollowing) {
      setState(() {
        _isLoading = false;
      });
      _showPrivateAccountDialog(user['username'] ?? 'this user');
      return;
    }

    String? user1Id = await _secureStorage.read(key: 'user1_id');
    String? csrftoken = await _secureStorage.read(key: 'csrftoken');
    String? sessionId = await _secureStorage.read(key: 'session_id');
    String? xIgAppId = await _secureStorage.read(key: 'x_ig_app_id');

    if (user1Id == null ||
        csrftoken == null ||
        sessionId == null ||
        xIgAppId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Authentication error. Please log in again.";
      });
      return;
    }

    String userAgent = SearchSomeoneApiService.generateRandomUserAgent();
    String userPk = user['pk']?.toString() ?? '';
    if (userPk.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Selected user has no valid ID.";
      });
      return;
    }
  

    try {
      final followingData =
          await SearchSomeoneApiService.fetchInstagramFollowing(
        userPk,
        user1Id,
        50,
        sessionId,
        csrftoken,
        xIgAppId,
        userAgent,
      );

      final followerData =
          await SearchSomeoneApiService.fetchInstagramFollowers(
        userPk,
        user1Id,
        50,
        sessionId,
        csrftoken,
        xIgAppId,
        userAgent,
      );

      List<Map<String, dynamic>> followingUsers =
          _extractUsers(followingData, 'edge_follow');
      List<Map<String, dynamic>> followerUsers =
          _extractUsers(followerData, 'edge_followed_by');

      setState(() {
        _followedUsers = followingUsers;
        _followerUsers = followerUsers;
        _isDataLoaded = true;
        _isLoading = false;
        //_searchResults = [];  // Clear search results - already done at the start of _selectUser
      });
    } catch (e) {
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
        content: Text("You need to follow $username to access their profile."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search People',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isDataLoaded) ...[
              _buildSearchInput(),
              const SizedBox(height: 16),
            ],
            if (_isSearchLoading) ...[
              // Show search loading indicator *instead* of search results
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_searchResults.isNotEmpty) ...[
              _buildSearchResults(), // Show search results only if not loading
            ] else if (!_isDataLoaded &&
                !_isSearchLoading &&
                _searchController.text.isEmpty) ...[
              _buildEmptySearchState(),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Expanded(
                // Expand to take up available space
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              _buildErrorMessage(),
            ] else if (_isDataLoaded) ...[
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildUserList(_followedUsers, "No users following."),
                    _buildUserList(_followerUsers, "No followers."),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for users...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchResults =
                                []; // Clear results when clearing input
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none, // Remove border
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (_) => performSearch(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSearchLoading
                ? null
                : performSearch, // Disable button during search
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: _isSearchLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.blue[100],
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue[800],
        labelColor: Colors.blue[800],
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
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0), // Add horizontal padding
        child: Divider(
          color: Colors.black, // Black divider
          height: 1,
          thickness: 0.5, // Thinner divider
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
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('$fullName ${isPrivate ? '(Private)' : ''}',
              style: TextStyle(color: Colors.grey[600])),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return Expanded(
      child: ListView.separated(
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            color: Colors.black,
            height: 1,
            thickness: 0.5,
          ),
        ),
        itemBuilder: (context, index) {
          final user = _searchResults[index];
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
            title:
                Text(username, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text('$fullName ${isPrivate ? '(Private)' : ''}',
                style: TextStyle(color: Colors.grey[600])),
            trailing: ElevatedButton(
              onPressed: () => _selectUser(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
              child: const Text("Select"),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red[600]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Search for users to view their followers and following.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}