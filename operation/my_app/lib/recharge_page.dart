import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for FilteringTextInputFormatter
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Make sure you have this config file or replace AppConfig.baseUrl with your actual URL string
import 'config.dart';




class RechargePage extends StatefulWidget {
  @override
  _RechargePageState createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final TextEditingController _cardNumberController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedOperator; // State for selected operator
  int? _selectedAmount;     // State for selected amount
  bool _isSubmitting = false;
  String? _apiErrorMessage;
  String? _apiSuccessMessage;

  // --- Define colors for styling ---
  final Color primaryColor = Colors.blue; // Adjusted to match image button
  final Color selectedColor = Colors.blue.shade50; // Lighter blue for selection background
  final Color borderColor = Colors.grey.shade300;
  final Color selectedBorderColor = Colors.blue; // Blue border when selected
  final Color backgroundColor = Colors.grey.shade100; // Light grey background
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.grey.shade700; // Slightly lighter heading
  final Color textColor = Colors.black87;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color errorColor = Colors.red.shade600;
  final Color successColor = Colors.green.shade600;
  // --- End Color Definitions ---

  // Placeholder paths - ensure these assets exist in your project's pubspec.yaml and path
  final String coinImage10 = 'assets/payment/1DT.png'; // Example path
  final String coinImage50 = 'assets/payment/5DT.png'; // Example path

