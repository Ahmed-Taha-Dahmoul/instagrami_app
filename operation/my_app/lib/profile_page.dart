import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shimmer/shimmer.dart'; // For smooth loading effect
import 'config.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userInfo;
  String? userCredit;
  bool isLoadingUser = true;
  bool isLoadingCredit = true;
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
    fetchUserCredit();
  }

  Future<void> fetchUserInfo() async {
    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      setState(() {
        errorMessage = "No access token found. Please log in again.";
        isLoadingUser = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}user-info/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          userInfo = jsonDecode(response.body);
          isLoadingUser = false;
        });
      } else {
        setState(() {
          errorMessage = "Failed to fetch user info.";
          isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoadingUser = false;
      });
    }
  }

  Future<void> fetchUserCredit() async {
    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      setState(() {
        errorMessage = "No access token found.";
        isLoadingCredit = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}payment/user/credit/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          userCredit = jsonDecode(response.body)['credit_balance'].toString();
          isLoadingCredit = false;
        });
        print("usercrediiiiiiiiiiiiiiiiiiiiiiit");
        print(userCredit);
      } else {
        setState(() {
          errorMessage = "Failed to fetch credit.";
          isLoadingCredit = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoadingCredit = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Info Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 6,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  SizedBox(width: 12),
                  isLoadingUser
                      ? Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(
                            width: 120,
                            height: 20,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "Hello, ${userInfo?['username'] ?? 'User'} ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Balance Section
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Balance",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  isLoadingCredit
                      ? Shimmer.fromColors(
                          baseColor: Colors.white70,
                          highlightColor: Colors.white,
                          child: Container(
                            width: 80,
                            height: 24,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          "${userCredit ?? '0.0000'} Coins",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                      ),
                      onPressed: () {},
                      child: Text("Recharge"),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Options List
            Expanded(
              child: ListView(
                children: [
                  _buildOptionTile(Icons.subscriptions, "Subscription History"),
                  _buildOptionTile(Icons.payment, "Payments"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          )
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
