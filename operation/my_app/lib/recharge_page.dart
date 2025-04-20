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
  final Color primaryColor = Colors.blue;
  final Color selectedColor = Colors.blue.shade50;
  final Color borderColor = Colors.grey.shade300;
  final Color selectedBorderColor = Colors.blue;
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.grey.shade700;
  final Color textColor = Colors.black87;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color errorColor = Colors.red.shade600;
  final Color successColor = Colors.green.shade600;
  // --- End Color Definitions ---

  // Placeholder paths - ensure these assets exist
  // final String coinImage10 = 'assets/payment/1DT.png'; // Example path
  // final String coinImage50 = 'assets/payment/5DT.png'; // Example path

  // --- Operator Definitions (Names and Icons) ---
  final Map<String, Widget> operatorIcons = {
    'Ooredoo': Image.asset('assets/operators/Ooredoo_logo.png', height: 30),
    'Telecom': Image.asset('assets/operators/tunisie_telcom.png', height: 35),
    'Orange': Image.asset('assets/operators/Orange-Logo.png', height: 35),
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

  // --- Renamed original submit function to handle only the API call ---
  Future<void> _performRechargeApiCall() async {
    if (!mounted) return; // Check mount status before proceeding

    setState(() {
      _isSubmitting = true;
      _apiErrorMessage = null;
      _apiSuccessMessage = null;
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
    // Endpoint uses selected amount
    String endpoint = "payment/add-payment-$_selectedAmount/";
    Uri url = Uri.parse("${AppConfig.baseUrl}$endpoint");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'card_number': cardNumber,
          'operator': _selectedOperator,
          // Add amount to body if backend requires it, otherwise keep in URL
          // 'amount': _selectedAmount,
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

        final finalSuccessMessage = successMsg + newBalanceMsg;

        setState(() {
          _apiSuccessMessage = finalSuccessMessage;
          _apiErrorMessage = null;
          _isSubmitting = false; // Set submitting false *before* popping
          // Keep form data for a moment while showing success
        });
        _showSnackbar(_apiSuccessMessage!, successColor);

        // --- Navigate back after a short delay ---
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // Pop the current RechargePage and return 'true' to indicate success
            Navigator.of(context).pop(true);
          }
        });
        // No need to reset form here, as the page will be popped

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
        if (mounted) {
           setState(() {
             _apiErrorMessage = errorMsg;
             _apiSuccessMessage = null;
             _isSubmitting = false;
           });
           _showSnackbar(_apiErrorMessage!, errorColor);
        }
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

  // --- New function to handle validation and show confirmation ---
  Future<void> _handleSubmissionAttempt() async {
     setState(() {
      _apiErrorMessage = null; // Clear previous errors
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

    _formKey.currentState!.save(); // Save form data

    // --- Show Confirmation Dialog ---
    final bool? confirmed = await _showConfirmationDialog();

    // --- If confirmed, proceed with API call ---
    if (confirmed == true) {
       // Make sure we are still mounted after the dialog
       if (mounted) {
         await _performRechargeApiCall();
       }
    } else {
       // User cancelled, do nothing or maybe show a cancellation message
       // print("Recharge cancelled by user.");
    }
  }

  // --- New Confirmation Dialog Widget ---
  Future<bool?> _showConfirmationDialog() {
    // Get the icon for the selected operator
    Widget operatorIcon = operatorIcons[_selectedOperator!] ?? Icon(Icons.phone_android, color: secondaryTextColor); // Fallback icon

    return showDialog<bool>(
      context: context,
      barrierDismissible: !_isSubmitting, // Prevent dismissal while submitting
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          backgroundColor: cardBackgroundColor,
          title: Text(
            "Confirm Recharge",
            style: TextStyle(color: headingColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min, // Make column height fit content
            children: <Widget>[
              Divider(color: borderColor),
              SizedBox(height: 15),
              Row(
                children: [
                  Text("Operator:", style: TextStyle(color: secondaryTextColor, fontSize: 15)),
                  Spacer(),
                  operatorIcon, // Display operator icon
                  SizedBox(width: 8),
                  Text(
                    _selectedOperator!,
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 15),
              Row(
                children: [
                  Text("Amount:", style: TextStyle(color: secondaryTextColor, fontSize: 15)),
                  Spacer(),
                  Icon(Icons.monetization_on_outlined, color: Colors.orange.shade600, size: 20), // Coin icon
                  SizedBox(width: 8),
                  Text(
                    "$_selectedAmount Coins",
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 15),
              SizedBox(height: 10),
              Divider(color: borderColor),
            ],
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          actions: <Widget>[
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(color: secondaryTextColor, fontSize: 15),
              ),
              onPressed: _isSubmitting ? null : () { // Disable cancel if already submitting
                Navigator.of(context).pop(false); // Close dialog, return false
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Disable confirm button if already submitting
              onPressed: _isSubmitting ? null : () {
                Navigator.of(context).pop(true); // Close dialog, return true
              },
              child: Text("Confirm", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Recharge Balance", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: cardBackgroundColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          // Make sure back button works even if submitting (user might want to cancel)
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Operator Selection ---
                Text(
                  "Select Operator",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: headingColor),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: operatorIcons.keys.map((operatorName) {
                    return _buildOperatorOptionBox(
                      name: operatorName,
                      iconWidget: operatorIcons[operatorName]!,
                      isSelected: _selectedOperator == operatorName,
                      // Disable selection if submitting
                      onTap: _isSubmitting ? (){} : () => setState(() { _selectedOperator = operatorName; }),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRechargeOptionBox(
                      amount: 10,
                      isSelected: _selectedAmount == 10,
                       // Disable selection if submitting
                      onTap: _isSubmitting ? (){} : () => setState(() { _selectedAmount = 10; }),
                    ),
                    _buildRechargeOptionBox(
                      amount: 50,
                      isSelected: _selectedAmount == 50,
                      // Disable selection if submitting
                      onTap: _isSubmitting ? (){} : () => setState(() { _selectedAmount = 50; }),
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
                  // Disable input if submitting
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
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
                     disabledBorder: OutlineInputBorder( // Style when disabled
                       borderRadius: BorderRadius.circular(10),
                       borderSide: BorderSide(color: Colors.grey.shade300),
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
                    fillColor: _isSubmitting ? Colors.grey.shade100 : cardBackgroundColor, // Grey out when disabled
                    prefixIcon: Icon(Icons.credit_card_outlined, color: secondaryTextColor, size: 20),
                    contentPadding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
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
                    if (value.trim().length < 13 || value.trim().length > 19) { // Adjust length as needed
                       return 'Enter a valid card number length';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40),

                // --- Submit Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                       // Slightly greyed out when loading
                      disabledBackgroundColor: primaryColor.withOpacity(0.7),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                      textStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    // Calls the validation/confirmation handler now
                    onPressed: _isSubmitting ? null : _handleSubmissionAttempt,
                    child: _isSubmitting
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        // Changed text slightly to imply it starts the process
                        : Text("Proceed to Recharge"),
                  ),
                ),
                 SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Operator Selection Boxes (No changes needed here, but added disable logic in build)
  Widget _buildOperatorOptionBox({
    required String name,
    required Widget iconWidget,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    double boxWidth = (MediaQuery.of(context).size.width - 40 - 30) / 3;
    bool isDisabled = _isSubmitting; // Check if should be disabled

    return IgnorePointer( // Makes the GestureDetector ignore taps when disabled
      ignoring: isDisabled,
      child: GestureDetector(
        onTap: onTap, // onTap itself is conditionally disabled in build method
        child: Opacity( // Visually grey out when disabled
          opacity: isDisabled ? 0.5 : 1.0,
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
               boxShadow: [
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
                iconWidget,
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
        ),
      ),
    );
  }


  // Helper for Amount Selection Boxes (No changes needed here, but added disable logic in build)
  Widget _buildRechargeOptionBox({
    required int amount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    double boxWidth = (MediaQuery.of(context).size.width - 40 - 20) / 2;
    bool isDisabled = _isSubmitting; // Check if should be disabled

     return IgnorePointer( // Makes the GestureDetector ignore taps when disabled
      ignoring: isDisabled,
      child: GestureDetector(
        onTap: onTap, // onTap itself is conditionally disabled in build method
        child: Opacity( // Visually grey out when disabled
          opacity: isDisabled ? 0.5 : 1.0,
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
              boxShadow: [
                 BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2)
                )
               ],
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                     Icons.monetization_on_outlined, // Placeholder Coin Icon
                     color: Colors.orange.shade600,
                     size: 24,
                  ),
                  SizedBox(width: 10),
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
        ),
      ),
    );
  }
}