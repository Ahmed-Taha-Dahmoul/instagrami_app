import 'package:flutter/material.dart';
import 'instagram_login.dart'; // Import the Instagram login screen
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isInstagramConnected = false;

  @override
  void initState() {
    super.initState();
    _checkInstagramConnection();
  }

  Future<void> _checkInstagramConnection() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cookiesJson = prefs.getString("cookies_json");
    
    setState(() {
      isInstagramConnected = cookiesJson != null;
    });
  }

  void _handleInstagramLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InstagramLogin()),
    );

    if (result == true) {
      _checkInstagramConnection();
    }
  }

  void _disconnectInstagram() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("cookies_json");

    setState(() {
      isInstagramConnected = false;
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
        child: ElevatedButton(
          onPressed: isInstagramConnected ? _disconnectInstagram : _handleInstagramLogin,
          child: Text(
            isInstagramConnected ? "Disconnect Instagram" : "Login with Instagram",
          ),
        ),
      ),
    );
  }
}
