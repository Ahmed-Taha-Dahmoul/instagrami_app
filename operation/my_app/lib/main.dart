import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'welcome_page.dart';
import 'home.dart'; // Import HomePage
import 'login_page.dart';
import 'signup.dart';

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
  Widget _initialScreen = WelcomePage(); // Default to WelcomePage

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    String? token = await _storage.read(key: 'access_token');
    if (token != null) {
      setState(() {
        _initialScreen = HomePage(); // Redirect to Home if logged in
      });
    }
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
      home: _initialScreen, // Dynamically change based on login state
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => SignupPage(),
      },
    );
  }
}
