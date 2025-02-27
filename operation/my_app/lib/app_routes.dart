// lib/app_routes.dart
import 'package:flutter/material.dart'; // Add this import
import 'login_page.dart';
import 'signup.dart';
import 'main.dart'; // Import MainScreen
import 'profile_page.dart';
import 'settings_page.dart';
//import 'followed_but_not_followed_back.dart'; // Removed import

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String main = '/main';
  static const String profile = '/profile';
  static const String settings1 = '/settings';
  //static const String followed = '/followed';  // Removed route

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        // Pass isLoggedIn to LoginPage and SignupPage
        return MaterialPageRoute(
            builder: (context) => LoginPage(
                isLoggedIn: settings.arguments as ValueNotifier<bool>));
      case register:
        return MaterialPageRoute(
            builder: (context) => SignupPage(
                isLoggedIn: settings.arguments as ValueNotifier<bool>));
      case main:
        return MaterialPageRoute(builder: (context) => MainScreen());
      case profile:
        return MaterialPageRoute(builder: (context) => ProfilePage());
      case settings1:
        return MaterialPageRoute(builder: (context) => SettingsPage());
      //case followed: // Removed route
      //   return MaterialPageRoute(builder: (context) => FollowedButNotFollowedBackScreen());
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  static Map<String, WidgetBuilder> routes(ValueNotifier<bool> isLoggedIn) {
    return {
      login: (context) => LoginPage(isLoggedIn: isLoggedIn),
      register: (context) => SignupPage(isLoggedIn: isLoggedIn),
      main: (context) => MainScreen(),
      profile: (context) => ProfilePage(),
      settings1: (context) => SettingsPage(),
    };
  }
}
