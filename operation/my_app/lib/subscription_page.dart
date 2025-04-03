import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async'; // For Timer

import 'config.dart'; // Your AppConfig

// --- Data Models --- (No changes)
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
      parsedEndDate = DateTime.now();
    }
    DateTime? parsedStartDate = DateTime.tryParse(json['start_date'] ?? '');
    if (parsedStartDate == null) {
      print("Warning: Could not parse start_date: ${json['start_date']}");
      parsedStartDate = DateTime.now();
    }
    return ActiveSubscription(
      plan: json['plan'] ?? 'Unknown',
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
    return UserCreditData(
      username: json['user'] ?? 'User',
      creditBalance: json['credit_balance']?.toString() ?? '0.0000',
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
  bool _isUpgrading = false;
  String? _errorMessage;
  String _timeRemaining = "";
  Timer? _timer;

  bool _showYearly = false;

  // --- Colors ---
  final Color backgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.black87;
  final Color textColor = Colors.grey.shade800;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color cardHighlightTextColor = Colors.white;
  final Color trialColor = Color(0xFF4AC4AE);
  final Color premiumColor = Color(0xFFE6C76A);
  final Color vipColor = Color(0xFFFA8282);
  final Color activePlanHighlightColor = Colors.indigoAccent.shade400;
  final Color activePlanBorderColor = Colors.indigoAccent.shade100;
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
      case SubscriptionPlan.trial: return Icons.hourglass_empty_rounded;
      case SubscriptionPlan.premium: return Icons.star_rounded;
      case SubscriptionPlan.vip: return Icons.diamond_rounded;
      case SubscriptionPlan.none: return Icons.help_outline; // Fallback
    }
  }

  Color _getPlanColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.trial: return trialColor;
      case SubscriptionPlan.premium: return premiumColor;
      case SubscriptionPlan.vip: return vipColor;
      case SubscriptionPlan.none: return Colors.grey; // Fallback
    }
  }
  // --- End Helper Functions ---


  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _timeRemaining = "";
      _timer?.cancel();
      _activeSubscriptionData = null;
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

    final headers = { "Authorization": "Bearer $token", "Content-Type": "application/json" };
    String? fetchErrorMsg;

    try {
      final results = await Future.wait([
        _fetchSubscription(headers).catchError((e) {
          fetchErrorMsg = "Subscription fetch failed: $e";
          return null;
        }),
        _fetchCredit(headers).catchError((e) {
          fetchErrorMsg = (fetchErrorMsg == null ? "" : "$fetchErrorMsg\n") + "Credit fetch failed: $e";
          return null;
        }),
      ]);

      if (mounted) {
        _activeSubscriptionData = results[0] as ActiveSubscription?;
        _userCredit = results[1] as UserCreditData?;
        _currentPlan = _mapPlanNameToEnum(_activeSubscriptionData?.plan);

        if (_activeSubscriptionData != null && _currentPlan != SubscriptionPlan.none) {
          _updateTimeRemaining();
          _timer = Timer.periodic(Duration(seconds: 1), (_) {
            if (mounted) { _updateTimeRemaining(); } else { _timer?.cancel(); }
          });
        } else { _timeRemaining = ""; }

        if (fetchErrorMsg != null) { _errorMessage = fetchErrorMsg; }
        else if (_userCredit == null && _activeSubscriptionData != null) {
          _errorMessage = _errorMessage ?? "Could not load credit balance.";
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = fetchErrorMsg ?? "An unexpected error occurred: $e"; });
        print("Error in _fetchInitialData (outer catch): $e");
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<ActiveSubscription?> _fetchSubscription(Map<String, String> headers) async {
    final url = Uri.parse("${AppConfig.baseUrl}/subscription/active/");
    try {
      final response = await http.get(url, headers: headers);
      if (!mounted) return null;
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          print("No active subscription found (200 but null/empty body).");
          return null;
        }
        try {
          final data = jsonDecode(body);
          if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
            return ActiveSubscription.fromJson(data);
          } else {
            print("No active subscription found (200 but decoded data is null/empty).");
            return null;
          }
        } catch (e) {
          print("Error decoding subscription JSON: $e. Body was: '$body'");
          throw Exception("Failed to parse subscription data from server.");
        }
      } else if (response.statusCode == 404) {
        print("No active subscription found (404).");
        return null;
      } else {
        String errorDetail = "(${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          if(errorBody is Map && errorBody.containsKey('message')){ errorDetail += " ${errorBody['message']}"; }
          else if(errorBody is Map && errorBody.containsKey('error')){ errorDetail += " ${errorBody['error']}"; }
          else { errorDetail += " ${response.body}";}
        } catch(_) { errorDetail += " ${response.body}"; }
        throw Exception("Failed to load subscription $errorDetail");
      }
    } catch (e) {
      print("Error in _fetchSubscription catch block: $e");
      throw Exception("Subscription fetch failed: $e");
    }
  }

  Future<UserCreditData?> _fetchCredit(Map<String, String> headers) async {
    final url = Uri.parse("${AppConfig.baseUrl}payment/user/credit/");
    try {
      final response = await http.get(url, headers: headers);
      if (!mounted) return null;
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body.toLowerCase() == 'null') {
          print("Warning: Credit endpoint returned 200 but null/empty body.");
          throw Exception("Credit data missing despite 200 OK.");
        }
        try {
          return UserCreditData.fromJson(jsonDecode(body));
        } catch (e) {
          print("Error decoding credit JSON: $e. Body was: '$body'");
          throw Exception("Failed to parse credit data from server.");
        }
      } else {
        String errorDetail = "(${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          if(errorBody is Map && errorBody.containsKey('error')){ errorDetail += " ${errorBody['error']}"; }
          if(errorBody is Map && errorBody.containsKey('details')){ errorDetail += " (${errorBody['details']})"; }
          else { errorDetail += " ${response.body}";}
        } catch(_) { errorDetail += " ${response.body}"; }
        throw Exception("Failed to load credits $errorDetail");
      }
    } catch (e) {
      print("Error in _fetchCredit catch block: $e");
      throw Exception("Credit fetch failed: $e");
    }
  }

  SubscriptionPlan _mapPlanNameToEnum(String? planName) {
    if (planName == null || planName.isEmpty || planName.toLowerCase() == 'unknown') {
      return SubscriptionPlan.none;
    }
    switch (planName.toLowerCase()) {
      case 'trial': return SubscriptionPlan.trial;
      case 'premium': return SubscriptionPlan.premium;
      case 'vip': return SubscriptionPlan.vip;
      default:
        print("Warning: Unknown plan name received from API: $planName");
        return SubscriptionPlan.none;
    }
  }

  void _updateTimeRemaining() {
    if (_activeSubscriptionData == null || !mounted) {
      if (mounted) setState(() => _timeRemaining = "");
      _timer?.cancel(); return;
    }
    final now = DateTime.now();
    final endDate = _activeSubscriptionData!.endDate;
    final difference = endDate.difference(now);
    if (difference.isNegative) {
      if (mounted) setState(() => _timeRemaining = "Expired");
      _timer?.cancel();
    } else {
      String days = difference.inDays.toString().padLeft(2, '0');
      String hours = (difference.inHours % 24).toString().padLeft(2, '0');
      String minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
      String seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
      String remainingStr = "";
      if (difference.inDays > 0) { remainingStr = "${days}d ${hours}h ${minutes}m left"; }
      else if (difference.inHours > 0) { remainingStr = "${hours}h ${minutes}m ${seconds}s left"; }
      else if (difference.inMinutes > 0) { remainingStr = "${minutes}m ${seconds}s left"; }
      else { remainingStr = "${seconds}s left"; }
      if (mounted) setState(() => _timeRemaining = remainingStr);
    }
  }

  // --- NEW: Styled Confirmation Dialog Helper ---
  Future<bool?> _showStyledConfirmationDialog(
      SubscriptionPlan plan, String planTitle) async {

    final IconData planIcon = _getPlanIcon(plan);
    final Color planColor = _getPlanColor(plan);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog( // Use Dialog for more customization
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0), // Match card radius
          ),
          elevation: 5,
          backgroundColor: Colors.transparent, // Make Dialog background transparent
          child: Container( // Main dialog content container
            decoration: BoxDecoration(
                color: cardBackgroundColor, // Use card background color
                borderRadius: BorderRadius.circular(18.0),
                boxShadow: [ // Subtle shadow like cards
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 4),
                  ),
                ]
            ),
            child: ClipRRect( // Clip content to rounded shape
              borderRadius: BorderRadius.circular(18.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Fit content size
                children: <Widget>[
                  // --- Dialog Header (with Plan Color/Icon) ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient( // Match card header gradient
                        colors: [planColor.withOpacity(0.85), planColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      // No bottom border radius needed here as it's part of the column
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

                  // --- Dialog Content ---
                  Padding(
                    padding: const EdgeInsets.all(24.0), // More padding for content
                    child: Text(
                      'Proceed to upgrade your plan to $planTitle?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor, // Use themed text color
                        height: 1.4,
                      ),
                    ),
                  ),

                  // --- Dialog Actions ---
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 8),
                    child: Row(
                      // Space buttons apart
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // Cancel Button (less emphasis)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0), // Match ElevatedButton
                            ),
                            side: BorderSide(color: Colors.grey.shade400),
                            foregroundColor: secondaryTextColor, // Subtle color
                          ),
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop(false); // Return false
                          },
                        ),
                        // Confirm Button (primary action)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: planColor, // Use plan color
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0), // Match card button
                            ),
                            elevation: 3,
                          ),
                          child: Text('Confirm'),
                          onPressed: () {
                            Navigator.of(context).pop(true); // Return true
                          },
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

  // --- UPDATED: Handle selecting a plan (calls styled dialog) ---
  Future<void> _selectPlan(SubscriptionPlan selectedPlan, String planTitle) async {
    // Initial checks
    if (selectedPlan != SubscriptionPlan.premium && selectedPlan != SubscriptionPlan.vip) { return; }
    if (!(_currentPlan == SubscriptionPlan.trial || _currentPlan == SubscriptionPlan.none)) {
      ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("You already have Premium/VIP."), backgroundColor: Colors.orange));
      return;
    }

    // Show *Styled* Confirmation Dialog
    final bool? confirmed = await _showStyledConfirmationDialog(selectedPlan, planTitle); // UPDATED CALL

    // Proceed only if confirmed
    if (confirmed == true) {
      if (!mounted) return;
      setState(() { _isUpgrading = true; _errorMessage = null; });

      String? token = await _secureStorage.read(key: 'access_token');
      if (token == null) {
        if (mounted) {
          setState(() { _isUpgrading = false; });
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Authentication error."), backgroundColor: Colors.red));
        } return;
      }

      String? upgradeError;
      bool success = false;
      // Wrap upgrade attempt in try/finally
      try {
        success = await _performUpgrade(selectedPlan, token).catchError((e) { upgradeError = e.toString(); return false; });
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("Successfully upgraded to $planTitle!"), backgroundColor: Colors.green));
          await _fetchInitialData(); // Refresh data
        } else {
          final message = upgradeError != null ? "Upgrade failed: $upgradeError" : "Upgrade failed.";
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(message), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text("An unexpected error occurred: $e"), backgroundColor: Colors.red));
          print("Error during plan selection flow: $e");
        } success = false;
      } finally {
        // Ensure loader is always removed
        if (mounted) { setState(() { _isUpgrading = false; }); }
      }
    } // End if (confirmed == true)
  }

  Future<bool> _performUpgrade(SubscriptionPlan targetPlan, String token) async {
    String endpointPath;
    if (targetPlan == SubscriptionPlan.premium) { endpointPath = "subscription/upgrade-to-premium/"; }
    else if (targetPlan == SubscriptionPlan.vip) { endpointPath = "subscription/upgrade-to-vip/"; }
    else { throw Exception("Invalid target plan for upgrade."); }
    final url = Uri.parse(AppConfig.baseUrl + endpointPath);
    final headers = { "Authorization": "Bearer $token", "Content-Type": "application/json" };
    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        print("Upgrade successful: ${response.body}"); return true;
      } else {
        String errorMessage = "(${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody.containsKey('message')) { errorMessage += ": ${errorBody['message']}"; }
          else if (errorBody is Map && errorBody.containsKey('error')) { errorMessage += ": ${errorBody['error']}"; }
          else { errorMessage += ". Response: ${response.body}"; }
        } catch (_) { errorMessage += ". Could not parse error: ${response.body}"; }
        print("Upgrade API Error: $errorMessage"); throw Exception(errorMessage);
      }
    } catch (e) {
      print("Network/Error during upgrade POST: $e"); throw Exception("Upgrade request failed: $e");
    }
  }
  // --- End Lifecycle and Fetch Methods ---

  @override
  Widget build(BuildContext context) {
    // Use Stack for the loader overlay
    return Stack(
      children: [
        Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text("Subscription Plans", style: TextStyle(color: headingColor, fontSize: 18, fontWeight: FontWeight.w600)),
            backgroundColor: cardBackgroundColor,
            elevation: 1,
            centerTitle: true,
            automaticallyImplyLeading: false, // No back button
            actions: [
              Padding( // Credit display
                padding: const EdgeInsets.only(right: 12.0),
                child: Center( child: Row( children: [
                  Icon(Icons.monetization_on_outlined, color: premiumColor, size: 20),
                  SizedBox(width: 4),
                  Text( _isLoading ? "..." : (_userCredit?.creditBalance ?? "---"), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: headingColor),),
                ],),),
              ),
            ],
          ),
          // --- Body Content ---
          body: _isLoading
              ? Center(child: CircularProgressIndicator()) // General page loading
              : _errorMessage != null
              ? _buildErrorContent(_errorMessage!)
              : _buildLoadedContent(),
        ),

        // --- Upgrade Loader Overlay ---
        if (_isUpgrading)
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
                    Text(
                      "Upgrading plan...",
                      style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Helper: Build Error Content ---
  Widget _buildErrorContent(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 45),
            SizedBox(height: 15),
            Text( "Failed to Load Subscription Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: headingColor), textAlign: TextAlign.center,),
            SizedBox(height: 8),
            Text( errorMsg, textAlign: TextAlign.center, style: TextStyle(color: secondaryTextColor)),
            SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh), label: Text("Retry"),
              style: ElevatedButton.styleFrom( padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              onPressed: _isLoading || _isUpgrading ? null : _fetchInitialData,
            )
          ],
        ),
      ),
    );
  }

  // --- Helper: Build Loaded Content ---
  Widget _buildLoadedContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Text
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column( children: [
                Text( "Upgrade Your Plan!", textAlign: TextAlign.center, style: TextStyle( fontSize: 22, fontWeight: FontWeight.bold, color: headingColor,),),
                SizedBox(height: 8),
                Text( "Unlock exciting features and enhance your experience with our premium plans.", textAlign: TextAlign.center, style: TextStyle( fontSize: 14, color: secondaryTextColor, height: 1.4 ),),
              ],),
            ),
            // Subscription Cards
            _buildSubscriptionCard(
              plan: SubscriptionPlan.trial, title: "Trial", icon: Icons.hourglass_empty_rounded, baseColor: trialColor,
              monthlyPriceCoins: 0, monthlyPriceDT: 0, yearlyPriceCoins: 0, yearlyPriceDT: 0,
              features: [ _currentPlan == SubscriptionPlan.trial ? "Current 3-day free access" : "Basic 3-day trial", "Explore basic features", "Community Support", ],
            ),
            SizedBox(height: 20),
            _buildSubscriptionCard(
              plan: SubscriptionPlan.premium, title: "Premium", icon: Icons.star_rounded, baseColor: premiumColor,
              monthlyPriceCoins: 100, monthlyPriceDT: 10, yearlyPriceCoins: 900, yearlyPriceDT: 90,
              features: [ "Full Feature Access", "Priority Support", "No Ads", "Advanced Analytics", ],
            ),
            SizedBox(height: 20),
            _buildSubscriptionCard(
              plan: SubscriptionPlan.vip, title: "VIP", icon: Icons.diamond_rounded, baseColor: vipColor,
              monthlyPriceCoins: 150, monthlyPriceDT: 15, yearlyPriceCoins: 1100, yearlyPriceDT: 110,
              features: [ "All Premium Features", "Exclusive Content Access", "Dedicated Support Manager", "Early Beta Access", ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widget to build individual subscription cards ---
  Widget _buildSubscriptionCard({
    required SubscriptionPlan plan,
    required String title,
    required IconData icon,
    required Color baseColor,
    required int monthlyPriceCoins,
    required int monthlyPriceDT,
    required int yearlyPriceCoins,
    required int yearlyPriceDT,
    required List<String> features,
  }) {
    bool isActive = _currentPlan == plan && plan != SubscriptionPlan.none;
    bool canChoosePlan = false;
    if (plan == SubscriptionPlan.premium || plan == SubscriptionPlan.vip) {
      canChoosePlan = (_currentPlan == SubscriptionPlan.none || _currentPlan == SubscriptionPlan.trial);
    }
    bool showChooseButton = plan == SubscriptionPlan.premium || plan == SubscriptionPlan.vip;
    bool disableButton = _isUpgrading || isActive || (showChooseButton && !canChoosePlan) ;

    String displayPrice = _showYearly ? "$yearlyPriceCoins Coins / $yearlyPriceDT DT" : "$monthlyPriceCoins Coins / $monthlyPriceDT DT";
    String displayPeriod = _showYearly ? "/ Year" : "/ Month";
    if(plan == SubscriptionPlan.trial) { displayPrice = "Free"; displayPeriod = " for 3 days"; }

    Color currentBorderColor = isActive ? activePlanBorderColor : Colors.grey.shade200;
    double currentBorderWidth = isActive ? 2.5 : 1.0;
    List<BoxShadow>? currentShadow = isActive ? [ BoxShadow( color: activePlanHighlightColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 1, offset: Offset(0, 6)),] : [ BoxShadow( color: Colors.grey.withOpacity(0.1), blurRadius: 12, spreadRadius: 1, offset: Offset(0, 5)),];

    return Container(
      decoration: BoxDecoration( color: cardBackgroundColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: currentBorderColor, width: currentBorderWidth), boxShadow: currentShadow,),
      child: ClipRRect( borderRadius: BorderRadius.circular(17), child: Column( children: [
        // Header
        Container( padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), decoration: BoxDecoration( gradient: LinearGradient( colors: [baseColor.withOpacity(0.85), baseColor], begin: Alignment.topLeft, end: Alignment.bottomRight),),
          child: Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container( padding: const EdgeInsets.all(8), decoration: BoxDecoration( color: cardBackgroundColor.withOpacity(0.9), shape: BoxShape.circle), child: Icon(icon, size: 26, color: baseColor),), SizedBox(width: 12),
            Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold, color: cardHighlightTextColor)), SizedBox(height: 3),
              RichText( text: TextSpan( style: TextStyle(color: cardHighlightTextColor.withOpacity(0.95), fontSize: 15, fontWeight: FontWeight.w600), children: <TextSpan>[
                TextSpan(text: displayPrice),
                if (plan != SubscriptionPlan.trial) TextSpan( text: displayPeriod, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
              ],),),
            ],),),
            if (isActive && _timeRemaining.isNotEmpty && _timeRemaining != "Expired") // Time Remaining
              Container( margin: EdgeInsets.only(left: 8), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration( color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10),),
                child: Text( _timeRemaining, style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),),)
            else if (isActive && _timeRemaining == "Expired") // Expired
              Container( margin: EdgeInsets.only(left: 8), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration( color: Colors.red.shade400.withOpacity(0.8), borderRadius: BorderRadius.circular(10),),
                child: Text( "Expired", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),),)
          ],),
        ),
        // Features and Action
        Padding( padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column( crossAxisAlignment: CrossAxisAlignment.start, children: features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 9.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle_outline_rounded, size: 17, color: isActive ? activePlanHighlightColor : Colors.grey.shade500), SizedBox(width: 9),
            Expanded(child: Text(feature, style: TextStyle(fontSize: 13.5, color: textColor))),
          ],),)).toList(),), SizedBox(height: 20),
          Center( child: isActive ? Chip( // Active Plan Chip
            avatar: Icon(Icons.check_circle, color: activePlanHighlightColor, size: 18), label: Text("Your Current Plan"),
            backgroundColor: activePlanHighlightColor.withOpacity(0.1), labelStyle: TextStyle(color: activePlanHighlightColor, fontWeight: FontWeight.bold, fontSize: 13),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), side: BorderSide(color: activePlanHighlightColor.withOpacity(0.3)),)
              : showChooseButton ? ElevatedButton( // Choose Plan Button
            style: ElevatedButton.styleFrom(
              backgroundColor: baseColor, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 35, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), elevation: disableButton ? 0 : 2,
              disabledBackgroundColor: baseColor.withOpacity(0.4), disabledForegroundColor: Colors.white.withOpacity(0.7),
            ),
            // Pass plan and title to _selectPlan
            onPressed: disableButton ? null : () => _selectPlan(plan, title), // Use selectedPlan enum here
            child: Text( "Choose Plan", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),),)
              : SizedBox.shrink(),
          ),
        ],),),
      ],),),
    );
  }

} // End of _SubscriptionPageState