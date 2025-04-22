import 'package:flutter/gestures.dart'; // Required for RichText links
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // Import for Timer/Future.delayed
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Page Imports (ensure these files exist and paths are correct) ---
import 'config.dart'; // For AppConfig.baseUrl
import 'login_page.dart'; // For navigating to login via link
import 'terms_of_service_page.dart'; // For navigating to terms
import 'privacy_policy_page.dart'; // For navigating to policy
// Note: We don't explicitly import home.dart here, navigation happens by popping
// ---

// Define colors for consistency
const Color primaryBlue = Color(0xFF3897F0);
const Color lightGrey = Color(0xFFFAFAFA);
const Color borderColor = Color(0xFFDBDBDB);
const Color darkGreyText = Color(0xFF262626);
const Color lightGreyText = Color(0xFF999999);
const Color linkBlue = Color(0xFF00376B);
const Color successGreen =
    Color.fromARGB(255, 84, 189, 98); // Success button color from original

class SignupPage extends StatefulWidget {
  final ValueNotifier<bool> isLoggedIn;

  SignupPage({required this.isLoggedIn, Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storage = FlutterSecureStorage();

  bool _isLoading = false;
  bool _agreeToTerms = false;

  // To manage the auto-close timer for the success dialog
  Timer? _successDialogTimer;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _successDialogTimer?.cancel(); // Cancel timer if page is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Keeping the updated UI ---
    return Scaffold(
      backgroundColor: Colors.white,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Image.asset(
                          'assets/instagram_logo_white.png',
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    // Headers
                    const Text('Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: darkGreyText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text('Join Instagram Tracker today',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: lightGreyText, fontSize: 14)),
                    const SizedBox(height: 30),
                    // Fields
                    _buildLabel('Full Name'),
                    _buildTextField(
                        controller: _fullNameController,
                        hintText: 'Enter your full name',
                        icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter your full name'
                            : null),
                    const SizedBox(height: 15),
                    _buildLabel('Email address'),
                    _buildTextField(
                        controller: _emailController,
                        hintText: 'Enter your email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Please enter your email';
                          final emailRegex = RegExp(
                              r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                          if (!emailRegex.hasMatch(v))
                            return 'Please enter a valid email address';
                          return null;
                        }),
                    const SizedBox(height: 15),
                    _buildLabel('Password'),
                    _buildPasswordField(
                        controller: _passwordController,
                        hintText: 'Create a password',
                        icon: Icons.lock_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please enter a password';
                          if (v.length < 8)
                            return 'Password must be at least 8 characters';
                          return null;
                        }),
                    const SizedBox(height: 15),
                    _buildLabel('Confirm Password'),
                    _buildPasswordField(
                        controller: _confirmPasswordController,
                        hintText: 'Confirm your password',
                        icon: Icons.lock_outline,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please confirm your password';
                          if (v != _passwordController.text)
                            return 'Passwords do not match';
                          return null;
                        }),
                    const SizedBox(height: 20),
                    // Terms Checkbox
                    _buildTermsCheckbox(), // Navigates to legal pages
                    const SizedBox(height: 25),
                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                        disabledBackgroundColor: primaryBlue.withOpacity(0.6),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                    // Login Link
                    _buildLoginLink(), // Navigates to Login Page
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets (Keep previous versions) ---
  Widget _buildLabel(String text) {
    /* ... same as before ... */
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

  Widget _buildTextField(
      {required TextEditingController controller,
      required String hintText,
      required IconData icon,
      TextInputType keyboardType = TextInputType.text,
      required String? Function(String?) validator}) {
    /* ... same as before ... */
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      autovalidateMode:
          AutovalidateMode.onUserInteraction, // Validate as typing
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        prefixIcon: Padding(
          // Add padding around icon
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: lightGreyText, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(
            minWidth: 40), // Ensure consistent icon spacing
        filled: true, // Need filled true for color
        fillColor: lightGrey, // Light grey background
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
          // Base border style
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          // Border when enabled and not focused
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          // Border when focused
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: primaryBlue, width: 1.5), // Highlight with blue
        ),
        errorBorder: OutlineInputBorder(
          // Border on error
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          // Border on error + focus
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(
            fontSize: 12, height: 0.8), // Adjust error text style
      ),
    );
  }

  Widget _buildPasswordField(
      {required TextEditingController controller,
      required String hintText,
      required IconData icon,
      required String? Function(String?) validator}) {
    /* ... same as before ... */
    return TextFormField(
      controller: controller,
      obscureText: true, // Always hidden
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        prefixIcon: Padding(
          // Add padding around icon
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: lightGreyText, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(
            minWidth: 40), // Ensure consistent icon spacing
        filled: true,
        fillColor: lightGrey,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    /* ... same as before, navigates to legal pages ... */
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 24.0,
          width: 24.0,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
            activeColor: primaryBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            side: BorderSide(
                color: _agreeToTerms ? primaryBlue : borderColor, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: 'I agree to the ',
              style: const TextStyle(
                  fontSize: 13, color: lightGreyText, height: 1.4),
              children: <TextSpan>[
                TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                        color: linkBlue, fontWeight: FontWeight.w600),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TermsOfServicePage()));
                      }),
                const TextSpan(text: ' and '),
                TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                        color: linkBlue, fontWeight: FontWeight.w600),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage()));
                      }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    /* ... same as before, navigates to login page ... */
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account? ",
            style: TextStyle(color: darkGreyText, fontSize: 14)),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => LoginPage(isLoggedIn: widget.isLoggedIn)));
          },
          child: const Text("Log in",
              style: TextStyle(
                  color: linkBlue, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  // --- Submission Logic (REVERTED to original behavior) ---
  void _submitForm() async {
    // Validate form
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Check terms
    if (!_agreeToTerms) {
      _showErrorSnackBar(
          'Please agree to the Terms of Service and Privacy Policy.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Get data
    String fullName = _fullNameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    // API Call
    final url = Uri.parse('${AppConfig.baseUrl}authentication/register/');
    print("Attempting to register: $email");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': email,
          'password': password,
          'first_name': fullName,
        }),
      );

      print("Response Status Code: ${response.statusCode}");

      if (response.statusCode == 201) {
        // Success
        final responseData = jsonDecode(response.body);
        print("Registration successful, storing tokens.");

        // --- STORE TOKENS and SET LOGIN STATE (Original Behavior) ---
        try {
          await _storage.write(
              key: 'access_token', value: responseData['access']);
          await _storage.write(
              key: 'refresh_token', value: responseData['refresh']);
          widget.isLoggedIn.value = true; // <<< SET LOGIN STATE TRUE
        } catch (storageError) {
          print("Error writing to secure storage: $storageError");
          _showErrorSnackBar('Could not save login details securely.');
          if (mounted)
            setState(() {
              _isLoading = false;
            });
          return;
        }
        // ----------------------------------------------------------

        if (mounted) {
          _showSuccessDialog(); // Show success dialog (which pops signup page)
        }
      } else {
        // Handle API Errors
        String errorMessage =
            'Signup failed (Code: ${response.statusCode}). Please try again.';
        try {
          /* ... (error parsing logic remains the same) ... */
          final errorData = jsonDecode(response.body);
          print("Signup error response body: $errorData");
          if (errorData is Map) {
            if (errorData.containsKey('error')) {
              errorMessage = errorData['error'];
            } else if (errorData.containsKey('username') &&
                errorData['username'] is List &&
                errorData['username'].isNotEmpty) {
              errorMessage = 'Username: ${errorData['username'][0]}';
            } else if (errorData.containsKey('password') &&
                errorData['password'] is List &&
                errorData['password'].isNotEmpty) {
              errorMessage = 'Password: ${errorData['password'][0]}';
            } else if (errorData.containsKey('first_name') &&
                errorData['first_name'] is List &&
                errorData['first_name'].isNotEmpty) {
              errorMessage = 'Full Name: ${errorData['first_name'][0]}';
            } else if (errorData.containsKey('detail')) {
              errorMessage = errorData['detail'];
            } else {
              errorMessage = errorData.entries
                  .map((e) =>
                      '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}')
                  .join('; ');
              if (errorMessage.isEmpty)
                errorMessage = "An unknown error occurred.";
            }
          } else if (errorData is String) {
            errorMessage = errorData;
          }
        } catch (e) {
          print("Error parsing error response: $e");
          errorMessage =
              response.body.isNotEmpty ? response.body : errorMessage;
        }
        _showErrorSnackBar(errorMessage);
      }
    } catch (error) {
      // Handle Network Errors
      print("Signup HTTP Error: $error");
      _showErrorSnackBar('Network error. Please check your connection.');
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  // --- Success Dialog (REVERTED to pop signup page) ---
  void _showSuccessDialog() {
    if (!mounted) return;

    // Cancel any previous timer
    _successDialogTimer?.cancel();

    showGeneralDialog(
      context: context,
      barrierDismissible: false, // User must tap button or wait for timeout
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration:
          const Duration(milliseconds: 400), // Faster transition
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(
              // Use Material for theming
              type: MaterialType.card,
              borderRadius:
                  BorderRadius.circular(15), // Less rounded than original
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(25), // More padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Simple Check Icon is better UX than progress + check
                    const Icon(Icons.check_circle,
                        color: successGreen, size: 50),
                    const SizedBox(height: 20),
                    const Text(
                      "Account Created!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkGreyText), // Standard text color
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your account has been successfully created. Get ready to explore!", // Original-style message
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.4), // Standard text color
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      onPressed: () =>
                          _closeDialogAndSignupPage(), // Use helper function
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen, // Use the green color
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                8)), // Match other button style
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

    // --- AUTO-CLOSE (Original Behavior) ---
    _successDialogTimer = Timer(const Duration(seconds: 3), () {
      _closeDialogAndSignupPage();
    });
    // ------------------------------------
  }

  // Helper function to close dialog and signup page safely
  void _closeDialogAndSignupPage() {
    if (mounted) {
      // Pop dialog first (use rootNavigator: true to be safe)
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      // Then pop the signup page itself
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
    // Ensure timer is cancelled if closed manually
    _successDialogTimer?.cancel();
  }

  // --- Snackbars (Keep as is) ---
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

  // ignore: unused_element
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
