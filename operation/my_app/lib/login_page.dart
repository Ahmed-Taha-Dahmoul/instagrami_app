import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart'; // Importing base URL config
import 'home.dart'; // Import HomePage

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _jarController;
  late AnimationController _coinController;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = FlutterSecureStorage(); // Secure storage for tokens
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _jarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _jarController.dispose();
    _coinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5C7B8),
      body: Stack(
        children: [
          _buildAnimatedElement(
            controller: _jarController,
            top: 50,
            left: 20,
            image: 'assets/jar1.png',
          ),
          _buildAnimatedElement(
            controller: _coinController,
            top: MediaQuery.of(context).size.height * 0.7,
            right: 30,
            image: 'assets/coin.png',
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: const Color(0xFFCF8360),
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildTextField(
                        controller: _emailController,
                        hintText: 'Email',
                        icon: Icons.email,
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter your email';
                          } else if (!value!.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _passwordController,
                        hintText: 'Password',
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        isPasswordVisible: _isPasswordVisible,
                        toggleVisibility: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 200,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFCF8360),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(
                                  color: Colors.black, width: 2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : const Text('LOGIN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedElement({
    required AnimationController controller,
    required double top,
    String? image,
    double? left,
    double? right,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Positioned(
          top: top + 10 * sin(controller.value * 2 * pi),
          left: left,
          right: right,
          child: Transform.rotate(
            angle: 0.2 * sin(controller.value * 4 * pi),
            child: Image.asset(image!, width: 80),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFFCF8360)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Color(0xFFCF8360),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    required bool isPasswordVisible,
    required VoidCallback toggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.lock, color: Color(0xFFCF8360)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Color(0xFFCF8360),
            width: 2,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFFCF8360),
          ),
          onPressed: toggleVisibility,
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      String email = _emailController.text;
      String password = _passwordController.text;

      final url = Uri.parse('${AppConfig.baseUrl}authentication/login/');

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': email, 'password': password}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final accessToken = responseData['access'];
          final refreshToken = responseData['refresh'];

          await _storage.write(key: 'access_token', value: accessToken);
          await _storage.write(key: 'refresh_token', value: refreshToken);

          if (mounted) {
            _showSuccessDialog();
          }
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = errorData['detail'] ??
              'Login failed'; // Use 'detail' for error message. Adjust as needed.
          _showErrorSnackBar(errorMessage);
        }
      } catch (error) {
        _showErrorSnackBar('Error: ${error.toString()}');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 10),
                Text(
                  "Login Successful!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                CircularProgressIndicator(color: Colors.green),
              ],
            ),
          ),
        );
      },
    );

    Future.delayed(Duration(seconds: 2), () {
      Navigator.pop(context); // Close dialog
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false, // Removes all previous routes
      );
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
