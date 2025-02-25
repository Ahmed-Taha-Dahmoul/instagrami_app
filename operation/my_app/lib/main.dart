import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';
import 'welcome_page.dart';
import 'home.dart';
import 'login_page.dart';
import 'signup.dart';
import 'bottom_nav_bar.dart';
//import 'followed_but_not_followed_back.dart'; // Removed import
import 'profile_page.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = FlutterSecureStorage();
  final ValueNotifier<bool> _isLoggedIn = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    String? accessToken = await _storage.read(key: 'access_token');
    String? refreshToken = await _storage.read(key: 'refresh_token');

    if (accessToken != null) {
      bool isValid = await _verifyToken(accessToken);
      if (isValid) {
        _isLoggedIn.value = true;
      } else if (refreshToken != null) {
        String? newAccessToken = await _refreshToken(refreshToken);
        if (newAccessToken != null) {
          await _storage.write(key: 'access_token', value: newAccessToken);
          _isLoggedIn.value = true;
        } else {
          _logoutUser();
        }
      } else {
        _logoutUser();
      }
    }
  }

  Future<bool> _verifyToken(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}api/token/verify/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200; // Token is valid if response is 200
  }

  Future<String?> _refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}api/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access']; // Return new access token
    } else {
      return null; // Refresh failed
    }
  }

  void _logoutUser() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    _isLoggedIn.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFFF5C7B8),
      ),
      routes: {
        '/login': (context) => LoginPage(isLoggedIn: _isLoggedIn),
        '/register': (context) => SignupPage(isLoggedIn: _isLoggedIn),
        '/main': (context) => MainScreen(),
        '/profile': (context) => ProfilePage(),
        '/settings': (context) => SettingsPage(),
        //'/followed': (context) => FollowedButNotFollowedBackScreen(), // Removed route
      },
      home: ValueListenableBuilder<bool>(
        valueListenable: _isLoggedIn,
        builder: (context, isLoggedIn, child) {
          return isLoggedIn
              ? MainScreen()
              : WelcomePage(isLoggedIn: _isLoggedIn);
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _pageController = PageController();
  int _selectedIndex = 0;

  // List of your screens.  Order matters; it corresponds to the BottomNavBar.
  final List<Widget> _screens = [
    HomePage(),
    ProfilePage(), // Replace with your actual ProfilePage
    SettingsPage(), // Replace with your actual SettingsPage
    //FollowedButNotFollowedBackScreen(), // Removed screen
  ];

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTabSelected(int index) {
    _pageController.jumpToPage(index); // Use jumpToPage for instant change
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _screens,
        onPageChanged: _onPageChanged,
        physics:
            NeverScrollableScrollPhysics(), // Prevent swiping between pages
      ),
      bottomNavigationBar: BottomNavBar(
        onTabSelected: _onTabSelected,
        initialIndex: _selectedIndex,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
