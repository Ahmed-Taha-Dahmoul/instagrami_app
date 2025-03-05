import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
// ignore: unused_import
import 'dart:convert';
import 'instagram_login.dart';
import 'api_service.dart';
import 'instagram_service.dart';
import 'followed_but_not_followed_back.dart';
import 'not_followed_but_following_me.dart';
import 'who_unfollowed_you.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  bool isInstagramConnected = false;
  bool isLoading = true;
  Map<String, dynamic>? instagramData;
  String errorMessage = "";
  bool isFetchingFollowers = false;
  Map<String, dynamic>? instagramUserProfile;

  DateTime? _lastFetchedTime;
  Timer? _timer;
  String _timeUntilNextFetch = "";

  bool isFirstTimeInstagramConnection = true;

  late final AnimationController _profileScaleController;
  late final Animation<double> _profileScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadLastFetchedTime();
    _checkInstagramStatus();
    _startTimer();

    // Profile scale animation (looping)
    _profileScaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(
        reverse:
            true); // This makes it loop:  forward, then reverse, then repeat
    _profileScaleAnimation = Tween<double>(
      begin: 1.0, // Normal size
      end: 1.03, // Slightly bigger
    ).animate(CurvedAnimation(
      parent: _profileScaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _profileScaleController.dispose(); // Dispose of the animation controller
    super.dispose();
  }

  Future<void> _loadLastFetchedTime() async {
    String? lastFetchedString = await _storage.read(key: 'lastFetchedTime');
    if (lastFetchedString != null) {
      _lastFetchedTime = DateTime.parse(lastFetchedString);
    }
    _updateTimeUntilNextFetch();
    _loadFirstTimeConnectionFlag();
  }

  Future<void> _saveLastFetchedTime() async {
    await _storage.write(
        key: 'lastFetchedTime', value: DateTime.now().toIso8601String());
  }

  Future<void> _loadFirstTimeConnectionFlag() async {
    String? firstTimeFlag =
        await _storage.read(key: 'isFirstTimeInstagramConnection');
    if (firstTimeFlag != null && firstTimeFlag == 'false') {
      setState(() {
        isFirstTimeInstagramConnection = false;
      });
    }
  }

  Future<void> _saveFirstTimeConnectionFlag() async {
    await _storage.write(key: 'isFirstTimeInstagramConnection', value: 'false');
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateTimeUntilNextFetch();
    });
  }

  void _updateTimeUntilNextFetch() {
    final now = DateTime.now();
    DateTime nextFetchTime = _lastFetchedTime != null
        ? _lastFetchedTime!.add(Duration(hours: 24))
        : now;

    if (nextFetchTime.isBefore(now)) {
      nextFetchTime = now;
    }

    final difference = nextFetchTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    setState(() {
      _timeUntilNextFetch =
          'Next fetch in ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _checkInstagramStatus() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      String? accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null) {
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
        });
        return;
      }

      bool status = await ApiService.checkInstagramStatus(accessToken);
      print("Instagram status: $status");

      if (!status) {
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
        });
        return;
      }

      await _fetchInstagramData(accessToken); // Fetch data
      status = await _verifyInstagramConnection(); //Verify connection

      setState(() {
        isInstagramConnected = status;
        isLoading = false;
      });
    } catch (e) {
      print("Error checking Instagram status: $e");
      setState(() {
        errorMessage = "Error checking Instagram status: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchInstagramData(String accessToken) async {
    try {
      final data = await ApiService.getInstagramData(accessToken);
      setState(() {
        instagramData = data;
      });

      await _storage.write(key: 'user1_id', value: instagramData!['user1_id']);
      await _storage.write(
          key: 'csrftoken', value: instagramData!['csrftoken']);
      await _storage.write(
          key: 'session_id', value: instagramData!['session_id']);
      await _storage.write(
          key: 'x_ig_app_id', value: instagramData!['x_ig_app_id']);

      if (isFirstTimeInstagramConnection &&
          instagramData != null &&
          instagramData!.isNotEmpty) {
        if (instagramData!.containsKey('user1_id') &&
            instagramData!['user1_id'] != null) {
          final result = await ApiService.getInstagramUserInfoAndSave(
            instagramData!['user1_id']!,
            instagramData!['csrftoken']!,
            instagramData!['session_id']!,
            instagramData!['x_ig_app_id']!,
            accessToken,
          );

          if (result.containsKey('error')) {
            print("Error saving user info: ${result['error']}");
            setState(() {
              errorMessage = "Error saving user info. ${result['error']}";
            });
          } else {
            print("User info saved successfully");
            setState(() {
              isFirstTimeInstagramConnection = false;
            });
            _saveFirstTimeConnectionFlag();
          }
        } else {
          print("Error: 'user1_id' is missing or null in instagramData");
          setState(() {
            errorMessage = "Instagram data is incomplete.  Missing 'user1_id'.";
          });
        }
      }
      if (instagramData != null) {
        await _attemptFetchAndSendFollowers(accessToken, instagramData!);
      }

      final userProfileResult =
          await ApiService.fetchInstagramUserProfile(accessToken);
      if (userProfileResult.containsKey('error')) {
        print(
            "Error fetching user profile from your backend: ${userProfileResult['error']}");
        setState(() {
          errorMessage =
              "Error fetching your profile. ${userProfileResult['error']}";
        });
      } else {
        setState(() {
          instagramUserProfile = userProfileResult['user_data'];
        });
      }
    } catch (e) {
      print("Error fetching Instagram data: $e");
      setState(() {
        errorMessage = "Error fetching Instagram data: ${e.toString()}";
      });
    }
  }

  Future<bool> _verifyInstagramConnection() async {
    try {
      if (instagramData == null || instagramData!.isEmpty) {
        print("Instagram data is null. Cannot verify connection.");
        return false;
      }

      String? csrftoken = instagramData!['csrftoken'];
      String? userId = instagramData!['user1_id']; // Corrected key
      String? sessionId = instagramData!['session_id'];
      String? xIgAppId = instagramData!['x_ig_app_id'];

      int count = 1;

      if (csrftoken == null ||
          userId == null ||
          sessionId == null ||
          xIgAppId == null) {
        print("Missing required Instagram authentication data");
        return false;
      }

      final headers = {
        "cookie":
            "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
        "referer": "https://www.instagram.com/$userId/following/?next=/",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": xIgAppId,
      };

      String url =
          "https://www.instagram.com/api/v1/friendships/$userId/following/?count=$count";

      final response = await http.get(Uri.parse(url), headers: headers);
      print(response.body); // Log for debugging
      if (response.statusCode == 200) {
        print("Instagram connection verified.");
        return true;
      } else {
        print(
            "Instagram connection failed with status: ${response.statusCode}");
        print("Response body: ${response.body}"); // Log for debugging
        return false;
      }
    } catch (e) {
      print("Error verifying Instagram connection: $e");
      return false;
    }
  }

  Future<void> _attemptFetchAndSendFollowers(
      String accessToken, Map<String, dynamic> instagramData) async {
    final now = DateTime.now();
    if (_lastFetchedTime == null ||
        now.difference(_lastFetchedTime!) >= Duration(hours: 24)) {
      await _fetchAndSendInstagramFollowers(accessToken, instagramData);
      await _saveLastFetchedTime();
      _lastFetchedTime = now;
    } else {
      print(
          "Not fetching followers yet. Time until next fetch: $_timeUntilNextFetch");
    }
  }

  Future<void> _fetchAndSendInstagramFollowers(
      String accessToken, Map<String, dynamic> instagramData) async {
    setState(() {
      isFetchingFollowers = true;
    });

    try {
      await fetchAndSendInstagramData(
        accessToken,
        instagramData['user1_id']!, // Corrected key
        instagramData['session_id']!,
        instagramData['csrftoken']!,
        instagramData['x_ig_app_id']!,
      );
      print("Successfully fetched and sent Instagram followers.");
    } catch (e) {
      print("Error fetching and sending Instagram followers: $e");
      setState(() {
        errorMessage = "Error fetching Instagram followers: ${e.toString()}";
      });
    } finally {
      setState(() {
        isFetchingFollowers = false;
      });
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InstagramLogin()),
    ).then((_) {
      setState(() {
        isFirstTimeInstagramConnection = true;
        _checkInstagramStatus(); // Re-check status after returning from login
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Text(
                  "Instagram account: ",
                  style: TextStyle(
                    color: isInstagramConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  isInstagramConnected ? Icons.check_circle : Icons.cancel,
                  color: isInstagramConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (isInstagramConnected) {
      // Show profile AND cards when connected
      return Column(
        children: [
          if (instagramUserProfile != null) ...[
            _buildUserProfile(), // Animated profile
            SizedBox(height: 20),
          ],
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _timeUntilNextFetch,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 25,
                crossAxisSpacing: 25,
                primary: false,
                children: [
                  _buildCard(
                    'assets/icons/unfollow.png', // Replace with your asset paths
                    'Who Unfollowed You',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => UnfollowedYouScreen()),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/not_following_you.png', // Replace with your asset paths
                    'Who is not following you back',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FollowedButNotFollowedBackScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/not_following.png', // Replace with your asset paths
                    'Who you are not following',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NotFollowedButFollowingMeScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Show login button and timer when not connected
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _timeUntilNextFetch,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ElevatedButton(
              onPressed: _navigateToLogin,
              child: Text("Login with Instagram"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildUserProfile() {
    // Use ScaleTransition for the pulsing effect
    return ScaleTransition(
      scale: _profileScaleAnimation, // Apply the scale animation
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(
                  instagramUserProfile!['instagram_profile_picture_url'],
                ),
                radius: 40,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "@${instagramUserProfile!['instagram_username'] ?? 'No Username'}",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      instagramUserProfile!['instagram_full_name'] ?? 'No Name',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(
                            instagramUserProfile!['instagram_total_posts'] ?? 0,
                            "posts"),
                        _buildStatColumn(
                            instagramUserProfile!['instagram_follower_count'] ??
                                0,
                            "followers"),
                        _buildStatColumn(
                            instagramUserProfile![
                                    'instagram_following_count'] ??
                                0,
                            "following"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(int value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

// No changes needed here - the cards already have a ScaleTransition
  Widget _buildCard(String imagePath, String title, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, width: 64, height: 64),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
