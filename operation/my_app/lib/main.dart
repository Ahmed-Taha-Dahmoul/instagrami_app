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
  // ignore: unused_field
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSplashScreen = true; // Flag to control splash screen display

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Simulate splash screen duration.
    await Future.delayed(Duration(seconds: 3));

    // Now check login status
    await _checkLoginStatus();

    // After checking login status, hide splash screen and show appropriate screen
    setState(() {
      _showSplashScreen = false;
      _isLoading = false;  // Ensure _isLoading is also updated
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
            _logoutUser();
          }
        } else {
          _logoutUser();
        }
      }
    } catch (e) {
      _errorMessage = "An error occurred: $e";
      _logoutUser();
    }
  }


    Future<bool> _verifyToken(String token) async {
    try {
        final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}api/token/verify/'),  // Ensure correct endpoint.
        headers: {
            'Authorization': 'Bearer $token',
        },
        );

        return response.statusCode == 200;
    } catch (e) {
      //  Network error (e.g., no internet)
        _errorMessage = "Network error: $e";  // Set an error message
        return false;  // Assume token is invalid on network failure
    }

  }

  Future<String?> _refreshToken(String refreshToken) async {
    try{
        final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}authentication/token/refresh/'), // Ensure correct endpoint.
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
        );

        if (response.statusCode == 200) {
            return jsonDecode(response.body)['access'];
        } else {
            _errorMessage = "Failed to refresh token: ${response.statusCode}";  // Set detailed error.
            return null;
        }
    }catch (e) {
        //  Network error (e.g., no internet)
        _errorMessage = "Network error: $e";  // Set an error message
        return null;  // Assume token is invalid on network failure
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
      routes: AppRoutes.routes(_isLoggedIn),
      home: _showSplashScreen
          ? CustomSplashScreen() // Show splash screen initially
          : ValueListenableBuilder<bool>(
              valueListenable: _isLoggedIn,
              builder: (context, isLoggedIn, child) {
                 if (_errorMessage != null) {
                  // Display error message (consider a SnackBar or Dialog)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_errorMessage!),
                      backgroundColor: Colors.red,
                    ));
                    _errorMessage = null; // Clear the error message after showing it
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