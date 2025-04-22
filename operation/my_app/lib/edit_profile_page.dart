import 'package:flutter/material.dart';
// Import image_picker if you implement photo changing:
// import 'package:image_picker/image_picker.dart';
import 'dart:io'; // For File type if using image_picker

// --- Assuming colors defined elsewhere or define them here ---
const Color primaryBlue = Color(0xFF3897F0); // Example blue
const Color lightGrey = Color(0xFFFAFAFA);
const Color borderColor = Color(0xFFDBDBDB);
const Color darkGreyText = Color(0xFF262626);
const Color lightGreyText = Color(0xFF999999);
const Color errorRed = Colors.redAccent;
// ---

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // For changing password

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  File? _profileImageFile; // To hold selected image file

  @override
  void initState() {
    super.initState();
    // TODO: Fetch current user profile data and populate controllers
    // Example:
    _fullNameController.text = "John Doe";
    _emailController.text = "john@example.com";
    // Don't populate password field by default for security
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Image Picking Logic (Placeholder) ---
  Future<void> _pickImage() async {
    // TODO: Implement image picking using image_picker package
    // Example using image_picker:
    /*
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImageFile = File(pickedFile.path);
        });
        // TODO: Upload the _profileImageFile to your backend/storage
        print("Image selected: ${pickedFile.path}");
      }
    } catch (e) {
      print("Error picking image: $e");
      _showErrorSnackBar("Could not pick image.");
    }
    */
    _showInfoSnackBar("Change photo feature not fully implemented.");
  }

  // --- Save Profile Logic (Placeholder) ---
  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return; // Validation failed
    }
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });
    print("Saving profile...");

    // TODO: Implement API call to update profile data
    // Get data:
    String fullName = _fullNameController.text;
    String email = _emailController.text;
    String? newPassword = _passwordController.text.isNotEmpty
        ? _passwordController.text
        : null; // Only send if entered

    print("Full Name: $fullName");
    print("Email: $email");
    if (newPassword != null) {
      print("New Password Set (length: ${newPassword.length})");
    }

    // --- Example API Call Structure ---
    /*
    try {
      final success = await yourApiService.updateProfile(
        fullName: fullName,
        email: email,
        password: newPassword, // Send null if not changing
        // You might also send the image URL if uploaded separately
      );

      if (success && mounted) {
        _showSuccessSnackBar("Profile updated successfully!");
        // Optionally navigate back after save
        // Navigator.pop(context);
      } else if (mounted) {
         _showErrorSnackBar("Failed to update profile.");
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar("An error occurred: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
    */

    // Simulate API delay for now
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      _showSuccessSnackBar("Profile saved (Simulated).");
      setState(() {
        _isLoading = false;
      });
      // Navigator.pop(context); // Optionally pop after save
    }
  }

  // --- Delete Account Logic (Placeholder) ---
  Future<void> _deleteAccount() async {
    // --- Show Confirmation Dialog ---
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
              "This action is permanent and cannot be undone. Are you sure you want to delete your account?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false), // Return false
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: errorRed),
              child: const Text("Delete"),
              onPressed: () => Navigator.of(context).pop(true), // Return true
            ),
          ],
        );
      },
    );

    // --- If User Confirmed ---
    if (confirmDelete == true) {
      print("Deleting account...");
      setState(() {
        _isLoading = true;
      }); // Optional: show loading on delete button

      // TODO: Implement API call to delete the user account
      // This might require re-authentication (asking for password again)
      /*
          try {
            final bool deleted = await yourApiService.deleteAccount(password: currentPassword); // You might need current password
            if (deleted && mounted) {
               _showSuccessSnackBar("Account deleted successfully.");
               // TODO: Log user out and navigate to login/signup screen
               // Example: widget.onAccountDeleted(); // Callback to parent widget
               Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage(isLoggedIn: ValueNotifier(false))), // Go to login
                  (Route<dynamic> route) => false, // Remove all previous routes
               );
            } else if(mounted) {
               _showErrorSnackBar("Failed to delete account.");
            }
          } catch(e) {
             if (mounted) _showErrorSnackBar("An error occurred during deletion: $e");
          } finally {
             if (mounted) setState(() { _isLoading = false; });
          }
          */

      // Simulate API delay for now
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        _showSuccessSnackBar("Account deletion initiated (Simulated).");
        setState(() {
          _isLoading = false;
        });
        // TODO: Navigate away after simulation
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1.0, // Subtle shadow line
        // Leading is automatically added by Navigator
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreyText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              color: darkGreyText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true, // Center title if desired
        actions: [
          // Save Button
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading &&
                    !ModalRoute.of(context)!
                        .isCurrent // Don't show loading if just navigating back
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryBlue))
                : const Text(
                    'Save',
                    style: TextStyle(
                        color: primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(width: 10), // Padding for save button
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Make Delete button stretch
            children: [
              const SizedBox(height: 20),
              // --- Profile Picture Section ---
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor:
                          Colors.grey.shade300, // Placeholder color
                      // Use FileImage if _profileImageFile is not null, otherwise NetworkImage or Placeholder
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!)
                          : const NetworkImage(// Placeholder network image
                                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT7vkD3moA7gaQ6aFUm7RnB5902Zv7Tj7zI2A&s')
                              as ImageProvider, // Replace with actual user image URL if available
                      child: _profileImageFile ==
                                  null && /* no network image url */
                              false
                          // ignore: dead_code
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white) // Placeholder Icon
                          : null,
                    ),
                    // Camera Icon Overlay
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _pickImage,
                  child: const Text(
                    'Change Photo',
                    style: TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 35),

              // --- Form Fields ---
              _buildLabel('Full Name'),
              _buildProfileTextField(
                // Use specific helper
                controller: _fullNameController,
                hintText: 'Enter your full name',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Email Address'),
              _buildProfileTextField(
                controller: _emailController,
                hintText: 'Enter your email address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                enabled:
                    false, // Typically email is not editable or needs verification
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email cannot be empty';
                  }
                  final emailRegex = RegExp(
                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Password'),
              _buildProfilePasswordField(
                // Use specific helper
                controller: _passwordController,
                hintText:
                    'Enter new password (optional)', // Use dots or leave hint
                icon: _isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                isPasswordVisible: _isPasswordVisible,
                toggleVisibility: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                validator: (value) {
                  // Password is optional here, but if entered, validate length
                  if (value != null && value.isNotEmpty && value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null; // No error if empty or valid
                },
              ),
              const SizedBox(height: 8),
              // Helper text for password
              Padding(
                padding: const EdgeInsets.only(left: 4.0), // Slight indent
                child: Text(
                  'Must be at least 8 characters long',
                  style: TextStyle(color: lightGreyText, fontSize: 12),
                ),
              ),

              const SizedBox(height: 40),

              // --- Delete Account Button ---
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Delete Account'),
                onPressed: _isLoading ? null : _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: errorRed, // Red text and icon
                  side: BorderSide(
                      color: Colors.grey.shade300), // Light grey border
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // --- Specific Helpers for Edit Profile TextFields ---

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

  Widget _buildProfileTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool enabled = true, // Added enabled flag
    TextInputType keyboardType = TextInputType.text,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      enabled: enabled, // Control editability
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(
          color:
              enabled ? darkGreyText : Colors.grey.shade600), // Dim if disabled
      decoration: InputDecoration(
        // hintText: hintText, // Using controller's initial value instead of hint
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        // Use suffixIcon as per the image
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Icon(icon, color: lightGreyText, size: 20),
        ),
        suffixIconConstraints: const BoxConstraints(
            minHeight: 20, minWidth: 20), // Ensure icon fits
        filled: true,
        fillColor: enabled
            ? lightGrey
            : Colors.grey.shade200, // Different color if disabled
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1.0)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: enabled ? borderColor : Colors.grey.shade400,
                width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: enabled ? primaryBlue : Colors.grey.shade400,
                width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorRed, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorRed, width: 1.5)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.grey.shade400,
                width: 1.0)), // Style when disabled
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
    );
  }

  Widget _buildProfilePasswordField({
    required TextEditingController controller,
    required String hintText, // Hint is useful here
    required IconData icon,
    required bool isPasswordVisible,
    required VoidCallback toggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isPasswordVisible,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hintText, // Show hint for new password
        hintStyle:
            TextStyle(color: lightGreyText.withOpacity(0.7), fontSize: 14),
        // Use suffixIcon for visibility toggle
        suffixIcon: IconButton(
          icon: Icon(icon, color: lightGreyText, size: 20),
          onPressed: toggleVisibility,
          splashRadius: 20, // Smaller splash for icon button
        ),
        suffixIconConstraints:
            const BoxConstraints(minHeight: 20, minWidth: 20),
        filled: true, fillColor: lightGrey,
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
            borderSide: const BorderSide(color: errorRed, width: 1.0)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: errorRed, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
    );
  }

  // --- Snackbars ---
  // ignore: unused_element
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600, // Success color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

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
