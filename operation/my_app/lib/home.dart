// home.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'instagram_login.dart';
import 'api_service.dart';
import 'instagram_service.dart';
import 'followed_but_not_followed_back.dart';
import 'not_followed_but_following_me.dart';
import 'who_unfollowed_you.dart'; // Import the UnfollowedYouScreen

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  bool isInstagramConnected = false;
  bool isLoading = true;
  Map<String, dynamic> instagramData = {};
  String errorMessage = "";
  bool isFetchingFollowers = false;

  DateTime? _lastFetchedTime;
  Timer? _timer;
  String _timeUntilNextFetch = "";

  bool isFirstTimeInstagramConnection = true;

  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    _loadLastFetchedTime();
    _checkInstagramStatus();
    _startTimer();

    _controller1 = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _controller2 = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _controller3 = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
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

      await _fetchAndDecryptInstagramData_check(accessToken);
      status = await _verifyInstagramConnection();
      setState(() {
        isInstagramConnected = status;
        isLoading = false;
      });
      if (status) {
        _controller1.forward();
        _controller2.forward();
        _controller3.forward();
        await _fetchAndDecryptInstagramData(accessToken);
      }
    } catch (e) {
      print("Error checking Instagram status: $e");
      setState(() {
        errorMessage = "Error checking Instagram status: ${e.toString()}";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAndDecryptInstagramData_check(String accessToken) async {
    try {
      final data = await ApiService.getInstagramData(accessToken);
      setState(() {
        instagramData = data;
      });
    } catch (e) {
      print("Error fetching and decrypting data: $e");
      setState(() {
        errorMessage = "Error fetching and decrypting data: ${e.toString()}";
      });
    }
  }

  Future<void> _fetchAndDecryptInstagramData(String accessToken) async {
    try {
      final data = await ApiService.getInstagramData(accessToken);
      setState(() {
        instagramData = data;
      });

      if (isFirstTimeInstagramConnection) {
        await _attemptFetchAndSendFollowers(accessToken, instagramData);
        setState(() {
          isFirstTimeInstagramConnection = false;
        });
        _saveFirstTimeConnectionFlag();
      }
    } catch (e) {
      print("Error fetching and decrypting data: $e");
      setState(() {
        errorMessage = "Error fetching and decrypting data: ${e.toString()}";
      });
    }
  }

  Future<bool> _verifyInstagramConnection() async {
    try {
      if (instagramData.isEmpty) {
        print("Instagram data is null. Cannot verify connection.");
        return false;
      }

      String? csrftoken = instagramData['csrftoken'];
      String? userId = instagramData['user1_id'];
      String? sessionId = instagramData['session_id'];
      String? xIgAppId = instagramData['x_ig_app_id'];

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
      print(response.body);
      if (response.statusCode == 200) {
        print("Instagram connection verified.");
        return true;
      } else {
        print(
            "Instagram connection failed with status: ${response.statusCode}");
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
        instagramData['user1_id'],
        instagramData['session_id'],
        instagramData['csrftoken'],
        instagramData['x_ig_app_id'],
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
        _checkInstagramStatus();
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
          if (!isInstagramConnected) ...[
            ElevatedButton(
              onPressed: _navigateToLogin,
              child: Text("Login with Instagram"),
            ),
            SizedBox(height: 20),
          ],
          if (isInstagramConnected)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 25,
                  crossAxisSpacing: 25,
                  primary: false,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller1,
                        curve: Curves.easeOut,
                      ),
                      child: _buildCard(
                        'assets/icons/student.png',
                        'Who Unfollowed You',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    UnfollowedYouScreen()), // Use the correct screen
                          );
                        },
                      ),
                    ),
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller2,
                        curve: Curves.easeOut,
                      ),
                      child: _buildCard(
                        'assets/icons/schedule.png',
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
                    ),
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _controller3,
                        curve: Curves.easeOut,
                      ),
                      child: _buildCard(
                        'assets/icons/prize.png',
                        'Who you are not following',
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  not_followed_but_following_me_Screen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
