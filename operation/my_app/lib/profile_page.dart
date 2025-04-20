import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart'; // Import for number formatting
import 'package:shimmer/shimmer.dart';

// --- Import your actual pages and config ---
// Ensure these paths are correct for your project structure
import 'config.dart'; // Assuming you have this
import 'recharge_page.dart'; // Assuming you have this
import 'recharge_cards_status.dart'; // Assuming you have this
import 'subscription_history.dart'; // Assuming you have this
// Add imports for EditProfilePage and WelcomePage if they exist and are used
// import 'edit_profile_page.dart';
// Make sure '/welcome' route points here in your MaterialApp
// -------------------------------------------

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? userInfo;
  String? userCredit; // Store as String from API
  bool _dataFetched = false;
  bool isLoading = true;
  String? errorMessage;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Currency Formatter
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$', // Use '$' symbol
    decimalDigits: 2, // Ensure two decimal places
  );

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs/pages

  @override
  void initState() {
    super.initState();
    // Fetch data only once initially if it hasn't been fetched yet
    if (!_dataFetched) {
      _fetchAllData();
    }
  }

  // --- Helper Function to Determine Display Name ---
  String _getDisplayName() {
    // Handle case where userInfo hasn't loaded yet
    if (userInfo == null) {
      // This is mostly a fallback, shimmer should cover loading state
      return "User";
    }

    // Safely get first_name and username, treat null/non-string as empty, trim whitespace
    String firstName = (userInfo!['first_name'] as String?)?.trim() ?? "";
    String username = (userInfo!['username'] as String?)?.trim() ?? ""; // Fallback

    // Return first_name if it's not empty, otherwise username, otherwise a default
    if (firstName.isNotEmpty) {
      return firstName;
    } else if (username.isNotEmpty) {
      return username;
    } else {
      return "User"; // Final fallback if both are empty/missing
    }
  }
  // --- End Helper Function ---


  // Method to fetch all necessary data concurrently
  Future<void> _fetchAllData() async {
    if (!mounted) return; // Check if the widget is still in the tree

    // Set loading state (only if not already loading or for initial load)
    if (!isLoading || !_dataFetched) {
      setState(() {
        isLoading = true;
        errorMessage = null; // Clear previous errors on refresh/load attempt
      });
    }

    try {
      // Fetch user info and credit in parallel
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
      // Error messages are usually set within specific fetch methods.
      // Set a generic one here if none was set previously.
      if (mounted && errorMessage == null) {
         setState(() {
           errorMessage = "An error occurred. Please pull down to refresh.";
         });
      }
      print("Error during _fetchAllData: $e"); // Log the error for debugging
    } finally {
      // Ensure loading state is turned off regardless of success or failure
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Fetch user details from the API
  Future<void> fetchUserInfo() async {
    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
       if (mounted) {
         setState(() {
           // Append error messages if multiple errors occur
           errorMessage = (errorMessage ?? "") + "\nUser Info: Authentication token missing.";
         });
       }
      throw Exception("No access token found for user info request.");
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}user-info/"), // Use your API endpoint from config
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(Duration(seconds: 15)); // Add a timeout for network requests

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            userInfo = jsonDecode(response.body);
            // Clear specific part of error message if successful, only if generic message isn't set
            // (This logic can get complex, might be simpler to just clear all on success)
          });
        } else {
           setState(() {
            errorMessage = (errorMessage ?? "") + "\nUser Info: Failed to load (${response.statusCode}).";
          });
          throw Exception("Failed to fetch user info: Status Code ${response.statusCode}");
        }
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nUser Info Error: ${e.toString()}";
         });
       }
       rethrow; // Rethrow the exception to be caught by _fetchAllData
    }
  }

  // Fetch user credit balance from the API
  Future<void> fetchUserCredit() async {
     String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nCredit: Authentication token missing.";
         });
       }
        throw Exception("No access token found for credit request.");
    }

    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}payment/user/credit/"), // Use your API endpoint from config
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ).timeout(Duration(seconds: 15)); // Add a timeout

       if (mounted) {
          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            // Safely extract the credit balance, handling various types
            dynamic creditValue = body['credit_balance'];
            String creditString = '0.00'; // Sensible default

            if (creditValue != null) {
              if (creditValue is num) {
                // Format number to string with fixed decimal places if needed, or just convert
                creditString = creditValue.toString();
              } else if (creditValue is String) {
                 // Try parsing string, fallback if parse fails
                 creditString = double.tryParse(creditValue)?.toString() ?? '0.00';
              }
            }

            setState(() {
               userCredit = creditString; // Store the raw string value
               // Clear specific part of error message if successful
            });
          } else {
             setState(() {
              errorMessage = (errorMessage ?? "") + "\nCredit: Failed to load (${response.statusCode}).";
            });
            throw Exception("Failed to fetch user credit: Status Code ${response.statusCode}");
          }
       }
    } catch (e) {
       if (mounted) {
         setState(() {
           errorMessage = (errorMessage ?? "") + "\nCredit Error: ${e.toString()}";
         });
       }
       rethrow; // Rethrow to be caught by _fetchAllData
    }
  }

  // Helper getter to format the stored credit string for display
  String get formattedCredit {
    if (userCredit == null) return '\$...'; // Loading indicator
    final double? creditDouble = double.tryParse(userCredit!);
    if (creditDouble == null) return '\$ N/A'; // Handle parsing error gracefully
    return _currencyFormat.format(creditDouble); // Format using intl package
  }

  // Handles the logout process
  Future<void> _handleLogout() async {
    // Optional: Show confirmation dialog before logging out
    bool confirmed = await showDialog<bool>( // Specify type for clarity
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Logout"),
        content: Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text("Cancel")),
          TextButton(
             onPressed: () => Navigator.of(context).pop(true),
             child: Text("Logout", style: TextStyle(color: const Color.fromARGB(255, 255, 50, 35))) // Style logout button
          ),
        ],
      ),
    ) ?? false; // Default to false if dialog is dismissed (e.g., tapping outside)

    if (confirmed && mounted) { // Check confirmation and if widget is still mounted
      print("Logout Confirmed - Clearing storage and navigating...");
      try {
        // Clear all data from secure storage (tokens, etc.)
        await _secureStorage.deleteAll();

        // Navigate to Welcome/Login page and remove all routes behind it
        // IMPORTANT: Ensure '/welcome' is correctly defined in your MaterialApp routes.
        Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
          '/welcome', // Replace with your actual welcome/login route name
          (Route<dynamic> route) => false, // Predicate always returns false to remove all routes
        );
      } catch (e) {
          print("Error during logout: $e");
          // Optionally show a snackbar or dialog if logout fails critically
          if(mounted){
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Logout failed. Please try again."), backgroundColor: Colors.red)
            );
          }
      }
    } else {
      print("Logout Cancelled");
    }
  }


   @override
  Widget build(BuildContext context) {
    super.build(context); // Necessary for AutomaticKeepAliveClientMixin

    // Determine shimmer states based on loading flag and data availability
    bool showUserShimmer = isLoading || (!_dataFetched && userInfo == null);
    bool showCreditShimmer = isLoading || (!_dataFetched && userCredit == null);

    return Scaffold(
      // Set background color matching the desired UI
      backgroundColor: Color(0xFFF8F8F8), // Light grey background
      body: RefreshIndicator(
        onRefresh: _fetchAllData, // Enable pull-to-refresh
        child: CustomScrollView( // Use CustomScrollView for flexible layout with headers
          slivers: [
            // --- Custom Header Area ---
            SliverPadding(
              padding: const EdgeInsets.only(top: kToolbarHeight * 0.8, left: 16.0, right: 16.0, bottom: 10.0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Title, Name, Email... (as before)
                           Text(
                            "Profile",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          showUserShimmer
                            ? _buildShimmerContainer(width: 140, height: 18)
                            : Text(
                                _getDisplayName(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [

                              showUserShimmer
                                ? _buildShimmerContainer(width: 180, height: 14)
                                : Flexible(
                                    child: Text(
                                      userInfo?['email'] as String? ?? 'loading email...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),


            // --- Error Message Display Area ---
             if (errorMessage != null && !isLoading)
               SliverPadding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                 sliver: SliverToBoxAdapter(
                   child: Container(
                      // ... Error message container styling ...
                     padding: EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.red.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                     ),
                     child: Text(
                       errorMessage!.trim(),
                       style: TextStyle(color: Colors.redAccent[700], fontWeight: FontWeight.w500),
                       textAlign: TextAlign.center,
                     ),
                   ),
                 ),
               ),

            // --- Balance Card Section ---
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Container(
                   // ... Balance card styling and content ...
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF3A86FF),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [ /* ... shadow ... */ ],
                  ),
                   child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row( /* ... Balance label, amount, icon ... */
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text( /* ... Available Balance ... */
                                "Available Balance",
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                              ),
                              SizedBox(height: 8),
                              showCreditShimmer
                                ? _buildShimmerContainer(width: 120, height: 28, isWhiteOnBlue: true)
                                : Text( /* ... Formatted Credit ... */
                                    formattedCredit,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                            ],
                          ),
                          Container( /* ... Wallet Icon ... */
                             padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 26),
                          )
                        ],
                      ),
                      SizedBox(height: 25),
                      SizedBox( /* ... Recharge Button ... */
                         width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add, size: 20),
                          label: Text("Recharge Balance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xFF3A86FF),
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                           onPressed: isLoading ? null : () {
                            print("Navigating to Recharge Page...");
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RechargePage()),
                            ).then((result) {
                              if (result == true) {
                                print("Recharge page indicated success, refreshing profile...");
                                _fetchAllData();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- List of Profile Options (MODIFIED) ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Padding around the list
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // --- "Cards Status" Tile REMOVED ---
                    // _buildOptionTile(
                    //   icon: Icons.credit_card,
                    //   iconBackgroundColor: Colors.purple[50]!,
                    //   title: "Cards Status",
                    //   subtitle: "View your cards",
                    //   onTap: () { /* ... was navigating to RechargeCardsStatusPage ... */ },
                    // ),

                    // --- "History" Tile MODIFIED ---
                    _buildOptionTile(
                      icon: Icons.history_rounded, // History icon
                      iconBackgroundColor: Colors.lightBlue[50]!, // Light blue accent
                      title: "History",
                      subtitle: "Transaction history", // Subtitle remains the same
                      onTap: () {
                        // **** THIS NOW NAVIGATES TO RechargeCardsStatusPage ****
                        print("Navigating to Card Status/History Page...");
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RechargeCardsStatusPage()),
                        );
                      },
                    ),

                    // --- Other Tiles Remain the Same ---
                    _buildOptionTile(
                      icon: Icons.receipt_long_outlined, // Receipt icon for subscriptions
                      iconBackgroundColor: Colors.green[50]!, // Light green accent
                      title: "Subscription History",
                      subtitle: "View your subscriptions",
                      onTap: () {
                        print("Navigating to Subscription History Page...");
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SubscriptionHistoryPage()),
                        );
                      },
                    ),
                    _buildOptionTile(
                      icon: Icons.person_outline_rounded, // User profile icon
                      iconBackgroundColor: Colors.orange[50]!, // Light orange accent
                      title: "Edit Profile",
                      subtitle: "Update your information",
                      onTap: () {
                         // TODO: Implement navigation to the Edit Profile page
                         print("Navigate to Edit Profile page (Not Implemented)");
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text("Edit Profile page not yet implemented."), duration: Duration(seconds: 2))
                         );
                         // Example navigation:
                         // Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfilePage()));
                      },
                    ),

                    // --- LOGOUT TILE ---
                    SizedBox(height: 10), // Add a little space before logout for visual separation
                    _buildOptionTile(
                      icon: Icons.logout, // Logout icon
                      iconBackgroundColor: Colors.red[50]!, // Light red background accent
                      // Using simple title, uncomment titleWidget for red text
                      title: "Logout",
                      // titleWidget: Text(
                      //   "Logout",
                      //    style: TextStyle(
                      //      fontSize: 16,
                      //      fontWeight: FontWeight.w600,
                      //      color: Colors.redAccent, // Red color for title
                      //    ),
                      // ),
                      subtitle: "Sign out of your account", // Descriptive subtitle
                      onTap: isLoading ? () {} : _handleLogout, // Call the existing logout handler, disable during load
                    ),
                    // --- END LOGOUT TILE ---

                    SizedBox(height: 20), // Keep breathing room at the bottom
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 // ... (Keep _buildShimmerContainer and _buildOptionTile functions as they were) ...

 // Helper widget to build shimmer containers consistently
  Widget _buildShimmerContainer({required double width, required double height, bool isWhiteOnBlue = false}) {
     // ... implementation ...
     return Shimmer.fromColors(
      baseColor: isWhiteOnBlue ? Colors.white.withOpacity(0.7) : Colors.grey[300]!,
      highlightColor: isWhiteOnBlue ? Colors.white : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isWhiteOnBlue ? Colors.white.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }


  // Builds a single option tile for the list below the balance card
  Widget _buildOptionTile({
    required IconData icon,
    required Color iconBackgroundColor,
    String? title,
    Widget? titleWidget,
    required String subtitle,
    required VoidCallback onTap,
  }) {
     // ... implementation ...
     assert(title != null || titleWidget != null, 'Either title or titleWidget must be provided to _buildOptionTile');

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [ /* ... shadow ... */ ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
             child: Row(
              children: [
                Container( /* ... icon container ... */
                   padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.black87.withOpacity(0.7),
                    size: 22
                  ),
                ),
                SizedBox(width: 16),
                Expanded( /* ... Title and Subtitle Column ... */
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleWidget ?? Text(
                        title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // End of _ProfilePageState class