  // --- Operator Definitions (Names and Icons) ---
  // !! Replace Icons with your Image.asset widgets later !!
  final Map<String, Widget> operatorIcons = {
    'Ooredoo': Image.asset('assets/operators/Ooredoo_logo.png', height: 35), // Added path
    'Telecom': Image.asset('assets/operators/tunisie_telcom.png', height: 35), // Added path
    'Orange': Image.asset('assets/operators/Orange-Logo.png', height: 35),   // Added path
  };
  // --- End Operator Definitions ---

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submitRecharge() async {
    setState(() {
      _apiErrorMessage = null;
      _apiSuccessMessage = null;
    });

    // --- Validation ---
    if (_selectedOperator == null) {
       _showSnackbar("Please select an operator.", errorColor);
       return;
    }
    if (_selectedAmount == null) {
      _showSnackbar("Please select a recharge amount.", errorColor);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      // Validation messages handled by TextFormField's validator
      return;
    }
    // --- End Validation ---

    _formKey.currentState!.save();

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

    String cardNumber = _cardNumberController.text.trim();
    // TODO: Update endpoint/body if operator needs to be sent to backend
    String endpoint = "payment/add-payment-$_selectedAmount/"; // Assumes amount is in URL
    Uri url = Uri.parse("${AppConfig.baseUrl}$endpoint");

    try {
      // TODO: Modify body if backend expects operator AND card_number
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'card_number': cardNumber,
          'operator': _selectedOperator, 
        }),
      );

      if (!mounted) return;

      final responseBody = response.body;

      if (response.statusCode == 201) { // Success
        String successMsg = "Recharge successful!";
        String newBalanceMsg = "";
        try {
          final decodedBody = jsonDecode(responseBody);
          if (decodedBody is Map) {
            successMsg = decodedBody['message'] ?? successMsg;
            if (decodedBody.containsKey('new_balance')) {
              newBalanceMsg = "\nNew Balance: ${decodedBody['new_balance']}";
            }
          }
        } catch (_) {
           print("Could not parse success response body: $responseBody");
        }

        setState(() {
          _apiSuccessMessage = successMsg + newBalanceMsg;
          _apiErrorMessage = null;
          _selectedOperator = null; // Reset operator
          _selectedAmount = null;   // Reset amount
          _cardNumberController.clear();
          _isSubmitting = false;
          // Reset form state visually
           _formKey.currentState?.reset();
        });
        _showSnackbar(_apiSuccessMessage!, successColor);

        // Optional: Navigate back after success
        // Future.delayed(Duration(seconds: 2), () {
        //   if (mounted) Navigator.pop(context, true);
        // });

      } else { // Handle API Errors
        String errorMsg = "Failed (${response.statusCode}).";
         try {
           final decodedBody = jsonDecode(responseBody);
           if (decodedBody is Map) {
              errorMsg += " ${decodedBody['error'] ?? decodedBody['message'] ?? ''}";
              if (decodedBody.containsKey('details') && decodedBody['details'] != (decodedBody['error'] ?? decodedBody['message'])) {
                 errorMsg += " (${decodedBody['details']})";
              }
           } else {
              errorMsg += " ${responseBody.length > 150 ? responseBody.substring(0, 150) + '...' : responseBody}";
           }
         } catch (_) {
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
    } catch (e) { // Catch network exceptions
      if (!mounted) return;
      setState(() {
        _apiErrorMessage = "An network error occurred: $e";
        _apiSuccessMessage = null;
        _isSubmitting = false;
      });
      _showSnackbar(_apiErrorMessage!, errorColor);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Recharge Balance", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardBackgroundColor, // White AppBar
        elevation: 0.5, // Subtle shadow
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align titles to the left
              children: [
                // --- Operator Selection ---
                Text(
                  "Select Operator",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: headingColor),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out operators
                  children: operatorIcons.keys.map((operatorName) {
                    return _buildOperatorOptionBox(
                      name: operatorName,
                      // !! Replace this Icon with your Image.asset widget !!
                      iconWidget: operatorIcons[operatorName]!,
                      isSelected: _selectedOperator == operatorName,
                      onTap: () => setState(() { _selectedOperator = operatorName; }),
                    );
                  }).toList(),
                ),
                SizedBox(height: 30),

                // --- Amount Selection ---
                Text(
                  "Select Amount",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: headingColor),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out amounts
                  children: [
                    _buildRechargeOptionBox(
                      amount: 10,
                      // imagePath: coinImage10, // Use this if you have the image asset
                      isSelected: _selectedAmount == 10,
                      onTap: () => setState(() { _selectedAmount = 10; }),
                    ),
                    _buildRechargeOptionBox(
                      amount: 50,
                      // imagePath: coinImage50, // Use this if you have the image asset
                      isSelected: _selectedAmount == 50,
                      onTap: () => setState(() { _selectedAmount = 50; }),
                    ),
                  ],
                ),
                SizedBox(height: 30),

                // --- Card Number Input ---
                Text(
                  "Enter Card Number",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: headingColor),
                ),
                SizedBox(height: 15),
                TextFormField(
                  controller: _cardNumberController,
                  decoration: InputDecoration(
                    // labelText: "Enter Card Number", // Using hintText is closer to image
                    // labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: "Enter your card number",
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(10),
                       borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(10),
                       borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(10),
                       borderSide: BorderSide(color: errorColor, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(10),
                       borderSide: BorderSide(color: errorColor, width: 1.5),
                    ),
                    filled: true,
                    fillColor: cardBackgroundColor,
                    prefixIcon: Icon(Icons.credit_card_outlined, color: secondaryTextColor, size: 20), // Icon inside
                    contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0), // Adjust padding
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Card number cannot be empty';
                    }
                    // Basic length check - adjust if needed
                    if (value.trim().length < 13 || value.trim().length > 19) {
                       return 'Enter a valid card number length';
                    }
                    return null; // Valid
                  },
                ),
                SizedBox(height: 40), // More space before button

                // --- Submit Button ---
                SizedBox( // Ensure button takes full width
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15), // Slightly less padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // Match input field radius
                      ),
                      elevation: 2,
                      textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _isSubmitting ? null : _submitRecharge,
                    child: _isSubmitting
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text("Submit Recharge"),
                  ),
                ),
                 SizedBox(height: 20), // Padding at the bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Operator Selection Boxes
  Widget _buildOperatorOptionBox({
    required String name,
    required Widget iconWidget, // Changed to Widget to allow Icon or Image
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Calculate width dynamically - approx 1/3rd minus padding/spacing
    double boxWidth = (MediaQuery.of(context).size.width - 40 - 30) / 3; // (Screenwidth - horizontal padding - space between boxes) / 3

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: boxWidth,
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : cardBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorderColor : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
           boxShadow: [ // Subtle shadow
             BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2)
            )
           ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // !! Replace Icon with your Image.asset if needed !!
            iconWidget, // Use the provided widget (Icon or Image)
            SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  // Helper for Amount Selection Boxes
  Widget _buildRechargeOptionBox({
    required int amount,
    // required String imagePath, // Uncomment and use if you have image assets
    required bool isSelected,
    required VoidCallback onTap,
  }) {
     // Calculate width dynamically - approx 1/2 minus padding/spacing
    double boxWidth = (MediaQuery.of(context).size.width - 40 - 20) / 2; // (Screenwidth - horizontal padding - space between) / 2

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: boxWidth,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : cardBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorderColor : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [ // Subtle shadow
             BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2)
            )
           ],
        ),
        child: Row( // Changed to Row to match image layout (Icon | Text)
            mainAxisAlignment: MainAxisAlignment.center, // Center content horizontally
            children: [
              // !! Replace Icon with your Image.asset(imagePath, height: 24, ...) !!
              Icon(
                 Icons.monetization_on_outlined, // Placeholder Coin Icon
                 color: Colors.orange.shade600,
                 size: 24,
              ),
              SizedBox(width: 10), // Space between icon and text
              Text(
                "$amount Coins",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: textColor
                ),
              ),
            ],
          ),
      ),
    );
  }
}