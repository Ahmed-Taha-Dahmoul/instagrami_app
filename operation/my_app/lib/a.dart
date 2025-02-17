import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';
import 'instagram_login.dart';
import 'bottom_nav_bar.dart';
import 'api_service.dart'; // Import the api service

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool isInstagramConnected = false;
  bool isLoading = true;
  Map<String, dynamic> instagramData = {}; // Store decrypted Instagram data
  String errorMessage = ""; // To display error messages

  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkInstagramStatus();
  }

  // Check Instagram connection status and fetch encrypted data
  Future<void> _checkInstagramStatus() async {
    setState(() {
      isLoading = true;
      errorMessage = ""; // Clear any previous error message
    });

    try {
      // Retrieve the access token from secure storage
      String? accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
        });
        return;
      }

      // Send request to check Instagram connection status
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}api/check_instagram_status/"),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          isInstagramConnected = responseData['connected'];
        });

        // If Instagram is connected, fetch and decrypt Instagram data
        if (isInstagramConnected) {
          _fetchAndDecryptInstagramData(accessToken);
        }
      } else {
        print("Failed to check Instagram status: ${response.statusCode}");
        _navigateToHome(); // Navigate to Home on failure
      }
    } catch (e) {
      print("Error checking Instagram status: $e");
      setState(() {
        errorMessage = "Error checking Instagram status: ${e.toString()}";
      });
      _navigateToHome(); // Navigate to Home on error
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch and decrypt Instagram data
  Future<void> _fetchAndDecryptInstagramData(String accessToken) async {
    try {
      final data = await ApiService.getInstagramData(accessToken);
      setState(() {
        instagramData = data;
      });
      print("Decrypted Instagram Data: $instagramData"); // Log the data
    } catch (e) {
      print("Error fetching and decrypting data: $e");
      setState(() {
        errorMessage = "Error fetching and decrypting data: ${e.toString()}";
      });
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InstagramLogin()),
    ).then((_) {
      // Refresh status after returning from login
      _checkInstagramStatus();
    });
  }

  // Handle tab selection
  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
  }

  // Navigate back to Home page if there's an error
  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
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
        child: isLoading
            ? CircularProgressIndicator() // Show loading indicator
            : _selectedTabIndex == 0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      if (isInstagramConnected && instagramData.isNotEmpty)
                        Column(
                          children: [
                            Text("Decrypted Instagram Data:"),
                            Text("user1_id: ${instagramData['user1_id']}"),
                            Text("session_id: ${instagramData['session_id']}"),
                            Text("csrftoken: ${instagramData['csrftoken']}"),
                            Text(
                                "x_ig_app_id: ${instagramData['x_ig_app_id']}"),
                          ],
                        ),
                    ],
                  )
                : _selectedTabIndex == 1
                    ? Center(child: Text("Profile Page"))
                    : _selectedTabIndex == 2
                        ? Center(child: Text("Settings Page"))
                        : Container(),
      ),
      bottomNavigationBar: BottomNavBar(onTabSelected: _onTabSelected),
    );
  }
}
