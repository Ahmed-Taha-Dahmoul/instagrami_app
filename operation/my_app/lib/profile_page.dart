import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import the secure storage
import 'config.dart'; // Import your app config

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userInfo;
  bool isLoading = true;
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    // Retrieve the access token from secure storage
    String? token = await _secureStorage.read(key: 'access_token');
    
    if (token == null) {
      setState(() {
        errorMessage = "No access token found. Please log in again.";
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}user-info/"), // Adjust endpoint if needed
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          userInfo = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to fetch user info. Status: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : errorMessage != null
                ? Text(errorMessage!)
                : userInfo != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("ID: ${userInfo!['id']}"),
                          Text("Username: ${userInfo!['username']}"),
                          Text("Email: ${userInfo!['email']}"),
                          Text("First Name: ${userInfo!['first_name']}"),
                          Text("Last Name: ${userInfo!['last_name']}"),
                        ],
                      )
                    : Text("No data available"),
      ),
    );
  }
}
