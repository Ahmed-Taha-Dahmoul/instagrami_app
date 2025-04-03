import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shimmer/shimmer.dart';
import 'config.dart';
import 'recharge_page.dart';
import 'recharge_cards_status.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? userInfo;
  String? userCredit;
  bool _dataFetched = false;
  bool isLoading = true; // Flag for initial load or refresh
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Fetch data only once initially when state is created
    if (!_dataFetched) {
      _fetchAllData();
    }
  }

  // This method will be called for initial load AND for refresh
  Future<void> _fetchAllData() async {
    // Don't set isLoading to true if already loading (prevents jittery UI if user pulls again quickly)
    // However, RefreshIndicator manages its own visual state, so setting it here is
    // mainly for controlling the Shimmer effect visibility.
    if (!isLoading && mounted) { // Only set loading if not already loading
      setState(() {
        isLoading = true;
        errorMessage = null; // Clear previous errors on refresh
      });
    } else if (mounted) {
        // If it's the very first load (isLoading is already true from declaration)
        // still clear any potential stale error message.
         setState(() {
            errorMessage = null;
         });
    }


    try {
      // Use Future.wait for concurrent fetching
      await Future.wait([
        fetchUserInfo(),
        fetchUserCredit(),
      ]);
      if (mounted) {
        setState(() {
           _dataFetched = true; // Mark that data has been successfully fetched at least once
        });
      }
    } catch (e) {
      // Error messages are set within the specific fetch methods
      // We just need to ensure the loading state is handled in finally
      if (mounted) {
         print("Error during _fetchAllData: $e");
         // The specific error message should already be set by fetchUserInfo/fetchUserCredit
         // If Future.wait itself fails (less likely here), set a generic one:
         if (errorMessage == null) {
           setState(() {
              errorMessage = "An error occurred during refresh.";
           });
         }
      }
    } finally {
      // Ensure loading state is turned off after fetches complete or fail
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchUserInfo() async {
    // No changes needed here from the previous version
    // (Make sure it includes mounted checks and error setting)
     String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nUser Info: No access token.";
         });
      }
      throw Exception("No access token for user info.");
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}user-info/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            userInfo = jsonDecode(response.body);
          });
        } else {
          setState(() {
            errorMessage = (errorMessage ?? "") + "\nUser Info: Failed (${response.statusCode}).";
          });
           throw Exception("Failed to fetch user info: ${response.statusCode}");
        }
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nUser Info Error: $e";
         });
       }
       rethrow;
    }
  }

  Future<void> fetchUserCredit() async {
    // No changes needed here from the previous version
    // (Make sure it includes mounted checks and error setting)
     String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nCredit: No access token.";
         });
       }
        throw Exception("No access token for credit.");
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}payment/user/credit/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

       if (mounted) {
          if (response.statusCode == 200) {
            setState(() {
              final body = jsonDecode(response.body);
              if (body is Map && body.containsKey('credit_balance')) {
                 userCredit = body['credit_balance']?.toString() ?? '0.0000';
              } else {
                 userCredit = '0.0000';
                 errorMessage = (errorMessage ?? "") + "\nCredit: Invalid response format.";
              }
            });
             print("usercrediiiiiiiiiiiiiiiiiiiiiiit");
             print(userCredit);
          } else {
            setState(() {
              errorMessage = (errorMessage ?? "") + "\nCredit: Failed (${response.statusCode}).";
            });
            throw Exception("Failed to fetch credit: ${response.statusCode}");
          }
       }
    } catch (e) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nCredit Error: $e";
         });
       }
       rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep this for AutomaticKeepAliveClientMixin

    // Calculate shimmer states based on combined loading flag and data presence
    bool showUserShimmer = isLoading || (!_dataFetched && userInfo == null);
    bool showCreditShimmer = isLoading || (!_dataFetched && userCredit == null);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text("Profile"),
        // Removed the explicit refresh button as pull-to-refresh is added
        // actions: [
        //    IconButton(
        //      icon: Icon(Icons.refresh),
        //      onPressed: isLoading ? null : _fetchAllData,
        //    ),
        // ],
      ),
      // Wrap the body's content with RefreshIndicator
      body: RefreshIndicator(
        onRefresh: _fetchAllData, // Point to your data fetching method
        child: Padding( // Keep Padding outside or inside RefreshIndicator? Inside is usually fine.
          padding: const EdgeInsets.all(16.0),
          // Make the Column scrollable if content exceeds screen height,
          // AND allow RefreshIndicator to work even if content is short.
          // Using ListView instead of Column + Expanded(ListView) simplifies the scroll structure.
          child: ListView( // Changed from Column to ListView
            // physics: AlwaysScrollableScrollPhysics(), // Ensures scrolling is always enabled for pull-down
            children: [
              // --- Error Message Display ---
              if (errorMessage != null && !isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    color: Colors.red.withOpacity(0.1),
                    child: Text(
                      "Could not load profile data. $errorMessage",
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // --- User Info Section ---
              Container(
                 margin: EdgeInsets.only(bottom: 20), // Add margin instead of SizedBox
                 padding: EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   boxShadow: [
                     BoxShadow(
                       color: Colors.grey.withOpacity(0.2),
                       blurRadius: 6,
                       spreadRadius: 2,
                     )
                   ],
                 ),
                 child: Row(
                   children: [
                     CircleAvatar(
                       radius: 30,
                       backgroundColor: Colors.blueAccent,
                       child: Icon(Icons.person, color: Colors.white, size: 30),
                     ),
                     SizedBox(width: 12),
                     showUserShimmer
                         ? Shimmer.fromColors(
                             baseColor: Colors.grey[300]!,
                             highlightColor: Colors.grey[100]!,
                             child: Container(
                               width: 120,
                               height: 20,
                               color: Colors.white,
                             ),
                           )
                         : Text(
                             "Hello, ${userInfo?['username'] ?? 'User'}!",
                             style: TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                   ],
                 ),
               ),

              // --- Balance Section ---
              Container(
                 margin: EdgeInsets.only(bottom: 20), // Add margin instead of SizedBox
                 padding: EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   gradient: LinearGradient(
                     colors: [Colors.blueAccent, Colors.lightBlueAccent],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       "Balance",
                       style: TextStyle(color: Colors.white, fontSize: 16),
                     ),
                     SizedBox(height: 5),
                     showCreditShimmer
                         ? Shimmer.fromColors(
                             baseColor: Colors.white70,
                             highlightColor: Colors.white,
                             child: Container(
                               width: 80,
                               height: 24,
                               color: Colors.white,
                             ),
                           )
                         : Text(
                             "${userCredit ?? 'N/A'} Coins",
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: 22,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                     Align(
                       alignment: Alignment.centerRight,
                       child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueAccent,
                        ),
                        onPressed: () {
                          // Navigate to the new RechargePage
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RechargePage()),
                          ).then((result) {
                            // Optional: Handle result after RechargePage pops
                            // For example, refresh profile if recharge was successful
                            if (result == true) { // Check if recharge page indicated success
                              print("Recharge successful, refreshing profile...");
                              _fetchAllData(); // Re-fetch profile data (including credit)
                            }
                          });
                          print("Recharge button pressed - Navigating");
                        },
                        child: Text("Recharge"),
                      ),
                     ),
                   ],
                 ),
               ),

              // --- Options List ---
              // These are now direct children of the outer ListView
              _buildOptionTile(Icons.payment, "Cards Status and History", () {
                print("Tapped Cards Status and History - Navigating..."); // Optional: for debugging
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RechargeCardsStatusPage()),
                );
              }),
               _buildOptionTile(Icons.subscriptions, "Subscription History", (){
                  print("Tapped Subscription History");
                  // TODO: Navigate
               }),
               // Add Edit Profile, Settings, etc.
                _buildOptionTile(Icons.edit, "Edit Profile", (){
                  print("Tapped Edit Profile");
                  // TODO: Navigate or show dialog
               }),
               _buildOptionTile(Icons.logout, "Logout", () async {
                   print("Logout Tapped - Implementing logout...");
                   // Clear secure storage
                   await _secureStorage.deleteAll();

                   // Navigate to Welcome/Login page and remove all previous routes
                   // Ensure you have access to the root navigator or use a state management solution
                   if (mounted) { // Ensure widget is still mounted
                    // Assuming you have a way to reset the login state in MyApp or using a provider
                    // This is a common way, but might need adjustment based on your exact setup
                     Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                       '/welcome', // Make sure '/welcome' route is defined in your AppRoutes pointing to WelcomePage
                       (Route<dynamic> route) => false,
                     );
                   }
                }),
            ],
          ),
        ),
      ),
    );
  }

  // _buildOptionTile remains the same
  Widget _buildOptionTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          )
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}