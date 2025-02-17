// home_page.dart (modified _navigateToLogin and _checkInstagramStatus)
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'instagram_login.dart';
import 'bottom_nav_bar.dart';
import 'api_service.dart';
import 'instagram_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLastFetchedTime();
    _checkInstagramStatus();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    print("_checkInstagramStatus called"); // Add this line for debugging
    if (!mounted)
      return; // Very important: prevents errors after widget disposal

    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      String? accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null || accessToken.isEmpty) {
        print("Access token is null or empty.");
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
        });
        return;
      }

      bool status = await ApiService.checkInstagramStatus(accessToken);
      print("Instagram status: $status"); // Add for debugging
      setState(() {
        isInstagramConnected = status;
        isLoading = false;
      });

      if (status) {
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

  Future<void> _fetchAndDecryptInstagramData(String accessToken) async {
    try {
      final data = await ApiService.getInstagramData(accessToken);
      setState(() {
        instagramData = data;
      });

      if (isFirstTimeInstagramConnection) {
        print("first connection aaaaaaaaaaaaaaaaaa");
        await _attemptFetchAndSendFollowers(accessToken, instagramData);

        setState(() {
          isFirstTimeInstagramConnection = false;
        });
        _saveFirstTimeConnectionFlag(); // Save that it's not the first time anymore
      }
    } catch (e) {
      print("Error fetching and decrypting data: $e");
      setState(() {
        errorMessage = "Error fetching and decrypting data: ${e.toString()}";
      });
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
      await fetchAndSendFollowing(
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
      // Rebuild the HomePage after returning.  Critically important.
      setState(() {
        _checkInstagramStatus();
      });
    });
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
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
      body: Center(
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavBar(onTabSelected: _onTabSelected),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return CircularProgressIndicator(); // Initial loading
    }

    return _selectedTabIndex == 0
        ? Column(
            mainAxisAlignment: MainAxisAlignment.start,
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
              Text(isInstagramConnected
                  ? "Instagram account connected!"
                  : "Instagram account is not connected."),
              SizedBox(height: 20),
              if (!isInstagramConnected)
                ElevatedButton(
                  onPressed: _navigateToLogin,
                  child: Text("Login with Instagram"),
                ),
            ],
          )
        : _selectedTabIndex == 1
            ? Center(child: Text("Profile Page"))
            : _selectedTabIndex == 2
                ? Center(child: Text("Settings Page"))
                : Container();
  }
}
