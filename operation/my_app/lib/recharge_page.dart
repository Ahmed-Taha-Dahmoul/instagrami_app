import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for FilteringTextInputFormatter
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart'; // Your AppConfig for baseUrl

class RechargePage extends StatefulWidget {
  @override
  _RechargePageState createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  // Renamed controller for clarity
  final TextEditingController _cardNumberController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>(); // Key for validation

  int? _selectedAmount;
  bool _isSubmitting = false;
  String? _apiErrorMessage; // Specifically for API/network errors displayed in Snackbar
  String? _apiSuccessMessage; // Specifically for API success displayed in Snackbar

  // --- Define colors for styling ---
  final Color primaryColor = Colors.blueAccent;
  final Color selectedColor = Colors.blue.shade100;
  final Color borderColor = Colors.grey.shade300;
  final Color selectedBorderColor = Colors.blueAccent;
  final Color backgroundColor = Colors.grey.shade200;
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.grey.shade800;
  final Color textColor = Colors.black87;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color errorColor = Colors.red.shade600;
  final Color successColor = Colors.green.shade600;
  // --- End Color Definitions ---

  // Placeholder URLs for images - replace with your actual image assets or URLs
  final String coinImage10 = 'assets/payment/1DT.png';
  final String coinImage50 = 'assets/payment/5DT.png';

  @override
  void dispose() {
    _cardNumberController.dispose(); // Dispose the controller
    super.dispose();
  }

  // Helper to show Snackbars
  void _showSnackbar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Remove previous snackbar if any
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating, // Floating style looks nice
        margin: EdgeInsets.all(10), // Add margin for floating style
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitRecharge() async {
    // --- Start Validation ---
    setState(() {
      _apiErrorMessage = null; // Clear previous API errors on new attempt
      _apiSuccessMessage = null;
    });

    // 1. Validate amount selection
    if (_selectedAmount == null) {
      _showSnackbar("Please select a recharge amount.", errorColor);
      return; // Stop submission
    }

    // 2. Validate Form (which includes Card Number)
    if (!_formKey.currentState!.validate()) {
      // Snackbar will likely be shown by the validator itself due to autovalidateMode or user interaction
      // but you could add a general form error message here if desired.
      // _showSnackbar("Please correct the errors in the form.", errorColor);
      return; // Stop submission if form is not valid
    }
    // --- End Validation ---

    // If validation passes:
    _formKey.currentState!.save(); // Optional: Save form data if using onSaved

    setState(() {
      _isSubmitting = true;
    });

    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      if (mounted) {
        setState(() {
          _apiErrorMessage = "Authentication error. Please log in again.";
          _isSubmitting = false;
        });
        _showSnackbar(_apiErrorMessage!, errorColor);
      }
      return;
    }

