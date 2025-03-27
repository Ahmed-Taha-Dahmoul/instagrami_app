import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'config.dart';
import 'welcome_page.dart';
import 'home.dart';
import 'bottom_nav_bar.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'app_routes.dart';
import 'custom_splash_screen.dart'; // Import CustomSplashScreen

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
  bool _isLoading =
      true; // Keep _isLoading to manage the transition after splash.
  String? _errorMessage;
  // Removed _showSplashScreen - no longer needed.

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Combine splash screen display and token verification.
    await _checkLoginStatus(); // Verify tokens FIRST

    // After token check, simulate any *additional* splash screen delay.
    // If token verification is fast, you might want a minimum splash duration.
    // If verification *itself* takes a long time, this might be a short delay, or even unnecessary.
    await Future.delayed(Duration(seconds: 2));

    setState(() {
      _isLoading = false; // Hide loading indicator and show main content.
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
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
            _logoutUser(); // Refresh failed, log out.
          }
        } else {
          _logoutUser(); // No valid tokens, log out.
        }
      } else {
        _isLoggedIn.value = false; // No access token, so not logged in
      }
    } catch (e) {
      _errorMessage = "An error occurred: $e";
      _logoutUser(); // Treat errors as logout to be safe.
    }
  }

  Future<bool> _verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}api/token/verify/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      _errorMessage = "Network error: $e";
      return false;
    }
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}authentication/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['access'];
      } else {
        _errorMessage = "Failed to refresh token: ${response.statusCode}";
        return null;
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
      return null;
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
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      routes: AppRoutes.routes(_isLoggedIn),
      home: _isLoading
          ? CustomSplashScreen() // Show splash screen while loading
          : ValueListenableBuilder<bool>(
              valueListenable: _isLoggedIn,
              builder: (context, isLoggedIn, child) {
                if (_errorMessage != null) {
                  // Display error using ScaffoldMessenger.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_errorMessage!),
                      backgroundColor: Colors.red,
                    ));
                    _errorMessage = null; // Clear error after displaying.
                  });
                }
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

  final List<Widget> _screens = [
    HomePage(),
    ProfilePage(),
    SettingsPage(),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTabSelected(int index) {
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: _screens,
        onPageChanged: _onPageChanged,
        physics: NeverScrollableScrollPhysics(),
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
