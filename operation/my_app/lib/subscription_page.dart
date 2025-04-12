import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // For Timer

import 'config.dart'; // Your AppConfig
import 'recharge_page.dart'; // <-- Import the RechargePage

// --- Data Models ---
class ActiveSubscription {
  final String plan;
  final DateTime startDate;
  final DateTime endDate;

  ActiveSubscription({
    required this.plan,
    required this.startDate,
    required this.endDate,
  });

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    DateTime? parsedEndDate = DateTime.tryParse(json['end_date'] ?? '');
    if (parsedEndDate == null) {
      print("Warning: Could not parse end_date: ${json['end_date']}");
      // Consider a more robust fallback or error handling if end_date is crucial
      parsedEndDate = DateTime.now()
          .add(Duration(days: -1)); // Mark as expired if unparseable
    }
    DateTime? parsedStartDate = DateTime.tryParse(json['start_date'] ?? '');
    if (parsedStartDate == null) {
      print("Warning: Could not parse start_date: ${json['start_date']}");
      parsedStartDate = DateTime.now();
    }
    return ActiveSubscription(
      plan: json['plan']?.toString().toLowerCase() ??
          'unknown', // Ensure lowercase
      startDate: parsedStartDate,
      endDate: parsedEndDate,
    );
  }
}

class UserCreditData {
  final String username;
  final String creditBalance;

  UserCreditData({required this.username, required this.creditBalance});

  factory UserCreditData.fromJson(Map<String, dynamic> json) {
    // Ensure credit_balance is treated as a string for potential decimals
    String balance = '0.0000';
    if (json['credit_balance'] != null) {
      // Attempt to parse and format, handle potential errors
      try {
        double parsedBalance = double.parse(json['credit_balance'].toString());
        balance =
            parsedBalance.toStringAsFixed(4); // Format to 4 decimal places
      } catch (e) {
        print(
            "Warning: Could not parse credit_balance: ${json['credit_balance']}. Using '0.0000'.");
        balance = '0.0000';
      }
    }

    return UserCreditData(
      username: json['user']?.toString() ?? 'User',
      creditBalance: balance,
    );
  }
}
// --- End Data Models ---

enum SubscriptionPlan { none, trial, premium, vip }

class SubscriptionPage extends StatefulWidget {
  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // State variables
  SubscriptionPlan _currentPlan = SubscriptionPlan.none;
  ActiveSubscription? _activeSubscriptionData;
  UserCreditData? _userCredit;
  bool _isLoading = true;
  bool _isUpgrading = false; // Only true during the API call
  String? _errorMessage;
  String _timeRemaining = "";
  Timer? _timer;

  bool _showYearly = false; // Assuming you might add this toggle later