    // Get card number from the controller
    String cardNumber = _cardNumberController.text.trim();
    // Determine the correct API endpoint based on selection
    String endpoint = "payment/add-payment-$_selectedAmount/";
    Uri url = Uri.parse("${AppConfig.baseUrl}$endpoint");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        // --- Send 'card_number' in the body as per backend ---
        body: jsonEncode({
          'card_number': cardNumber,
        }),
      );

      if (!mounted) return; // Check if the widget is still in the tree

      final responseBody = response.body; // Store response body for parsing

      // --- Check for 201 Created status from backend ---
      if (response.statusCode == 201) {
        String successMsg = "Recharge successful!"; // Default message
        String newBalanceMsg = "";
        try {
          // Try parsing backend success message and new balance
          final decodedBody = jsonDecode(responseBody);
          if (decodedBody is Map) {
            if (decodedBody.containsKey('message')) {
              successMsg = decodedBody['message'];
            }
            if (decodedBody.containsKey('new_balance')) {
              newBalanceMsg = "\nNew Balance: ${decodedBody['new_balance']}";
            }
          }
        } catch (_) {
          // Ignore parsing errors on success, use the default message
          print("Could not parse success response body: $responseBody");
        }

        setState(() {
          _apiSuccessMessage = successMsg + newBalanceMsg; // Combine messages
          _apiErrorMessage = null;
          _selectedAmount = null; // Reset selection
          _cardNumberController.clear(); // Clear the card number field
          _isSubmitting = false;
          // Optionally reset form validation state visually if needed, but clear() often suffices
          // _formKey.currentState?.reset();
        });
        _showSnackbar(_apiSuccessMessage!, successColor);

        // Navigate back to profile page after a short delay, indicating success
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true); // Pass true back to ProfilePage
        });

      } else {
        // --- Handle API Errors (400, 500, etc.) ---
        String errorMsg = "Failed (${response.statusCode}).";
        try {
          final decodedBody = jsonDecode(responseBody);
          if (decodedBody is Map) {
            // Check for specific keys from backend error response
            if (decodedBody.containsKey('error')) {
              errorMsg += " ${decodedBody['error']}";
            }
            // Append 'details' if they exist and are different from 'error'
            if (decodedBody.containsKey('details') && decodedBody['details'] != decodedBody['error']) {
              errorMsg += " (${decodedBody['details']})";
            }
            // Fallback if specific keys aren't present but it's a map
            else if (!decodedBody.containsKey('error') && !decodedBody.containsKey('details')) {
               errorMsg += " ${responseBody.length > 150 ? responseBody.substring(0, 150) + '...' : responseBody}";
            }
          } else {
            // Not a map, show raw body (truncated)
            errorMsg += " ${responseBody.length > 150 ? responseBody.substring(0, 150) + '...' : responseBody}";
          }
        } catch (_) {
          // Error parsing the error response itself
          errorMsg += " Could not parse error details.";
          print("Could not parse error response body: $responseBody");
        }
        setState(() {
          _apiErrorMessage = errorMsg;
          _apiSuccessMessage = null;
          _isSubmitting = false;
        });
        _showSnackbar(_apiErrorMessage!, errorColor);
      }
    } catch (e) { // Catch network exceptions, timeouts, etc.
      if (!mounted) return;
      setState(() {
        _apiErrorMessage = "An error occurred: $e";
        _apiSuccessMessage = null;
        _isSubmitting = false;
      });
      _showSnackbar(_apiErrorMessage!, errorColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor, // Use defined color
      appBar: AppBar(
        title: Text("Recharge Coins"),
        backgroundColor: cardBackgroundColor, // White AppBar
        foregroundColor: headingColor,      // Darker title text
        elevation: 1,                       // Subtle shadow
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headingColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0), // Apply padding around the content
        child: Form( // Wrap content in a Form widget for validation
          key: _formKey, // Assign the key
          child: SingleChildScrollView( // Prevent overflow if content is long
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make button stretch full width
              children: [
                Text(
                  "Select Recharge Amount",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headingColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 25),

                // Option Boxes using Row for horizontal layout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute space
                  children: [
                    _buildRechargeOptionBox(
                      amount: 10,
                      label: "Basic Pack",
                      imagePath: coinImage10,
                      isSelected: _selectedAmount == 10,
                      onTap: () => setState(() { _selectedAmount = 10; }),
                    ),
                    _buildRechargeOptionBox(
                      amount: 50,
                      label: "Value Pack",
                      imagePath: coinImage50,
                      isSelected: _selectedAmount == 50,
                      onTap: () => setState(() { _selectedAmount = 50; }),
                    ),
                  ],
                ),

                SizedBox(height: 35),

                // Card Number Input Field (Mandatory)
                TextFormField(
                  controller: _cardNumberController, // Assign controller
                  decoration: InputDecoration(
                    labelText: "Card Number *", // Indicate mandatory field
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: "Enter your card number",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder( // Default border
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder( // Border when enabled but not focused
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder( // Border when focused
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(color: primaryColor, width: 1.5), // Highlight focus
                    ),
                    errorBorder: OutlineInputBorder( // Border on validation error
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(color: errorColor, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder( // Border on validation error + focus
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(color: errorColor, width: 1.5),
                    ),
                    filled: true, // Enable background fill
                    fillColor: cardBackgroundColor, // White background for field
                    prefixIcon: Icon(Icons.credit_card, color: secondaryTextColor), // Card icon
                  ),
                  keyboardType: TextInputType.number, // Numeric keyboard
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly // Allow only digits
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction, // Validate as user types/leaves field
                  validator: (value) { // Validation logic
                    if (value == null || value.trim().isEmpty) {
                      return 'Card number cannot be empty'; // Presence check
                    }
                    // Basic length check (adjust as needed for specific card types)
                    if (value.trim().length < 13 || value.trim().length > 19) {
                       return 'Please enter a valid card number length';
                    }
                    // Consider adding Luhn algorithm check here for better validation
                    return null; // Return null means validation passed
                  },
                ),

                SizedBox(height: 35),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor, // Use defined primary color
                    foregroundColor: Colors.white, // White text/icon
                    padding: EdgeInsets.symmetric(vertical: 16), // Vertical padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    elevation: 2, // Slight shadow
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), // Button text style
                  ),
                  // Disable button while submitting request
                  onPressed: _isSubmitting ? null : _submitRecharge,
                  child: _isSubmitting
                      ? SizedBox( // Show loading indicator when submitting
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text("Submit Recharge"), // Button text
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget to build the selectable recharge option boxes
  Widget _buildRechargeOptionBox({
    required int amount,
    required String label,
    required String imagePath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap, // Handle tap event
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4, // Responsive width
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16), // Internal padding
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : cardBackgroundColor, // Background based on selection
          borderRadius: BorderRadius.circular(15), // Rounded corners
          border: Border.all(
            color: isSelected ? selectedBorderColor : borderColor, // Border based on selection
            width: isSelected ? 2.0 : 1.5, // Thicker border when selected
          ),
          boxShadow: isSelected ? [ // Subtle glow shadow when selected
             BoxShadow(
               color: primaryColor.withOpacity(0.2),
               blurRadius: 8,
               spreadRadius: 1,
             )
           ] : [ // Standard subtle shadow
             BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 6,
              spreadRadius: 1,
              offset: Offset(0, 2)
            )
           ],
        ),
        child: Stack( // Use Stack for overlaying the check icon
          clipBehavior: Clip.none, // Allow check icon to overflow slightly
          alignment: Alignment.center, // Center the main content (Column)
          children: [
            // Main content of the box
            Column(
              mainAxisSize: MainAxisSize.min, // Fit content height
              children: [
                // Display the image for the coin pack
                Image.asset(
                  imagePath,
                  height: 55, // Image height
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    print("Error loading image: $imagePath, Error: $error");
                    return Icon(Icons.monetization_on_outlined, size: 55, color: Colors.orangeAccent);
                  },
                ),
                SizedBox(height: 12),
                // Display the amount
                Text(
                  "$amount Coins",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                SizedBox(height: 5),
                // Display the pack label
                Text(
                  label,
                  style: TextStyle(fontSize: 14, color: secondaryTextColor),
                ),
              ],
            ),
            // Check Icon Overlay (only shown when selected)
            if (isSelected)
              Positioned(
                top: -12, // Position slightly outside the top-right
                right: -12,
                child: CircleAvatar( // Use CircleAvatar for a perfect circle background
                  radius: 12,
                  backgroundColor: successColor, // Green background for check
                  child: Icon(Icons.check, color: Colors.white, size: 16), // White check icon
                ),
              ),
          ],
        ),
      ),
    );
  }
}