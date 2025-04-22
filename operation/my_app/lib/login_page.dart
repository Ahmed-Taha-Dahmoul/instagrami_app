// Required for RichText links
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // For Timer
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Page Imports ---
import 'config.dart'; // For AppConfig.baseUrl
import 'signup.dart'; // For navigating to signup
// We don't need to import home.dart, navigation happens by popping LoginPage
// ---

// Define colors for consistency (matching SignupPage styles)
const Color primaryBlue = Color(0xFF3897F0);
const Color lightGrey = Color(0xFFFAFAFA);
const Color borderColor = Color(0xFFDBDBDB);
const Color darkGreyText = Color(0xFF262626);
const Color lightGreyText = Color(0xFF999999);
const Color linkBlue = Color(0xFF00376B); // Slightly darker blue for links
const Color successGreen =
    Color.fromARGB(255, 79, 190, 103); // Green from original dialog

class LoginPage extends StatefulWidget {
  final ValueNotifier<bool> isLoggedIn;

  LoginPage({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Removed TickerProviderStateMixin as animations are gone
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = FlutterSecureStorage();
  bool _isLoading = false;
  // Removed _isPasswordVisible as the toggle is gone

  // Timer for success dialog auto-close
  Timer? _successDialogTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _successDialogTimer?.cancel(); // Cancel timer if active
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // Make button full width
                  children: [
                    // --- Logo ---
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 80, height: 80,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        // --- Replace with your asset ---
                        child: Image.asset(
                          'assets/instagram_logo_white.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- Header Text ---
                    const Text(
                      'Instagram Tracker', // Updated Header
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: darkGreyText,
                        fontSize: 24, // Adjusted size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Monitor your Instagram analytics', // Added Subheader
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: lightGreyText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40), // Increased spacing

                    // --- Email Field ---
                    _buildLabel('Email address'), // Label above
                    _buildTextField(
                      // Using updated helper
                      controller: _emailController,
                      hintText: 'Enter your email',
                      icon: Icons.mail_outline, // Updated icon
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        // Basic email regex validation
                        final emailRegex = RegExp(
                            r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                        if (!emailRegex.hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // --- Password Field ---
                    _buildLabel('Password'), // Label above
                    _buildPasswordField(
                      // Using updated helper (no visibility toggle)
                      controller: _passwordController,
                      hintText: 'Enter your password',
                      // Use info or warning icon as per image
                      icon:
                          Icons.info_outline, // Or Icons.warning_amber_outlined
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        // Optional: Add length validation if needed
                        return null;
                      },
                    ),
                    const SizedBox(height: 10), // Space before forgot password

                    // --- Forgot Password Link ---
                    _buildForgotPasswordLink(), // Added helper call
                    const SizedBox(height: 25), // Space before login button

                    // --- Login Button ---
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue, // Match UI
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8), // Match Signup style
                        ),
                        elevation: 2,
                        disabledBackgroundColor: primaryBlue.withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text(
                              'Log in', // Updated text
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 30),

                    // --- Sign up Link ---
                    _buildSignupLink(), // Added helper call
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets (Adapted from Signup Page) ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: darkGreyText,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: lightGreyText, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: lightGrey,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1.0)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
    );
  }

  // Password Field (No visibility toggle)
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true, // Password always obscured
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: lightGreyText, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: lightGrey,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1.0)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
    );
  }

  // Helper for "Forgot password?" link
  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          // TODO: Implement Forgot Password Navigation/Logic
          print("Forgot Password Tapped");
          _showInfoSnackBar("Forgot Password feature not implemented yet.");
        },
        child: Text(
          "Forgot password?",
          style: TextStyle(
            color: linkBlue, // Use link color
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Helper for "Don't have an account? Sign up" link
  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: darkGreyText, fontSize: 14), // Use dark text
        ),
        GestureDetector(
          onTap: () {
            print("Navigate to Sign up");
            // Navigate to Signup Page (add it on top of Login)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SignupPage(isLoggedIn: widget.isLoggedIn), // Pass notifier
              ),
            );
          },
          child: Text(
            "Sign up",
            style: TextStyle(
              color: linkBlue, // Use link color
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // --- Login Logic (Kept mostly the same, points to /login/ endpoint) ---
  void _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text;

    // Ensure this points to your LOGIN endpoint
    final url = Uri.parse('${AppConfig.baseUrl}authentication/login/');
    print("Attempting to login: $email");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email,
          'password': password
        }), // Use 'username' if backend expects it
      );

      print("Login Response Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        // SUCCESS (OK) for login
        final responseData = jsonDecode(response.body);
        final accessToken = responseData['access'];
        final refreshToken = responseData['refresh'];

        print("Login successful, storing tokens.");
        // Store tokens
        try {
          await _storage.write(key: 'access_token', value: accessToken);
          await _storage.write(key: 'refresh_token', value: refreshToken);
          // Update the global login state
          widget.isLoggedIn.value =
              true; // <<< This triggers the main app rebuild
        } catch (storageError) {
          print("Error writing to secure storage: $storageError");
          _showErrorSnackBar('Could not save login details securely.');
          if (mounted)
            setState(() {
              _isLoading = false;
            });
          return;
        }

        // Show success dialog (which will pop the login page)
        if (mounted) {
          _showLoginSuccessDialog();
        }
      } else {
        // Handle Login Errors (e.g., 401 Unauthorized, 400 Bad Request)
        String errorMessage =
            'Login failed. Please check your credentials.'; // Default
        try {
          final errorData = jsonDecode(response.body);
          print("Login error response body: $errorData");
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail']; // Common DRF error message
          } else if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          } else if (errorData is String) {
            errorMessage = errorData;
          }
          // Add more specific checks if your backend returns different error structures
        } catch (e) {
          print("Error parsing login error response: $e");
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (error) {
      // Handle Network Errors
      print("Login HTTP Error: $error");
      _showErrorSnackBar('Network error. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Dialogs and Snackbars ---

  // Login Success Dialog (pops login page)
  void _showLoginSuccessDialog() {
    if (!mounted) return;
    _successDialogTimer?.cancel(); // Cancel previous timer if any

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              type: MaterialType.card,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: successGreen, size: 50), // Use original green
                    const SizedBox(height: 20),
                    const Text(
                      "Login Successful!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkGreyText),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Welcome back! Loading your dashboard...", // Updated text
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: () => _closeDialogAndLoginPage(), // Use helper
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen,
                        foregroundColor: Colors.white, // Use original green
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                      ),
                      child: const Text("Continue"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    // Auto close after 2 seconds (as per original logic)
    _successDialogTimer = Timer(const Duration(seconds: 2), () {
      _closeDialogAndLoginPage();
    });
  }

  // Helper to close dialog and login page
  void _closeDialogAndLoginPage() {
    if (mounted) {
      // Pop dialog first
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Then pop the login page itself
      if (Navigator.of(context).canPop()) {
        Navigator.of(context)
            .pop(); // This takes user back to where Login was pushed from
      }
    }
    _successDialogTimer?.cancel();
  }

  // Error Snackbar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Info Snackbar
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
}