  // --- Colors (Keep your theme colors) ---
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.black87;
  final Color textColor = Colors.grey.shade800;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color cardHighlightTextColor = Colors.white;
  final Color trialColor = Color(0xFF4AC4AE);
  final Color premiumColor =
      Color(0xFFE6C76A); // Also used for Add Funds button
  final Color vipColor = Color(0xFFFA8282);
  final Color activePlanHighlightColor = Colors.indigoAccent.shade400;
  final Color activePlanBorderColor = Colors.indigoAccent.shade100;
  final Color errorColor = Colors.red.shade700;
  final Color warningColor = Colors.orange.shade500;
  // --- End colors ---

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Helper Functions for Plan Visuals ---
  IconData _getPlanIcon(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.trial:
        return Icons.hourglass_empty_rounded;
      case SubscriptionPlan.premium:
        return Icons.star_rounded;
      case SubscriptionPlan.vip:
        return Icons.diamond_rounded;
      case SubscriptionPlan.none:
      // ignore: unreachable_switch_default
      default:
        return Icons.help_outline;
    }
  }

  Color _getPlanColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.trial:
        return trialColor;
      case SubscriptionPlan.premium:
        return premiumColor;
      case SubscriptionPlan.vip:
        return vipColor;
      case SubscriptionPlan.none:
      // ignore: unreachable_switch_default
      default:
        return Colors.grey;
    }
  }
  // --- End Helper Functions ---

  // --- Data Fetching Logic (Mostly Unchanged) ---
  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _timeRemaining = "";
      _timer?.cancel();
      // Reset state before fetch
      _activeSubscriptionData = null;
      _userCredit = null;
      _currentPlan = SubscriptionPlan.none;
    });

    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "Authentication error. Please log in again.";
          _isLoading = false;
        });
      }
      return;
    }

    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json"
    };
    String? fetchErrorMsg;

    try {
      // Fetch concurrently
      final results = await Future.wait([
        _fetchSubscription(headers).catchError((e) {
          print("Subscription fetch failed in Future.wait: $e");
          fetchErrorMsg =
              "Could not load subscription details."; // User-friendly message
          return null;
        }),
        _fetchCredit(headers).catchError((e) {
          print("Credit fetch failed in Future.wait: $e");
          fetchErrorMsg = (fetchErrorMsg == null ? "" : "$fetchErrorMsg\n") +
              "Could not load credit balance."; // User-friendly message
          return null;
        }),
      ]);

      if (!mounted) return; // Check mount status *after* await

      // Process results
      _activeSubscriptionData = results[0] as ActiveSubscription?;
      _userCredit = results[1] as UserCreditData?;

      // Determine current plan AFTER fetching data
      _currentPlan = _mapPlanNameToEnum(_activeSubscriptionData?.plan);

      // Start timer only if there's an active, valid subscription
      if (_activeSubscriptionData != null &&
          _currentPlan != SubscriptionPlan.none) {
        _updateTimeRemaining(); // Initial calculation
        if (_timeRemaining != "Expired") {
          // Only start timer if not already expired
          _timer = Timer.periodic(Duration(seconds: 1), (_) {
            if (mounted) {
              _updateTimeRemaining();
            } else {
              _timer?.cancel(); // Clean up timer if widget is disposed
            }
          });
        }
      } else {
        _timeRemaining = ""; // No active sub or timer needed
      }

      // Set error message if any fetch failed
      if (fetchErrorMsg != null) {
        _errorMessage = fetchErrorMsg;
      } else if (_userCredit == null) {
        // Check specifically for credit failure if sub succeeded
        _errorMessage = "Could not load credit balance.";
      }
    } catch (e) {
      // Catch any unexpected errors during the Future.wait or processing
      if (mounted) {
        print("Error in _fetchInitialData outer catch: $e");
        setState(() {
          _errorMessage = fetchErrorMsg ??
              "An unexpected error occurred while loading data.";
        });
      }
    } finally {
      // Ensure loading indicator is turned off
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<ActiveSubscription?> _fetchSubscription(
      Map<String, String> headers) async {
    final url = Uri.parse("${AppConfig.baseUrl}/subscription/active/");
    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: 15)); // Add timeout
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          print("No active subscription found (200 but null/empty body).");
          return null; // Explicitly no subscription
        }
        try {
          final data = jsonDecode(body);
          if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
            return ActiveSubscription.fromJson(data);
          } else {
            print(
                "No active subscription found (200 but decoded data is null/empty).");
            return null;
          }
        } catch (e) {
          print("Error decoding subscription JSON: $e. Body was: '$body'");
          throw Exception(
              "Failed to parse subscription data."); // Simplified error
        }
      } else if (response.statusCode == 404) {
        print("No active subscription found (404).");
        return null; // Expected case for no subscription
      } else {
        // Handle other errors (500, 401, etc.)
        String errorDetail = "(${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          errorDetail +=
              " ${errorBody['detail'] ?? errorBody['message'] ?? errorBody['error'] ?? response.body}";
        } catch (_) {
          errorDetail += " ${response.body}";
        }
        print("Failed to load subscription: $errorDetail");
        throw Exception(
            "Server error fetching subscription."); // Simplified error
      }
    } on TimeoutException {
      print("Subscription fetch timed out.");
      throw Exception("Request timed out. Please try again.");
    } catch (e) {
      // Catch network errors or errors thrown above
      print("Error in _fetchSubscription catch block: $e");
      // Rethrow a user-friendly message or the simplified exception
      throw Exception(
          "Could not connect to fetch subscription: ${e is Exception?}");
    }
  }

  Future<UserCreditData?> _fetchCredit(Map<String, String> headers) async {
    final url = Uri.parse(
        "${AppConfig.baseUrl}payment/user/credit/"); // Ensure correct URL
    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: 15)); // Add timeout
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          print("Warning: Credit endpoint returned 200 but null/empty body.");
          // Decide if this is an error or valid (e.g., new user with 0 credits)
          // Returning null might be appropriate if credit data is expected
          throw Exception("Credit data missing from server response.");
        }
        try {
          return UserCreditData.fromJson(jsonDecode(body));
        } catch (e) {
          print("Error decoding credit JSON: $e. Body was: '$body'");
          throw Exception("Failed to parse credit data."); // Simplified error
        }
      } else {
        // Handle errors (404 might mean user not found, 401 auth error, 500 server issue)
        String errorDetail = "(${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          errorDetail +=
              " ${errorBody['detail'] ?? errorBody['message'] ?? errorBody['error'] ?? response.body}";
        } catch (_) {
          errorDetail += " ${response.body}";
        }
        print("Failed to load credits: $errorDetail");
        throw Exception("Server error fetching credits."); // Simplified error
      }
    } on TimeoutException {
      print("Credit fetch timed out.");
      throw Exception("Request timed out. Please try again.");
    } catch (e) {
      print("Error in _fetchCredit catch block: $e");
      throw Exception("Could not connect to fetch credits: ${e is Exception?}");
    }
  }
  // --- End Data Fetching Logic ---

  // --- Plan Mapping & Time Remaining (Unchanged) ---
  SubscriptionPlan _mapPlanNameToEnum(String? planName) {
    if (planName == null || planName.isEmpty || planName == 'unknown') {
      return SubscriptionPlan.none;
    }
    // Already converting to lowercase in fromJson, but double-check here
    switch (planName.toLowerCase()) {
      case 'trial':
        return SubscriptionPlan.trial;
      case 'premium':
        return SubscriptionPlan.premium;
      case 'vip':
        return SubscriptionPlan.vip;
      default:
        print("Warning: Unknown plan name received: $planName");
        return SubscriptionPlan.none;
    }
  }

  void _updateTimeRemaining() {
    if (_activeSubscriptionData == null || !mounted) {
      if (mounted) setState(() => _timeRemaining = "");
      _timer?.cancel();
      return;
    }
    final now = DateTime.now();
    final endDate = _activeSubscriptionData!.endDate;
    final difference = endDate.difference(now);

    if (difference.isNegative || difference.inSeconds <= 0) {
      if (mounted) setState(() => _timeRemaining = "Expired");
      _timer?.cancel(); // Stop timer if expired
    } else {
      String days = difference.inDays.toString();
      String hours = (difference.inHours % 24).toString().padLeft(2, '0');
      String minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      String seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
      String remainingStr = "";

      if (difference.inDays > 0) {
        remainingStr =
            "${days}d ${hours}h ${minutes}m"; // Less detail for longer times
      } else if (difference.inHours > 0) {
        remainingStr = "${hours}h ${minutes}m ${seconds}s";
      } else if (difference.inMinutes > 0) {
        remainingStr = "${minutes}m ${seconds}s";
      } else {
        remainingStr = "${seconds}s";
      }
      if (mounted) setState(() => _timeRemaining = "$remainingStr left");
    }
  }
  // --- End Plan Mapping & Time Remaining ---

  // --- Styled Confirmation Dialog (Unchanged) ---
  Future<bool?> _showStyledConfirmationDialog(
      SubscriptionPlan plan, String planTitle) async {
    final IconData planIcon = _getPlanIcon(plan);
    final Color planColor = _getPlanColor(plan);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
          elevation: 5,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
                color: cardBackgroundColor,
                borderRadius: BorderRadius.circular(18.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [planColor.withOpacity(0.85), planColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(planIcon, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Confirm Upgrade',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cardHighlightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Proceed to upgrade your plan to $planTitle?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: textColor, height: 1.4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, bottom: 20, top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 25, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0)),
                            side: BorderSide(color: Colors.grey.shade400),
                            foregroundColor: secondaryTextColor,
                          ),
                          child: Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: planColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 30, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0)),
                            elevation: 3,
                          ),
                          child: Text('Confirm'),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // --- End Styled Confirmation Dialog ---

  // --- *** NEW: Styled Insufficient Funds Dialog *** ---
  Future<bool?> _showInsufficientFundsDialog(
      int requiredCoins, double currentBalance, String planTitle) async {
    final double needed = requiredCoins - currentBalance;
    // Format needed amount nicely (avoid unnecessary decimals)
    final String neededFormatted =
        needed.toStringAsFixed(needed.truncateToDouble() == needed ? 0 : 2);
    final String currentBalanceFormatted = currentBalance.toStringAsFixed(
        currentBalance.truncateToDouble() == currentBalance
            ? 0
            : 2); // Also format current balance

    return showDialog<bool>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          elevation: 5,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(18.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // --- Dialog Header (Warning Theme) ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          warningColor.withOpacity(0.8),
                          warningColor
                        ], // Use warning color
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Insufficient Funds',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cardHighlightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Dialog Content ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        24.0, 20.0, 24.0, 16.0), // Adjust padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'More Credits Needed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: headingColor,
                          ),
                        ),
                        SizedBox(height: 12),
                        RichText(
                          // Use RichText for better formatting
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14.5, color: textColor, height: 1.4),
                            children: <TextSpan>[
                              TextSpan(text: 'You need '),
                              TextSpan(
                                  text: '$neededFormatted more coins',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: warningColor)),
                              TextSpan(
                                  text: ' to upgrade to the $planTitle plan.'),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Your current balance: $currentBalanceFormatted coins',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  // --- Dialog Actions ---
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, bottom: 20, top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // Cancel Button
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 25, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0)),
                            side: BorderSide(color: Colors.grey.shade400),
                            foregroundColor: secondaryTextColor,
                          ),
                          child: Text('Cancel'),
                          onPressed: () =>
                              Navigator.of(context).pop(false), // Return false
                        ),
                        // Add Funds Button
                        ElevatedButton.icon(
                          icon: Icon(Icons.add_card_rounded, size: 18),
                          label: Text('Add Funds'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                premiumColor, // Use a distinct action color
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 25, vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25.0)),
                            elevation: 3,
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(true), // Return true
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // --- *** END Insufficient Funds Dialog *** ---

  // --- *** UPDATED: Handle selecting a plan (with fund check) *** ---
  Future<void> _selectPlan(SubscriptionPlan selectedPlan, String planTitle,
      int requiredCoins) async {
    // Initial checks (prevent upgrading to same/lower, or selecting trial)
    if (selectedPlan == SubscriptionPlan.trial ||
        selectedPlan == _currentPlan) {
      // Or show a message if they click on current plan again?
      print("Plan selection ignored: Trial or already current plan.");
      return;
    }
    // Prevent upgrading if already Premium/VIP (unless you allow VIP upgrade from Premium)
    if (_currentPlan == SubscriptionPlan.premium ||
        _currentPlan == SubscriptionPlan.vip) {
      // Allow VIP upgrade from Premium if needed
      if (!(selectedPlan == SubscriptionPlan.vip &&
          _currentPlan == SubscriptionPlan.premium)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("You already have a high-tier plan."),
            backgroundColor: Colors.orange));
        return;
      }
    }
    // Prevent selecting lower plans (e.g., Premium if already VIP) - Covered above mostly

    // Show Confirmation Dialog first
    final bool? confirmed =
        await _showStyledConfirmationDialog(selectedPlan, planTitle);

    // Proceed only if confirmed
    if (confirmed == true) {
      if (!mounted) return; // Check mount status after await

      // --- Credit Check ---
      double currentBalance = 0.0;
      if (_userCredit?.creditBalance != null) {
        currentBalance = double.tryParse(_userCredit!.creditBalance) ?? 0.0;
      }

      if (currentBalance < requiredCoins) {
        // --- Insufficient Funds ---
        final bool? wantsToAddFunds = await _showInsufficientFundsDialog(
            requiredCoins, currentBalance, planTitle);

        if (wantsToAddFunds == true && mounted) {
          // Navigate to Recharge Page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RechargePage()),
          ).then((_) {
            // Optional: Refresh data after returning from RechargePage?
            // Useful if recharge might update the balance immediately.
            print("Returned from RechargePage, refreshing data...");
            _fetchInitialData(); // Refresh to see if balance updated
          });
        }
        // Stop the process here whether they navigated or cancelled
        return;
      }
      // --- End Credit Check ---

      // --- Sufficient Funds: Proceed with Upgrade ---
      setState(() {
        _isUpgrading = true; // Show loader *only* when starting the API call
        _errorMessage = null; // Clear previous errors
      });

      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        if (mounted) {
          setState(() {
            _isUpgrading = false;
          }); // Hide loader
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Authentication error. Please log in again."),
              backgroundColor: errorColor));
        }
        return;
      }

      String? upgradeError;
      bool success = false;
      try {
        // Perform the actual API call
        success = await _performUpgrade(selectedPlan,
            token); // No need for catchError here, handled by try/catch

        if (!mounted) return; // Check mount after await

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Successfully upgraded to $planTitle!"),
              backgroundColor: Colors.green));
          await _fetchInitialData(); // Refresh data to show new plan & potentially updated balance
        } else {
          // _performUpgrade should throw an Exception on failure, caught below
          // This else might not be strictly necessary if exceptions are always thrown
          final message = upgradeError ?? "Upgrade failed. Please try again.";
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: errorColor));
        }
      } catch (e) {
        // Catch errors from _performUpgrade or network issues
        if (mounted) {
          final message = e is Exception?;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Upgrade failed: $message"),
              backgroundColor: errorColor));
          print("Error during plan selection upgrade flow: $e");
        }
        success = false; // Ensure success is false on error
      } finally {
        // Ensure loader is always removed
        if (mounted) {
          setState(() {
            _isUpgrading = false;
          });
        }
      }
    } // End if (confirmed == true)
  }
  // --- *** END Updated Plan Selection Logic *** ---

  // --- Perform Upgrade API Call (Minor Refinement) ---
  Future<bool> _performUpgrade(
      SubscriptionPlan targetPlan, String token) async {
    String endpointPath;
    switch (targetPlan) {
      case SubscriptionPlan.premium:
        endpointPath = "subscription/upgrade-to-premium/";
        break;
      case SubscriptionPlan.vip:
        endpointPath = "subscription/upgrade-to-vip/";
        break;
      default:
        // Should not happen due to checks in _selectPlan
        throw Exception("Invalid target plan for upgrade: $targetPlan");
    }

    final url = Uri.parse(AppConfig.baseUrl + endpointPath);
    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type":
          "application/json" // Ensure Content-Type if needed by backend
    };

    try {
      // Using POST as it modifies server state (creates/updates subscription)
      final response = await http.post(url, headers: headers).timeout(Duration(
          seconds: 20)); // Longer timeout for potentially slow operations

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Accept 201 Created as well
        print("Upgrade successful: ${response.body}");
        return true;
      } else {
        // Parse error message more robustly
        String errorMessage = "(${response.statusCode})";
        String responseBody = response.body;
        try {
          final errorBody = jsonDecode(responseBody);
          // Look for common error keys
          errorMessage +=
              ": ${errorBody['detail'] ?? errorBody['message'] ?? errorBody['error'] ?? jsonEncode(errorBody)}"; // Include more details if possible
        } catch (_) {
          // If response is not JSON or parsing fails
          errorMessage +=
              ". Response: ${responseBody.length > 150 ? responseBody.substring(0, 150) + '...' : responseBody}"; // Truncate long non-JSON errors
        }
        print("Upgrade API Error: $errorMessage");
        // Throw an exception with the parsed message
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      print("Upgrade request timed out.");
      throw Exception(
          "The upgrade request timed out. Please check your subscription status later or try again.");
    } catch (e) {
      // Catch network errors or the exception thrown above
      print("Network/Error during upgrade POST: $e");
      // Re-throw the exception or a user-friendly one
      throw Exception("Upgrade request failed: ${e is Exception?}");
    }
  }
  // --- End Perform Upgrade ---

  // --- Build Method (Main Structure) ---
  @override
  Widget build(BuildContext context) {
    // Use Stack for the loader overlay to appear on top of everything
    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text("Subscription Plans",
                style: TextStyle(
                    color: headingColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            backgroundColor: cardBackgroundColor,
            elevation: 1,
            centerTitle: true,
            automaticallyImplyLeading: false, // Keep no back button?
            actions: [
              // Credit display in AppBar
              Padding(
                padding: const EdgeInsets.only(right: 16.0), // More padding
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Prevent excessive width
                    children: [
                      Icon(Icons.monetization_on_outlined,
                          color: premiumColor, size: 20),
                      SizedBox(width: 5),
                      // Show loading indicator for credits specifically if needed
                      _isLoading // If general loading, show placeholder
                          ? Text("...",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: headingColor))
                          : Text(
                              _userCredit?.creditBalance ??
                                  "---", // Handle null credit object
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: headingColor),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Body Content based on state
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color:
                          activePlanHighlightColor)) // Show loader during initial fetch
              : _errorMessage != null
                  ? _buildErrorContent(_errorMessage!) // Show error view
                  : _buildLoadedContent(), // Show main content
        ),

        // --- Upgrade Loader Overlay ---
        // This appears *only* when _isUpgrading is true (during API call)
        if (_isUpgrading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6), // Semi-transparent overlay
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3.0,
                    ),
                    SizedBox(height: 16),
                    // Ensure text is visible and doesn't inherit Scaffold styles
                    Material(
                      // Wrap text in Material for default text styling
                      color: Colors.transparent,
                      child: Text(
                        "Processing upgrade...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
  // --- End Build Method ---

  // --- Helper: Build Error Content ---
  Widget _buildErrorContent(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 50),
            SizedBox(height: 18),
            Text(
              "Something Went Wrong",
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: headingColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(errorMsg, // Display the specific error message
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 14, height: 1.4)),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh_rounded),
              label: Text("Retry"),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      activePlanHighlightColor, // Use a theme color
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12)),
              // Disable button while loading or upgrading
              onPressed: _isLoading || _isUpgrading ? null : _fetchInitialData,
            )
          ],
        ),
      ),
    );
  }
  // --- End Helper: Build Error Content ---

  // --- Helper: Build Loaded Content ---
  Widget _buildLoadedContent() {
    return RefreshIndicator(
      // Add pull-to-refresh
      onRefresh: _fetchInitialData,
      color: activePlanHighlightColor,
      child: SingleChildScrollView(
        physics:
            AlwaysScrollableScrollPhysics(), // Ensure scroll works even if content fits screen
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 24.0, horizontal: 16.0), // Adjust horizontal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Text Section
              Padding(
                padding: const EdgeInsets.only(
                    bottom: 28.0,
                    left: 4,
                    right: 4), // Add horizontal padding to text block
                child: Column(
                  children: [
                    Text(
                      "Choose Your Plan", // Simplified title
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, // Slightly larger
                        fontWeight: FontWeight.bold,
                        color: headingColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Unlock more features and enhance your experience by upgrading.", // Concise description
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14.5,
                          color: secondaryTextColor,
                          height: 1.4),
                    ),
                  ],
                ),
              ),

              // --- Subscription Cards ---
              // Pass the correct monthly price to each upgradable plan card
              _buildSubscriptionCard(
                plan: SubscriptionPlan.trial,
                title: "Trial",
                icon: _getPlanIcon(SubscriptionPlan.trial), // Use helper
                baseColor: _getPlanColor(SubscriptionPlan.trial), // Use helper
                monthlyPriceCoins: 0, // Not applicable
                monthlyPriceDT: 0, // Not applicable
                yearlyPriceCoins: 0, // Not applicable
                yearlyPriceDT: 0, // Not applicable
                features: [
                  _currentPlan == SubscriptionPlan.trial
                      ? "Active 3-day free access"
                      : "Limited 3-day trial",
                  "Explore basic features",
                  "Community Support",
                ],
              ),
              SizedBox(height: 20),
              _buildSubscriptionCard(
                plan: SubscriptionPlan.premium,
                title: "Premium",
                icon: _getPlanIcon(SubscriptionPlan.premium),
                baseColor: _getPlanColor(SubscriptionPlan.premium),
                monthlyPriceCoins: 100, // ** THE PRICE FOR PREMIUM **
                monthlyPriceDT: 10,
                yearlyPriceCoins: 900,
                yearlyPriceDT: 90,
                features: [
                  "Full Feature Access",
                  "Priority Support Queue",
                  "Ad-Free Experience",
                  "Advanced Analytics",
                ],
              ),
              SizedBox(height: 20),
              _buildSubscriptionCard(
                plan: SubscriptionPlan.vip,
                title: "VIP",
                icon: _getPlanIcon(SubscriptionPlan.vip),
                baseColor: _getPlanColor(SubscriptionPlan.vip),
                monthlyPriceCoins: 150, // ** THE PRICE FOR VIP **
                monthlyPriceDT: 15,
                yearlyPriceCoins: 1100,
                yearlyPriceDT: 110,
                features: [
                  "All Premium Benefits",
                  "Exclusive Content Access",
                  "Dedicated Support Manager",
                  "Early Access to Betas",
                ],
              ),
              SizedBox(height: 20), // Add some padding at the bottom
            ],
          ),
        ),
      ),
    );
  }
  // --- End Helper: Build Loaded Content ---

  // --- *** UPDATED Helper Widget to build subscription cards *** ---
  Widget _buildSubscriptionCard({
    required SubscriptionPlan plan,
    required String title,
    required IconData icon,
    required Color baseColor,
    required int monthlyPriceCoins, // Used for display and fund check
    required int monthlyPriceDT, // Used for display
    required int yearlyPriceCoins, // Used for display (if _showYearly is true)
    required int yearlyPriceDT, // Used for display (if _showYearly is true)
    required List<String> features,
  }) {
    bool isActive = _currentPlan == plan && plan != SubscriptionPlan.none;

    // Determine if this card's plan can be chosen based on the *current* plan
    bool canChooseThisPlan = false;
    if (plan == SubscriptionPlan.premium) {
      // Can upgrade to Premium from None or Trial
      canChooseThisPlan = (_currentPlan == SubscriptionPlan.none ||
          _currentPlan == SubscriptionPlan.trial);
    } else if (plan == SubscriptionPlan.vip) {
      // Can upgrade to VIP from None, Trial, or Premium
      canChooseThisPlan = (_currentPlan == SubscriptionPlan.none ||
          _currentPlan == SubscriptionPlan.trial ||
          _currentPlan == SubscriptionPlan.premium);
    }

    // Show the "Choose Plan" button only for Premium and VIP plans
    bool showChooseButton =
        (plan == SubscriptionPlan.premium || plan == SubscriptionPlan.vip);

    // Disable the button if: upgrading is in progress OR it's the active plan OR it's not a choosable plan
    bool disableButton =
        _isUpgrading || isActive || (showChooseButton && !canChooseThisPlan);

    // Determine price and period text based on _showYearly toggle (if implemented)
    // For now, defaulting to monthly
    int displayPriceCoins = monthlyPriceCoins;
    // ignore: unused_local_variable
    int displayPriceDT = monthlyPriceDT;
    String displayPeriod = "/ Month";
    // String displayPriceText = "$displayPriceCoins Coins / $displayPriceDT DT"; // Or use locale formatting
    String displayPriceText =
        "$displayPriceCoins Credits"; // Simplified display

    if (plan == SubscriptionPlan.trial) {
      displayPriceText = "Free";
      displayPeriod = "for 3 days";
    } else if (_showYearly) {
      // Add logic for yearly if needed
      displayPriceCoins = yearlyPriceCoins;
      displayPriceDT = yearlyPriceDT;
      // displayPriceText = "$displayPriceCoins Coins / $displayPriceDT DT";
      displayPriceText = "$displayPriceCoins Credits";
      displayPeriod = "/ Year";
    }

    // Styling for active plan border and shadow
    Color currentBorderColor =
        isActive ? activePlanBorderColor : Colors.grey.shade200;
    double currentBorderWidth = isActive ? 2.5 : 1.0;
    List<BoxShadow>? currentShadow = isActive
        ? [
            BoxShadow(
                color: activePlanHighlightColor.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 0,
                offset: Offset(0, 5))
          ]
        : [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 0,
                offset: Offset(0, 4))
          ];

    return Container(
      margin: EdgeInsets.only(bottom: 4), // Add tiny margin between cards
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: currentBorderColor, width: currentBorderWidth),
        boxShadow: currentShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17), // Clip slightly inside border
        child: Column(
          children: [
            // --- Card Header ---
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [baseColor.withOpacity(0.85), baseColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon background
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: cardBackgroundColor.withOpacity(0.9),
                        shape: BoxShape.circle),
                    child: Icon(icon, size: 26, color: baseColor),
                  ),
                  SizedBox(width: 12),
                  // Plan Title and Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cardHighlightTextColor)),
                        SizedBox(height: 4), // Spacing
                        if (plan !=
                            SubscriptionPlan
                                .trial) // Only show price for paid plans
                          Text(
                            displayPriceText +
                                (plan != SubscriptionPlan.trial
                                    ? displayPeriod
                                    : ""),
                            style: TextStyle(
                              color: cardHighlightTextColor.withOpacity(0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else // Show trial duration clearly
                          Text(
                            displayPeriod,
                            style: TextStyle(
                              color: cardHighlightTextColor.withOpacity(0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Time Remaining / Expired Badge (only if active)
                  if (isActive && _timeRemaining.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _timeRemaining == "Expired"
                            ? errorColor.withOpacity(0.8)
                            : Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _timeRemaining,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: _timeRemaining == "Expired"
                                ? FontWeight.bold
                                : FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            // --- Features List and Action Button ---
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 18, 20, 20), // Adjust padding
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Stretch feature rows
                children: [
                  // Features
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: features
                        .map((feature) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 10.0), // Feature spacing
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    // Add padding to align icon better
                                    padding: const EdgeInsets.only(top: 1.5),
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 17,
                                      color: isActive
                                          ? activePlanHighlightColor
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                  SizedBox(
                                      width: 10), // Space between icon and text
                                  Expanded(
                                      child: Text(feature,
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              color: textColor,
                                              height: 1.3 // Line height
                                              ))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 24), // Space before button/chip

                  // Action Button / Current Plan Chip
                  Center(
                    child: isActive
                        ? Chip(
                            // Display chip for the active plan
                            avatar: Icon(Icons.check_circle,
                                color: activePlanHighlightColor, size: 18),
                            label: Text("Your Current Plan"),
                            backgroundColor:
                                activePlanHighlightColor.withOpacity(0.1),
                            labelStyle: TextStyle(
                                color: activePlanHighlightColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            side: BorderSide(
                                color:
                                    activePlanHighlightColor.withOpacity(0.3)),
                          )
                        : showChooseButton // Only show button for Premium/VIP
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: baseColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25)),
                                  elevation: disableButton
                                      ? 0
                                      : 3, // Reduce elevation when disabled
                                  // Grey out button visually when disabled
                                  disabledBackgroundColor:
                                      baseColor.withOpacity(0.5),
                                  disabledForegroundColor:
                                      Colors.white.withOpacity(0.8),
                                ),
                                // --- *** UPDATED onPressed passes price *** ---
                                onPressed: disableButton
                                    ? null // Disable if needed
                                    : () => _selectPlan(plan, title,
                                        displayPriceCoins), // Pass the price (monthly or yearly)
                                child: Text(
                                  canChooseThisPlan
                                      ? "Choose Plan"
                                      : "Upgrade Not Available", // Give feedback if disabled
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : SizedBox
                                .shrink(), // No button for Trial card (unless you add 'Start Trial')
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // --- *** END Updated Card Builder *** ---
} // End of _SubscriptionPageState
