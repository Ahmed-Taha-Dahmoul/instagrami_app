import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';


// Lottie package import
import 'package:lottie/lottie.dart';

// Assuming config.dart and recharge_page.dart exist
import 'config.dart'; // Replace with your actual config import
import 'recharge_page.dart'; // Replace with your actual recharge page import

// --- Data Models --- (Keep existing)
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
      parsedEndDate = DateTime.now().add(Duration(days: -1));
    }
    DateTime? parsedStartDate = DateTime.tryParse(json['start_date'] ?? '');
    if (parsedStartDate == null) {
      print("Warning: Could not parse start_date: ${json['start_date']}");
      parsedStartDate = DateTime.now();
    }
    return ActiveSubscription(
      plan: json['plan']?.toString().toLowerCase() ?? 'unknown',
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
    String balance = '0';
    if (json['credit_balance'] != null) {
      try {
        double parsedBalance = double.parse(json['credit_balance'].toString());
        balance = parsedBalance.toInt().toString();
      } catch (e) {
        print(
            "Warning: Could not parse credit_balance: ${json['credit_balance']}. Using '0'.");
        balance = '0';
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
  // final Random _random = Random(); // Not needed

  SubscriptionPlan _currentPlan = SubscriptionPlan.none;
  ActiveSubscription? _activeSubscriptionData;
  UserCreditData? _userCredit;
  bool _isLoading = true;
  bool _isUpgrading = false;
  String? _errorMessage;

  // --- State for Celebration Overlay ---
  bool _showCelebration = false; // Controls visibility of the animation overlay
  String? _celebrationPlanTitle; // To pass to the success dialog
  bool _isShowingInitialCongrats = true; // Controls which animation phase / dialog visibility
  Timer? _congratsTimer; // Timer for switching phase
  // --- End Celebration State ---

  // --- UI Color Definitions --- (Keep existing)
  final Color scaffoldBgColor = Colors.grey.shade50;
  final Color cardBgColor = Colors.white;
  final Color primaryTextColor = Colors.black87;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color accentColorBlue = Color(0xFF3F51B5);
  final Color accentColorPurple = Color(0xFF673AB7);
  final Color labelBlueBg = Color(0xFFE3F2FD);
  final Color labelBlueText = Color(0xFF1E88E5);
  final Color labelPurpleBg = Color(0xFFEDE7F6);
  final Color labelPurpleText = Color(0xFF5E35B1);
  final Color errorColor = Colors.red.shade700;
  final Color warningColor = Colors.orange.shade700;
  final Color successColor = Colors.green.shade600;
  // --- End UI colors ---

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _congratsTimer?.cancel(); // Cancel timer if page is disposed
    super.dispose();
  }

  // --- Data Fetching Logic --- (Keep existing)
  Future<void> _fetchInitialData() async {
    // ... (Implementation remains the same) ...
    if (!mounted) return;
    // Don't show main loader if only refreshing after celebration is dismissed
    if (!_showCelebration) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
    ActiveSubscription? fetchedSubscription;
    UserCreditData? fetchedCredit;

    try {
      final results = await Future.wait([
        _fetchSubscription(headers).catchError((e) {
          print("Subscription fetch failed: $e");
          fetchErrorMsg = "Could not load subscription details.";
          return null;
        }),
        _fetchCredit(headers).catchError((e) {
          print("Credit fetch failed: $e");
          fetchErrorMsg = (fetchErrorMsg == null ? "" : "$fetchErrorMsg\n") +
              "Could not load credit balance.";
          return null;
        }),
      ]);

      if (!mounted) return;

      fetchedSubscription = results[0] as ActiveSubscription?;
      fetchedCredit = results[1] as UserCreditData?;

      setState(() {
        _activeSubscriptionData = fetchedSubscription;
        _userCredit = fetchedCredit;
        _currentPlan = _mapPlanNameToEnum(_activeSubscriptionData?.plan);
        _errorMessage = fetchErrorMsg;
        if (_errorMessage == null &&
            _userCredit == null &&
            _activeSubscriptionData != null) {
          _errorMessage = "Could not load credit balance.";
        }
        _isLoading = false; // Stop loading indicator
      });
    } catch (e) {
      if (mounted) {
        print("Error in _fetchInitialData: $e");
        setState(() {
          _errorMessage =
              fetchErrorMsg ?? "An unexpected error occurred while loading data.";
          _isLoading = false; // Stop loading indicator
        });
      }
    }
  }

  Future<ActiveSubscription?> _fetchSubscription(
      Map<String, String> headers) async {
    // ... (Implementation remains the same) ...
    final url = Uri.parse("${AppConfig.baseUrl}/subscription/active/");
    try {
      final response =
          await http.get(url, headers: headers).timeout(Duration(seconds: 15));
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          return null;
        }
        try {
          final data = jsonDecode(body);
          if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
            return ActiveSubscription.fromJson(data);
          } else {
            return null;
          }
        } catch (e) {
          print("Error decoding subscription JSON: $e. Body was: '$body'");
          throw Exception("Failed to parse subscription data.");
        }
      } else if (response.statusCode == 404) {
        return null;
      } else {
        print( "Failed to load subscription: (${response.statusCode}) ${response.body}");
        throw Exception( "Server error fetching subscription (${response.statusCode}).");
      }
    } on TimeoutException {
      print("Subscription fetch timed out.");
      throw Exception("Request timed out. Please try again.");
    } catch (e) {
      print("Error in _fetchSubscription catch block: $e");
      throw Exception("Could not connect to fetch subscription.");
    }
  }

  Future<UserCreditData?> _fetchCredit(Map<String, String> headers) async {
    // ... (Implementation remains the same) ...
    final url = Uri.parse("${AppConfig.baseUrl}payment/user/credit/");
    try {
      final response =
          await http.get(url, headers: headers).timeout(Duration(seconds: 15));
      if (!mounted) return null;

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          throw Exception("Credit data missing from server response.");
        }
        try {
          return UserCreditData.fromJson(jsonDecode(body));
        } catch (e) {
          print("Error decoding credit JSON: $e. Body was: '$body'");
          throw Exception("Failed to parse credit data.");
        }
      } else {
        print("Failed to load credits: (${response.statusCode}) ${response.body}");
        throw Exception("Server error fetching credits (${response.statusCode}).");
      }
    } on TimeoutException {
      print("Credit fetch timed out.");
      throw Exception("Request timed out. Please try again.");
    } catch (e) {
      print("Error in _fetchCredit catch block: $e");
      throw Exception("Could not connect to fetch credits.");
    }
  }
  // --- End Data Fetching Logic ---

  // --- Plan Mapping --- (Keep existing)
  SubscriptionPlan _mapPlanNameToEnum(String? planName) {
     // ... (Implementation remains the same) ...
    if (planName == null || planName.isEmpty || planName == 'unknown') {
      return SubscriptionPlan.none;
    }
    switch (planName.toLowerCase()) {
      case 'trial':
        return SubscriptionPlan.trial;
      case 'premium':
        return SubscriptionPlan.premium;
      case 'vip':
        return SubscriptionPlan.vip;
      default:
        print("Warning: Unknown plan name received from API: $planName");
        return SubscriptionPlan.none;
    }
  }
  // --- End Plan Mapping ---

  // --- Dialogs --- (Keep existing confirmation/insufficient funds dialogs)
  Future<bool?> _showStyledConfirmationDialog(
      SubscriptionPlan plan, String planTitle) async {
    // ... (Implementation remains the same) ...
     return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Upgrade'),
          content: Text('Proceed to upgrade your plan to $planTitle?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _getPlanButtonColor(plan),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showInsufficientFundsDialog(
      int requiredCoins, String currentBalanceStr, String planTitle) async {
    // ... (Implementation remains the same) ...
      double currentBalance = double.tryParse(currentBalanceStr) ?? 0.0;
      final double needed = requiredCoins - currentBalance;
      final String neededFormatted = needed.toInt().toString();
      final String currentBalanceFormatted = currentBalance.toInt().toString();

       return showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: warningColor),
                SizedBox(width: 8),
                Text('Insufficient Funds'),
              ],
            ),
            content: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: primaryTextColor, height: 1.4),
                children: <TextSpan>[
                  TextSpan(text: 'You need '),
                  TextSpan(
                    text: '$neededFormatted more coins',
                    style: TextStyle(fontWeight: FontWeight.bold, color: warningColor)
                  ),
                  TextSpan(text: ' to upgrade to the $planTitle plan.\n\n'),
                  TextSpan(
                    text: 'Your current balance: $currentBalanceFormatted coins',
                    style: TextStyle(color: secondaryTextColor, fontSize: 13.5)
                  ),
                ],
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            actions: <Widget>[
               TextButton(
                child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add_card_rounded, size: 18),
                label: Text('Add Funds'),
                style: ElevatedButton.styleFrom(
                   backgroundColor: warningColor,
                   foregroundColor: Colors.white,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );
   }

  // --- NEW: Success Pop-up Dialog ---
  Future<void> _showSuccessDialog(String planTitle) async {
    // Check if still mounted before showing dialog
    if (!mounted) return;

    // Make sure the timer is cancelled when the dialog is shown or dismissed
    _congratsTimer?.cancel();

    await showDialog(
      context: context,
      barrierDismissible: false, // User must press the button
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: successColor, size: 28),
              SizedBox(width: 10),
              Text('Upgrade Successful!'),
            ],
          ),
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
          content: Text(
            'You are now on the $planTitle plan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: secondaryTextColor),
          ),
          contentPadding: EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0), // Adjust padding
          actionsAlignment: MainAxisAlignment.center, // Center the button
          actionsPadding: EdgeInsets.only(bottom: 20.0, top: 10.0),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              child: Text('Awesome!'),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog FIRST

                // Reset state and refresh data *after* dialog is closed
                if (mounted) {
                   // Need setState to ensure the animation overlay is removed
                   setState(() {
                       _showCelebration = false; // Hide the animation overlay
                       _isShowingInitialCongrats = true; // Reset phase for next time
                       _celebrationPlanTitle = null;
                   });
                   await _fetchInitialData(); // Refresh page data
                }
              },
            ),
          ],
        );
      },
    );
     // Execution continues here ONLY after the dialog is popped
     // Ensure state is reset if dialog is dismissed differently (though barrierDismissible=false prevents it)
     if (mounted && _showCelebration) {
         setState(() {
           _showCelebration = false;
           _isShowingInitialCongrats = true;
           _celebrationPlanTitle = null;
         });
     }
  }
  // --- End Dialogs ---

  // --- Plan Selection and Upgrade Logic --- (MODIFIED)
  Future<void> _selectPlan(
      SubscriptionPlan selectedPlan, String planTitle, int requiredCoins) async {
    // ... (initial checks remain the same) ...
     if (selectedPlan == _currentPlan || selectedPlan == SubscriptionPlan.trial) {
      return;
    }
    if ((_currentPlan == SubscriptionPlan.vip &&
        selectedPlan == SubscriptionPlan.premium)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Cannot downgrade subscription."),
          backgroundColor: warningColor));
      return;
    }

    final bool? confirmed =
        await _showStyledConfirmationDialog(selectedPlan, planTitle);


    if (confirmed == true) {
       // ... (credit check and upgrade process remain the same up to success) ...
       if (!mounted) return;

      String currentBalanceStr = _userCredit?.creditBalance ?? '0';
      double currentBalance = double.tryParse(currentBalanceStr) ?? 0.0;

      if (currentBalance < requiredCoins) {
        final bool? wantsToAddFunds = await _showInsufficientFundsDialog(
            requiredCoins, currentBalanceStr, planTitle);

        if (wantsToAddFunds == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RechargePage()),
          ).then((_) {
            print("Returned from RechargePage, refreshing data...");
            _fetchInitialData();
          });
        }
        return;
      }

      setState(() {
        _isUpgrading = true;
        _errorMessage = null;
      });

      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        if (mounted) {
          setState(() { _isUpgrading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Authentication error. Please log in again."),
              backgroundColor: errorColor));
        }
        return;
      }


      try {
        bool success = await _performUpgrade(selectedPlan, token);

        if (mounted) {
          setState(() { _isUpgrading = false; });
        } else { return; }

        if (success) {
          if (mounted) {
            // Show animation overlay and start timer
            setState(() {
              _celebrationPlanTitle = planTitle;
              _isShowingInitialCongrats = true; // Start with initial phase
              _showCelebration = true;         // Show the animation overlay
            });

            _congratsTimer?.cancel();
            _congratsTimer = Timer(const Duration(seconds: 3), () { // Adjust duration
              if (mounted && _showCelebration) {
                // Timer fired: Hide initial congrats anim & show dialog
                 setState(() {
                    _isShowingInitialCongrats = false; // Stop showing first anim
                 });
                 // Use a tiny delay to allow state change to render before showing dialog
                 Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted && _showCelebration && !_isShowingInitialCongrats) {
                       _showSuccessDialog(_celebrationPlanTitle ?? 'your new plan');
                    }
                 });
              }
            });
          }
        }
      } catch (e) {
         // ... (Error handling remains the same) ...
          if (mounted) {
          setState(() { _isUpgrading = false; });
          final message = (e is Exception) ? e.toString().replaceFirst("Exception: ", "") : "An unknown error occurred during upgrade.";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Upgrade failed: $message"),
              backgroundColor: errorColor));
          print("Error during plan upgrade API call: $e");
        }
      }
    }
  }

  // --- Perform Upgrade Logic --- (Keep existing)
  Future<bool> _performUpgrade(SubscriptionPlan targetPlan, String token) async {
    // ... (Implementation remains the same) ...
     String endpointPath;
    switch (targetPlan) {
      case SubscriptionPlan.premium:
        endpointPath = "subscription/upgrade-to-premium/";
        break;
      case SubscriptionPlan.vip:
        endpointPath = "subscription/upgrade-to-vip/";
        break;
      default:
        throw Exception("Invalid target plan for upgrade: $targetPlan");
    }

    final url = Uri.parse(AppConfig.baseUrl + endpointPath);
    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json"
    };

    try {
      final response = await http
          .post(
            url,
            headers: headers,
          )
          .timeout(Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Upgrade successful: ${response.body}");
        return true;
      } else {
        String errorMessage = "API Error (${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage +=
              ": ${errorBody['detail'] ?? errorBody['message'] ?? errorBody['error'] ?? jsonEncode(errorBody)}";
        } catch (_) {
          errorMessage += ". Response: ${response.body}";
        }
        print("Upgrade API Error: $errorMessage");
        throw Exception(errorMessage);
      }
    } on TimeoutException {
      print("Upgrade request timed out.");
      throw Exception("The upgrade request timed out. Please try again.");
    } catch (e) {
      print("Network/Error during upgrade POST: $e");
      throw Exception(
          "Upgrade request failed: ${e is Exception ? e.toString().replaceFirst('Exception: ', '') : e}");
    }
  }
  // --- End Plan Selection and Upgrade Logic ---

  // --- Build Method (Main UI Structure) --- (Keep existing)
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: scaffoldBgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryTextColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text("Subscription Plans",
                style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            backgroundColor: cardBgColor,
            elevation: 0.5,
            centerTitle: true,
          ),
          body: _isLoading && !_showCelebration
              ? Center(child: CircularProgressIndicator(color: accentColorBlue))
              : _errorMessage != null && !_showCelebration
                  ? _buildErrorContent(_errorMessage!)
                  : _buildLoadedContent(),
        ),

        // --- Upgrade Loader Overlay ---
        if (_isUpgrading)
           // ... (Implementation remains the same) ...
           Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3.0,
                    ),
                    SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: Text(
                        "Processing upgrade...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // --- Full Screen Animation Overlay (No Background, No Content) ---
        // This overlay now *only* shows the animations
        if (_showCelebration)
          IgnorePointer( // Overlay should not be interactive
            ignoring: true,
            child: _buildAnimationOverlay(),
          ),
      ],
    );
  }
  // --- End Build Method ---

  // --- Helper Widget for Full-Screen Animation Overlay --- (MODIFIED)
  // Renamed to reflect its purpose: only showing animations
  Widget _buildAnimationOverlay() {

    // Define the paths directly
    const String congratsAnimPath = 'assets/animations/congratulations_ani.json';
    const String celebAnimPath = 'assets/animations/Animation_celeb_1.json';

    return Positioned.fill(
      child: Container(
        color: Colors.transparent, // No background dimming
        child: Stack(
          children: [
            // --- Layer 1: congratulations_ani.json (Conditional) ---
            // Show only during the initial phase
            if (_isShowingInitialCongrats)
              Positioned.fill(
                child: Lottie.asset(
                  congratsAnimPath,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  repeat: false,
                ),
              ),

            // --- Layer 2: Animation_celeb_1.json (Always shows when overlay is visible) ---
            Positioned.fill(
              child: Lottie.asset(
                celebAnimPath,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                repeat: false, // Play once
              ),
            ),

            // --- NO CONTENT (Text/Button) HERE ANYMORE ---
          ],
        ),
      ),
    );
  }
  // --- End Animation Overlay Helper ---

  // --- Helper Widgets for Building UI --- (Keep existing)

  Widget _buildErrorContent(String errorMsg) {
     // ... (Implementation remains the same) ...
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
                  color: primaryTextColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: secondaryTextColor, fontSize: 14, height: 1.4)),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh_rounded),
              label: Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColorBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: _isLoading || _isUpgrading ? null : _fetchInitialData,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedContent() {
     // ... (Implementation remains the same) ...
    // Prevent rebuild of underlying UI while animations/dialog are showing
    // if (_showCelebration) return Container(); // Commented out: Let UI stay visible under transparent overlay

    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      color: accentColorBlue,
      child: SingleChildScrollView(
        // Disable scroll when celebration is active to prevent weird interactions
        physics: _showCelebration ? NeverScrollableScrollPhysics() : AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCreditsBalanceCard(),
            SizedBox(height: 24),
            _buildSubscriptionCard(
              plan: SubscriptionPlan.trial,
              planTitle: "Trial",
              priceCoins: 0,
              durationDays: 7,
              features: [
                "Basic tracking features",
                "Limited to 100 accounts",
              ],
              isCurrentPlan: _currentPlan == SubscriptionPlan.trial,
              label: _currentPlan == SubscriptionPlan.trial ? "CURRENT PLAN" : null,
              labelType: 'current',
            ),
            SizedBox(height: 16),
            _buildSubscriptionCard(
              plan: SubscriptionPlan.premium,
              planTitle: "Premium",
              priceCoins: 10,
              durationDays: 7,
              features: [
                "Advanced tracking features",
                "Up to 1000 accounts",
                "Priority support",
              ],
              isCurrentPlan: _currentPlan == SubscriptionPlan.premium,
              label: "POPULAR",
              labelType: 'popular',
            ),
            SizedBox(height: 16),
            _buildSubscriptionCard(
              plan: SubscriptionPlan.vip,
              planTitle: "Business",
              priceCoins: 15,
              durationDays: 15,
              features: [
                "All Premium features",
                "Unlimited accounts",
                "API access",
                "24/7 VIP support",
              ],
              isCurrentPlan: _currentPlan == SubscriptionPlan.vip,
              label: "VIP",
              labelType: 'vip',
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditsBalanceCard() {
     // ... (Implementation remains the same) ...
      String balance = _userCredit?.creditBalance ?? '---';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: accentColorPurple,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Credits Balance",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "$balance credits",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            // Disable Buy More if celebration is active
            onPressed: _showCelebration ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RechargePage()),
              ).then((_) => _fetchInitialData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: accentColorPurple,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
               disabledBackgroundColor: Colors.white.withOpacity(0.5), // Style when disabled
            ),
            child: Text("Buy More"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard({
    required SubscriptionPlan plan,
    required String planTitle,
    required int priceCoins,
    required int durationDays,
    required List<String> features,
    required bool isCurrentPlan,
    String? label,
    required String labelType,
  }) {
    // ... (Implementation remains the same, disableButton already includes _showCelebration check) ...
     bool canUpgradeTo = false;
    if (plan == SubscriptionPlan.premium &&
        (_currentPlan == SubscriptionPlan.none ||
            _currentPlan == SubscriptionPlan.trial)) {
      canUpgradeTo = true;
    } else if (plan == SubscriptionPlan.vip &&
        (_currentPlan == SubscriptionPlan.none ||
            _currentPlan == SubscriptionPlan.trial ||
            _currentPlan == SubscriptionPlan.premium)) {
      canUpgradeTo = true;
    }

    bool showUpgradeButton =
        (plan == SubscriptionPlan.premium || plan == SubscriptionPlan.vip) &&
            !isCurrentPlan;
    // Disable button if upgrading OR if celebration overlay is active
    bool disableButton = _isUpgrading || _showCelebration || (showUpgradeButton && !canUpgradeTo);

    Color labelBg;
    Color labelTextCol;
    switch (labelType) {
      case 'popular':
        labelBg = labelBlueBg;
        labelTextCol = labelBlueText;
        break;
      case 'vip':
        labelBg = labelPurpleBg;
        labelTextCol = labelPurpleText;
        break;
      case 'current':
      default:
        labelBg = labelBlueBg;
        labelTextCol = labelBlueText;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan
              ? accentColorBlue.withOpacity(0.5)
              : Colors.grey.shade200,
          width: isCurrentPlan ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Chip(
                            label: Text(label),
                            labelStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: labelTextCol),
                            backgroundColor: labelBg,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide.none,
                          ),
                        ),
                      Text(
                        planTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan == SubscriptionPlan.trial
                          ? "Free"
                          : "$priceCoins coins",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "$durationDays days",
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 18, color: successColor),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: primaryTextColor,
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            if (showUpgradeButton) ...[
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPlanButtonColor(plan),
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    elevation: disableButton ? 0 : 2,
                    disabledBackgroundColor:
                        _getPlanButtonColor(plan).withOpacity(0.5),
                    disabledForegroundColor: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: disableButton
                      ? null
                      : () => _selectPlan(plan, planTitle, priceCoins),
                  child: Text(
                    canUpgradeTo ? "Upgrade to $planTitle" : "Upgrade Not Available",
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (isCurrentPlan && plan != SubscriptionPlan.trial) ...[
              SizedBox(height: 20),
              Center(
                child: Text(
                  "This is your current plan",
                  style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Color _getPlanButtonColor(SubscriptionPlan plan) {
     // ... (Implementation remains the same) ...
     switch (plan) {
      case SubscriptionPlan.premium:
        return accentColorBlue;
      case SubscriptionPlan.vip:
        return accentColorPurple;
      default:
        return Colors.grey;
    }
  }

  // --- End Helper Widgets ---

} // End of _SubscriptionPageState class