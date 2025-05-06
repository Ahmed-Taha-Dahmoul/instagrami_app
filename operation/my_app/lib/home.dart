import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED Import
import 'dart:convert'; // ADDED Import

// --- Import your other necessary files ---
import 'instagram_login.dart';
import 'api_service.dart';

import 'first_time_flag_service.dart';
import 'who_unfollowed_you.dart';
import 'followed_but_not_followed_back.dart';
import 'not_followed_but_following_me.dart';
import 'search_someone_screen.dart';
import 'who_removed_you.dart';
import 'instagram_service.dart';
// --- End Imports ---

// --- Define Colors and Styles ---
const Color kPrimaryColor = Color(0xFFE1306C); // Example Instagram-like pink
const Color kConnectedColor = Color(0xFF4CAF50); // Green
const Color kErrorColor = Color(0xFFF44336); // Red
const Color kCardBackgroundColor = Colors.white;
const Color kScaffoldBackgroundColor = Color(0xFFFAFAFA); // Very light grey
const Color kTextColor = Color(0xFF262626); // Dark grey text
const Color kSecondaryTextColor = Color(0xFF8e8e8e); // Lighter grey text

// Icon background colors
const Color kPinkIconBg = Color(0xFFFFE0E6);
const Color kOrangeIconBg = Color(0xFFFFEEE0);
const Color kPurpleIconBg = Color(0xFFEAE0FF);
const Color kBlueIconBg = Color(0xFFE0F2FF);
const Color kTealIconBg = Color(0xFFE0FFFA);

// Icon colors (used for text counts matching background)
const Color kPinkIcon = Color(0xFFE91E63);
const Color kOrangeIcon = Color(0xFFFF9800);
const Color kPurpleIcon = Color(0xFF9C27B0);
const Color kBlueIcon = Color(0xFF2196F3);
const Color kTealIcon = Color(0xFF009688); // Kept for Profile Checker concept

// Text Styles
const TextStyle kTitleTextStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 16,
  color: kTextColor,
);

const TextStyle kSubtitleTextStyle = TextStyle(
  fontSize: 14,
  color: kSecondaryTextColor,
);

const TextStyle kStatsNumberStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 18,
  color: kTextColor,
);

const TextStyle kStatsLabelStyle = TextStyle(
  fontSize: 13,
  color: kSecondaryTextColor,
);

const TextStyle kCardTitleStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 15,
  color: kTextColor,
);
// --- End Colors and Styles ---

// --- SharedPreferences Keys --- ADDED KEYS
const String kPrefKeyIsConnected = 'home_is_instagram_connected';
const String kPrefKeyUserProfile = 'home_instagram_user_profile_json';
const String kPrefKeyStats = 'home_instagram_stats_json';
const String kPrefKeyIsMoreThanCount = 'home_is_more_than_count';
const String kPrefKeyErrorMessage = 'home_error_message';
// --- End SharedPreferences Keys ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // --- State variables from your original code ---
  bool isInstagramConnected = false;
  var instagramData;
  bool isLoading = false;
  bool isMoreThanCount = false;
  bool isFirstTimeUser = false; // Default value, will be checked
  Map<String, dynamic>? instagramUserProfile;
  String errorMessage = "";
  late AnimationController _profileAnimationController;

  // --- ADDED State variable for new UI ---
  Map<String, dynamic>? instagramStats;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs; // ADDED SharedPreferences instance

  @override
  bool get wantKeepAlive => true;

  // Helper to safely update state only if the widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // --- Function to save the current UI state --- ADDED FUNCTION
  Future<void> _saveStateToPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(kPrefKeyIsConnected, isInstagramConnected);
    await _prefs?.setBool(kPrefKeyIsMoreThanCount, isMoreThanCount);
    await _prefs?.setString(kPrefKeyErrorMessage, errorMessage);

    if (instagramUserProfile != null) {
      try {
        String profileJson = jsonEncode(instagramUserProfile);
        await _prefs?.setString(kPrefKeyUserProfile, profileJson);
      } catch (e) {
        print("Error encoding user profile JSON: $e");
        await _prefs?.remove(kPrefKeyUserProfile); // Clear if encoding fails
      }
    } else {
      await _prefs?.remove(kPrefKeyUserProfile); // Clear if null
    }

    if (instagramStats != null) {
      try {
        String statsJson = jsonEncode(instagramStats);
        await _prefs?.setString(kPrefKeyStats, statsJson);
      } catch (e) {
        print("Error encoding stats JSON: $e");
        await _prefs?.remove(kPrefKeyStats); // Clear if encoding fails
      }
    } else {
      await _prefs?.remove(kPrefKeyStats); // Clear if null
    }
    print("State saved to SharedPreferences.");
  }

  // --- Function to load the UI state from Prefs --- ADDED FUNCTION
  Future<void> _loadStateFromPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Load simple values with defaults
    final bool loadedIsConnected =
        _prefs?.getBool(kPrefKeyIsConnected) ?? false;
    final bool loadedIsMoreThanCount =
        _prefs?.getBool(kPrefKeyIsMoreThanCount) ?? false;
    final String loadedErrorMessage =
        _prefs?.getString(kPrefKeyErrorMessage) ?? "";

    // Load and decode JSON strings
    Map<String, dynamic>? loadedUserProfile;
    final String? profileJson = _prefs?.getString(kPrefKeyUserProfile);
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        loadedUserProfile = jsonDecode(profileJson) as Map<String, dynamic>?;
      } catch (e) {
        print("Error decoding user profile JSON: $e");
        loadedUserProfile = null; // Reset on error
        await _prefs?.remove(kPrefKeyUserProfile); // Clear invalid data
      }
    }

    Map<String, dynamic>? loadedStats;
    final String? statsJson = _prefs?.getString(kPrefKeyStats);
    if (statsJson != null && statsJson.isNotEmpty) {
      try {
        loadedStats = jsonDecode(statsJson) as Map<String, dynamic>?;
      } catch (e) {
        print("Error decoding stats JSON: $e");
        loadedStats = null; // Reset on error
        await _prefs?.remove(kPrefKeyStats); // Clear invalid data
      }
    }

    // Update the state variables directly before the build
    // Use _safeSetState if called after initial build, but here it's usually before
    _safeSetState(() {
      // Use _safeSetState for safety during init
      isInstagramConnected = loadedIsConnected;
      isMoreThanCount = loadedIsMoreThanCount;
      errorMessage = loadedErrorMessage;
      instagramUserProfile = loadedUserProfile;
      instagramStats = loadedStats;
    });

    print("State loaded from SharedPreferences.");
  }

  // --- Function to fetch stats (called from original logic below) ---
  Future<void> _fetchStatsAndUpdateState(String accessToken) async {
    final result = await ApiService.fetchInstagramStatsDifference(accessToken);
    _safeSetState(() {
      if (!result.containsKey('error')) {
        instagramStats = result;
        // Optionally clear error message if stats fetch succeeds
        // errorMessage = "";
      } else {
        instagramStats = null; // Clear stats on error
        errorMessage = result['error'] ??
            "Error fetching stats"; // Set error message from stats fetch
        print("Error fetching stats: ${result['error']}");
      }
    });
    // No need to save prefs here, parent function will save after all steps
  }

  // ========================================================================
  // --- YOUR ORIGINAL LOGIC METHODS (WITH _saveStateToPrefs calls added) ---
  // ========================================================================
  Future<void> _checkFirstTimeFlag(String token) async {
    /* ... Original Code ... */
    bool firstTimeFlag = await FirstTimeFlagService.fetchFirstTimeFlag(token);
    // Use _safeSetState as it might update after initial build
    _safeSetState(() {
      isFirstTimeUser = firstTimeFlag;
    });
    // No need to save state here, _initializeApp decides action based on this flag
  }

  Future<void> _handleInstagramLoginAndCheckFirstTime() async {
    /* ... Original Code ... */
    _safeSetState(() {
      // Use safeSetState
      isLoading = true;
      errorMessage = "";
    });
    String? accessToken = await _secureStorage.read(key: 'access_token');
    dynamic success; // Declare success outside if block

    // Handle case where token might be null initially, requiring login first
    if (accessToken == null) {
      success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InstagramLogin()),
      );
      if (success == true) {
        accessToken = await _secureStorage.read(key: 'access_token');
        if (accessToken == null) {
          _safeSetState(() {
            isLoading = false;
            isInstagramConnected = false;
            errorMessage = "Login succeeded but failed to retrieve token.";
          });
          await _saveStateToPrefs(); // ADDED Save State
          return;
        }
        // Now continue with the token...
      } else {
        _safeSetState(() {
          isLoading = false;
          errorMessage = "Login cancelled or failed.";
        });
        await _saveStateToPrefs(); // ADDED Save State
        return; // Stop if login failed/cancelled
      }
    } else {
      // If token already existed, simulate 'success' to proceed
      // Although the original code has push inside the 'if (accessToken != null)'
      // which seems logically flawed if token exists. Let's assume the original
      // intent was to check status IF token exists.
      // Reverting to EXACT original structure:
      success = await Navigator.push(
        // This runs even if token exists in original code
        context,
        MaterialPageRoute(builder: (context) => InstagramLogin()),
      );
    }

    // ---- Original logic continues below ----
    if (accessToken != null) {
      // This check is now slightly redundant due to handling above, but kept for structure
      // success variable is already determined above
      if (success == true) {
        bool status = await ApiService.checkInstagramStatus(accessToken);
        if (status) {
          final data = await ApiService.getInstagramData(accessToken);
          // Add check for potentially null data from API
          if (data == null || data['user1_id'] == null) {
            _safeSetState(() {
              isLoading = false;
              isInstagramConnected = false;
              errorMessage = "Failed to retrieve necessary Instagram data.";
            });
            await _saveStateToPrefs(); // ADDED Save State
            return;
          }
          String csrftoken = data['csrftoken'];
          String userId = data['user1_id'];
          String sessionId = data['session_id'];
          String xIgAppId = data['x_ig_app_id'];
          await _secureStorage.write(key: 'user1_id', value: data['user1_id']);
          await _secureStorage.write(
              key: 'csrftoken', value: data['csrftoken']);
          await _secureStorage.write(
              key: 'session_id', value: data['session_id']);
          await _secureStorage.write(
              key: 'x_ig_app_id', value: data['x_ig_app_id']);
          bool userInfoSaved = await ApiService.getInstagramUserInfoAndSave(
              userId, csrftoken, sessionId, xIgAppId, accessToken);
          if (userInfoSaved) {
            final userProfile =
                await ApiService.fetchInstagramUserProfile(accessToken);
            bool checkCounts =
                await ApiService.checkInstagramCounts(accessToken);
            _safeSetState(() {
              // Use safeSetState
              // Set profile early, but connection depends on next steps
              instagramUserProfile = userProfile;
              isMoreThanCount = !checkCounts; // Set based on check
            });
            if (checkCounts) {
              // Counts OK (< 20k)
              bool instagram_data_feched_saved =
                  await fetchAndSendfollowing_followers(
                      // Assume this exists
                      accessToken,
                      userId,
                      sessionId,
                      csrftoken,
                      xIgAppId);
              if (instagram_data_feched_saved) {
                // ignore: unused_local_variable
                var response =
                    await ApiService.changeUnfollowStatus(accessToken, false);
                await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                bool flagUpdated = await FirstTimeFlagService.postFirstTimeFlag(
                    accessToken, false);

                _safeSetState(() {
                  // Use safeSetState
                  instagramData = data;
                  isInstagramConnected = true; // Success!
                  isLoading = false;
                  isFirstTimeUser = false;
                  errorMessage =
                      flagUpdated ? "" : "Failed to update first-time flag.";
                });
                await _saveStateToPrefs(); // ADDED Save State
                print("First-time flag updated successfully.");
              } else {
                // Failed fetching follower data
                _safeSetState(() {
                  // Use safeSetState
                  isInstagramConnected =
                      true; // Still connected, profile loaded
                  isLoading = false;
                  // isMoreThanCount already set
                  errorMessage = "Failed to fetch follower/following data.";
                });
                await _saveStateToPrefs(); // ADDED Save State
              }
            } else {
              // Counts NOT OK (> 20k)
              await _fetchStatsAndUpdateState(accessToken); // Fetch stats
              _safeSetState(() {
                // Use safeSetState
                isInstagramConnected = true; // Connected, profile loaded
                isLoading = false;
                // isMoreThanCount already set
                errorMessage =
                    "Account follower/following count exceeds limits.";
              });
              await _saveStateToPrefs(); // ADDED Save State
            }
          } else {
            // UserInfoSave failed
            _safeSetState(() {
              // Use safeSetState
              isInstagramConnected = false;
              isLoading = false;
              errorMessage = "Failed to save Instagram user info.";
              instagramUserProfile = null; // Clear profile
              instagramStats = null; // Clear stats
            });
            await _saveStateToPrefs(); // ADDED Save State
            print("Failed to save Instagram user info.");
          }
        } else {
          // Status check failed
          _safeSetState(() {
            // Use safeSetState
            isInstagramConnected = false;
            isLoading = false;
            errorMessage = "Failed to check Instagram Status.";
            instagramUserProfile = null; // Clear profile
            instagramStats = null; // Clear stats
          });
          await _saveStateToPrefs(); // ADDED Save State
        }
      } else {
        // Login success == false (cancelled or failed)
        _safeSetState(() {
          // Use safeSetState
          isLoading = false;
          errorMessage = "Login cancelled or failed.";
          // isInstagramConnected remains false
        });
        await _saveStateToPrefs(); // ADDED Save State
      }
    } else {
      // accessToken is STILL null after potential login attempt
      _safeSetState(() {
        // Use safeSetState
        isLoading = false;
        isInstagramConnected = false;
        errorMessage = "No access token found. Please log in.";
      });
      await _saveStateToPrefs(); // ADDED Save State
      print("No access token found in secure storage.");
    }
  }

  Future<void> _handleInstagramReconnection() async {
    /* ... Original Code ... */
    _safeSetState(() {
      // Use safeSetState
      isLoading = true;
      errorMessage = "";
    });
    String? accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      bool status = await ApiService.checkInstagramStatus(accessToken);
      if (status) {
        final data = await ApiService.getInstagramData(accessToken);
        // Add check for potentially null data from API
        if (data == null || data['user1_id'] == null) {
          _safeSetState(() {
            // Use safeSetState
            isLoading = false;
            isInstagramConnected = false;
            errorMessage =
                "Failed to retrieve necessary Instagram data on reconnect.";
          });
          await _saveStateToPrefs(); // ADDED Save State
          return;
        }
        String csrftoken = data['csrftoken'];
        String userId = data['user1_id'];
        String sessionId = data['session_id'];
        String xIgAppId = data['x_ig_app_id'];
        await _secureStorage.write(key: 'user1_id', value: data['user1_id']);
        await _secureStorage.write(key: 'csrftoken', value: data['csrftoken']);
        await _secureStorage.write(
            key: 'session_id', value: data['session_id']);
        await _secureStorage.write(
            key: 'x_ig_app_id', value: data['x_ig_app_id']);
        print("afterr getting data ");
        final lastfech = await ApiService.checkIf12HoursPassed(accessToken);
        if (lastfech) {
          // > 12 hours
          print("requesting to the instagram to get the profile ");
          bool userInfoSaved = await ApiService.getInstagramUserInfoAndSave(
              userId, csrftoken, sessionId, xIgAppId, accessToken);
          if (userInfoSaved) {
            print("success feching user profile from instagram");
            final userProfile =
                await ApiService.fetchInstagramUserProfile(accessToken);

            bool checkCounts =
                await ApiService.checkInstagramCounts(accessToken);

            _safeSetState(() {
              // Use safeSetState - Update profile and counts early
              isInstagramConnected = true; // Assume connected for now
              instagramUserProfile = userProfile;
              isMoreThanCount = !checkCounts;
            });

            print("check counts");
            print(checkCounts);
            if (checkCounts) {
              // Counts OK (< 20k)
              bool unfollowstatus =
                  await ApiService.checkUnfollowStatus(accessToken);
              print("unfollow status :");
              print(unfollowstatus);
              if (unfollowstatus) {
                // Needs follower scan
                bool instagram_data_feched_saved =
                    await fetchAndSendfollowing_followers(
                        // Assume exists
                        accessToken,
                        userId,
                        sessionId,
                        csrftoken,
                        xIgAppId);
                print("fetchAndSendfollowing_followers");
                if (instagram_data_feched_saved) {
                  // ignore: unused_local_variable
                  bool changedlasttime = await ApiService.updateLastTimeFetched(
                      accessToken); // Update timestamp on SUCCESS
                  var response =
                      await ApiService.changeUnfollowStatus(accessToken, false);
                  print(response);
                  await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                  // No need to update first time flag here usually
                  // bool flagUpdated = await FirstTimeFlagService.postFirstTimeFlag(accessToken, false);

                  _safeSetState(() {
                    // Use safeSetState
                    instagramData = data;
                    // isMoreThanCount already set
                    isLoading = false;
                    isFirstTimeUser = false; // Successfully reconnected
                    errorMessage = ""; // Clear error
                  });
                  await _saveStateToPrefs(); // ADDED Save State
                  print("Full reconnect successful with follower data.");
                } else {
                  // Failed follower scan
                  // Don't update last fetched time
                  // ignore: unused_local_variable
                  // bool flagUpdated = await FirstTimeFlagService.postFirstTimeFlag(accessToken, true); // Maybe revert flag?

                  _safeSetState(() {
                    // Use safeSetState
                    isLoading = false;
                    // isInstagramConnected = false; // Keep connected or disconnect? Keep seems better.
                    // isFirstTimeUser = true; // Revert flag? Or just show error?
                    // isMoreThanCount already set
                    errorMessage =
                        "Failed to fetch follower/following data on reconnect.";
                  });
                  await _saveStateToPrefs(); // ADDED Save State
                }
              } else {
                // Unfollow status false (no scan needed)
                // ignore: unused_local_variable
                bool changedlasttime = await ApiService.updateLastTimeFetched(
                    accessToken); // Update timestamp (profile/counts checked)
                // Unfollow status false
                await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                _safeSetState(() {
                  // Use safeSetState
                  // isMoreThanCount already set
                  isLoading = false;
                  errorMessage = ""; // Clear error
                });
                await _saveStateToPrefs(); // ADDED Save State
                print("Full reconnect successful (no follower scan needed).");
              }
            } else {
              // Counts NOT OK (> 20k)
              // ignore: unused_local_variable
              bool changedlasttime = await ApiService.updateLastTimeFetched(
                  accessToken); // Update timestamp (profile/counts checked)
              // Counts NOT OK (> 20k)
              await _fetchStatsAndUpdateState(accessToken); // Fetch stats
              _safeSetState(() {
                // Use safeSetState
                isLoading = false;
                // isMoreThanCount already set
                errorMessage =
                    "Account follower/following count exceeds limits.";
              });
              await _saveStateToPrefs(); // ADDED Save State
              print("Full reconnect successful (counts exceed limit).");
            }
          } else {
            // UserInfoSave failed on reconnect
            _safeSetState(() {
              // Use safeSetState
              isLoading = false;
              isInstagramConnected = false; // Disconnect if core info fails
              errorMessage =
                  "Failed to refresh user info. Please log in again.";
              instagramUserProfile = null;
              instagramStats = null;
            });
            await _saveStateToPrefs(); // ADDED Save State
          }
        } else {
          // Less than 12 hours - Original logic from this branch
          final userProfile =
              await ApiService.fetchInstagramUserProfile(accessToken);
          bool checkCounts = await ApiService.checkInstagramCounts(accessToken);
          await _fetchStatsAndUpdateState(accessToken); // Fetch stats
          _safeSetState(() {
            // Use safeSetState
            instagramUserProfile = userProfile;
            isInstagramConnected = true;
            isLoading = false;
            isMoreThanCount = !checkCounts;
            errorMessage = ""; // Clear error
          });
          await _saveStateToPrefs(); // ADDED Save State
          print("Quick reconnect (<12h) successful.");
        }
      } else {
        // Status check failed
        _safeSetState(() {
          // Use safeSetState
          isInstagramConnected = false;
          isLoading = false;
          isFirstTimeUser = true; // Assume needs full login if status fails
          errorMessage = "Instagram connection check failed.";
          instagramUserProfile = null;
          instagramStats = null;
        });
        await _saveStateToPrefs(); // ADDED Save State
        print("Instagram status check failed.");
      }
    } else {
      // No access token
      _safeSetState(() {
        // Use safeSetState
        isLoading = false;
        isInstagramConnected = false;
        errorMessage = "No access token found. Please log in.";
        isFirstTimeUser = true; // Needs login
      });
      await _saveStateToPrefs(); // ADDED Save State
      print("No access token found in secure storage.");
    }
  }

  @override
  void initState() {
    super.initState();
    _profileAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    // Call _initializeApp directly as in original code
    _initializeApp();
  }

  // --- MODIFIED _initializeApp ---
  Future<void> _initializeApp() async {
    // 1. Set loading initially
    _safeSetState(() {
      // Use safeSetState
      // Set isLoading true only if not already loading? Or always? Original sets it.
      isLoading = true;
    });

    // 2. Load the last known state from SharedPreferences FIRST
    await _loadStateFromPrefs();
    // UI state variables are now populated with saved data

    // 3. Check for Access Token
    String? accessToken = await _secureStorage.read(key: 'access_token');

    if (accessToken != null) {
      // 4. Check if 12 hours have passed
      final bool lastfech = await ApiService.checkIf12HoursPassed(accessToken);

      if (lastfech) {
        // More than 12 hours - Run original refresh logic
        print("Initialization: More than 12 hours passed. Refreshing data...");
        // Original logic for > 12 hours
        await _checkFirstTimeFlag(accessToken); // Checks flag from server
        if (!isFirstTimeUser) {
          await _handleInstagramReconnection(); // This will fetch data and set isLoading=false
        } else {
          // Is first time according to server, stay disconnected, stop loading
          _safeSetState(() {
            // Use safeSetState
            isLoading = false;
            isInstagramConnected = false; // Ensure disconnected
            errorMessage = "Please log in to fetch initial data.";
          });
          await _saveStateToPrefs(); // Save this state
        }
        // Note: _handleInstagramReconnection handles setting isLoading = false internally
      } else {
        // Less than 12 hours - Use the loaded state
        print("Initialization: Less than 12 hours passed. Using loaded state.");
        // State was already loaded by _loadStateFromPrefs. Just stop loading indicator.
        _safeSetState(() {
          // Use safeSetState
          isLoading = false;
          // Ensure connection status reflects loaded state
          // isInstagramConnected = _prefs?.getBool(kPrefKeyIsConnected) ?? false; // Redundant check, loadStateFromPrefs did this
        });
        // No need to save prefs, nothing changed
      }
    } else {
      // No access token - Stop loading, show login prompt
      print("Initialization: No access token found.");
      _safeSetState(() {
        // Use safeSetState
        isLoading = false;
        isInstagramConnected = false;
        isFirstTimeUser = true; // Definitely needs login
        errorMessage = "Please log in.";
      });
      await _saveStateToPrefs(); // Save disconnected state
      return;
    }
  }

  @override
  void dispose() {
    /* ... Original Code ... */
    _profileAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    /* ... Original Code ... */
    super.didChangeDependencies();
  }

  // ========================================================================
  // --- UI Building Logic (UNCHANGED from your provided code) ---
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: kScaffoldBackgroundColor,
      appBar: AppBar(
        /* ... Original AppBar Code ... */
        backgroundColor: kScaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 16.0,
        title: Row(
          children: [
            const Icon(
                Icons
                    .insights, // Changed icon back as per previous request? Or keep original? Keep original install_mobile_sharp
                color: kPrimaryColor,
                size: 28),
            const SizedBox(width: 8),
            const Text(
              "InstaTracker",
              style: TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Original condition: Show status if NOT loading OR if connected
          // This might flash 'Disconnected' during initial load before connection status is known
          // A better condition might be simply 'if (!isLoading)'
          if (!isLoading) // Simplified condition: Only show when not loading
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isInstagramConnected
                        ? kConnectedColor.withOpacity(0.1)
                        : kErrorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: isInstagramConnected
                            ? kConnectedColor
                            : kErrorColor,
                        size: 10,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isInstagramConnected ? "Connected" : "Disconnected",
                        style: TextStyle(
                          color: isInstagramConnected
                              ? kConnectedColor
                              : kErrorColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimaryColor));
    }

    if (!isInstagramConnected) {
      // --- Not Connected / First Time User View ---
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded,
                  size: 60, color: kSecondaryTextColor),
              const SizedBox(height: 20),
              const Text(
                "Connect Your Instagram",
                style: kTitleTextStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Log in to track your account activity and insights.",
                style: kSubtitleTextStyle,
                textAlign: TextAlign.center,
              ),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: kErrorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleInstagramLoginAndCheckFirstTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.login),
                label: const Text("Login with Instagram"),
              ),
            ],
          ),
        ),
      );
    }

    // Connected States
    if (isMoreThanCount) {
      // --- > 20k view ---
      return Center(
        // Keep original Center wrap
        child: Padding(
          // Keep original Padding
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            // ADDED SingleChildScrollView for safety
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildUserProfile(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    // Use specific error if available and relevant, else generic
                    errorMessage.isNotEmpty &&
                            (errorMessage.contains("exceeds limits") ||
                                errorMessage.contains("limit detailed"))
                        ? errorMessage
                        : "This account's follower or following count may limit detailed tracking features.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange[800], fontSize: 14),
                  ),
                ),
                // Show other errors IF they exist AND are not the count limit message
                if (errorMessage.isNotEmpty &&
                    !errorMessage.contains("exceeds limits") &&
                    !errorMessage.contains("limit detailed"))
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(color: kErrorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed:
                      _handleInstagramLoginAndCheckFirstTime, // Still allow re-login
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  icon: const Icon(Icons.sync_alt),
                  label: const Text("Connect Different Account"),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // --- < 20k view (Main Dashboard) ---
      return SingleChildScrollView(
        // Ensures scrollability
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 8.0), // Overall vertical padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserProfile(), // New profile widget
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    // Optional styling for error
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: kErrorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                          color: kErrorColor, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              // --- Reduced top padding ---
              Padding(
                padding: const EdgeInsets.only(
                    left: 16.0,
                    top: 16.0,
                    bottom: 6.0,
                    right: 16.0), // Adjusted top padding
                child: Text(
                  "Tracking Tools",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                    // Adjusted padding
                    left: 16.0,
                    right: 16.0,
                    top: 10.0,
                    bottom: 10.0),
                child: _buildProfileCheckerCard(
                  imagePath:
                      'assets/icons/search.png', // Ensure path is correct
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SearchSomeoneScreen()));
                  },
                ),
              ), // End Profile Checker Padding

              Padding(
                // Adjusted padding
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 10.0, bottom: 16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05, // Keep aspect ratio
                  children: [
                    // --- Original Calls using imagePath ---
                    _buildTrackingToolCard(
                      imagePath:
                          'assets/icons/unfollow.png', // Ensure path is correct
                      backgroundColor: kPinkIconBg,
                      title: 'Who unfollowed you',
                      count: instagramStats?['unfollowed_you_count'] ?? 0,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => UnfollowedYouScreen()));
                      },
                    ),
                    _buildTrackingToolCard(
                      imagePath:
                          'assets/icons/remove_user.png', // Use different icon if available
                      /* <-- Replace this path */ backgroundColor:
                          kOrangeIconBg,
                      title: 'Who removed you',
                      count: instagramStats?['removed_following_count'] ?? 0,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => WhoRemovedYouScreen()));
                      },
                    ),
                    _buildTrackingToolCard(
                      imagePath:
                          'assets/icons/not_following_you.png', // Ensure path is correct
                      backgroundColor: kPurpleIconBg,
                      title: 'Not following you back',
                      count: instagramStats?['dont_follow_back_count'] ?? 0,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    FollowedButNotFollowedBackScreen()));
                      },
                    ),
                    _buildTrackingToolCard(
                      imagePath:
                          'assets/icons/not_following.png', // Ensure path is correct
                      backgroundColor: kBlueIconBg,
                      title: "You're not following",
                      count: instagramStats?['you_dont_follow_back_count'] ?? 0,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    NotFollowedButFollowingMeScreen()));
                      },
                    ),
                  ],
                ),
              ), // End GridView Padding
              const SizedBox(height: 16), // Add bottom spacing
            ],
          ),
        ),
      ); // End SingleChildScrollView
    }
  }

  Widget _buildUserProfile() {
    // Keep original logic, just call the content builder
    return _buildProfileContent();
  }

  Widget _buildProfileContent() {
    // Original placeholder logic
    if (instagramUserProfile == null && isInstagramConnected) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: kCardBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15), // Adjusted shadow
                  spreadRadius: 1,
                  blurRadius: 8, // Adjusted blur
                  offset: const Offset(0, 4), // Adjusted offset
                ),
              ],
            ),
            child: const Center(
                child: Row(
                    // Added indicator to placeholder
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimaryColor)),
                  SizedBox(width: 10),
                  Text("Loading profile data...", style: kSubtitleTextStyle),
                ])),
          ));
    }
    // Original null check
    if (instagramUserProfile == null) {
      return const SizedBox.shrink();
    }
    // Original data extraction
    final userData =
        instagramUserProfile!['user_data'] as Map<String, dynamic>?;
    if (userData == null) {
      // Keep original error handling
      _safeSetState(() {
        errorMessage = "Error: User data format incorrect.";
      });
      return const Center(
          child: Text("Error: User data format incorrect.",
              style: TextStyle(color: kErrorColor)));
    }
    final profilePictureUrl =
        userData['instagram_profile_picture_url'] as String?;
    final username = userData['instagram_username'] as String? ?? 'username';
    final followerCount = userData['instagram_follower_count'] as int? ?? 0;
    final followingCount = userData['instagram_following_count'] as int? ?? 0;
    final totalPosts = userData['instagram_total_posts'] as int? ?? 0;

    // Original stats extraction (handle null instagramStats)
    final int newFollowers =
        instagramStats?['follower_difference'] as int? ?? 0;
    final int followingDifference =
        instagramStats?['following_difference'] as int? ??
            0; // Renamed from 'Removed' logic

    // Original Profile Card Structure
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: kCardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              // Keep original shadow values
              color: Colors.grey.withOpacity(0.15), // Adjusted shadow
              spreadRadius: 1,
              blurRadius: 8, // Adjusted blur
              offset: const Offset(0, 4), // Adjusted offset
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  // Added basic URL validation
                  backgroundImage: (profilePictureUrl != null &&
                          profilePictureUrl.isNotEmpty &&
                          Uri.tryParse(profilePictureUrl)?.hasAbsolutePath ==
                              true)
                      ? NetworkImage(profilePictureUrl)
                      : const AssetImage(
                              'assets/placeholder_avatar.png') // Ensure placeholder exists
                          as ImageProvider,
                  radius: 35,
                  backgroundColor: Colors.grey[200],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "@$username",
                        style: kTitleTextStyle.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        // Use Wrap instead of Row for flexibility
                        spacing: 16,
                        runSpacing: 4,
                        children: [
                          Text(
                            "${_formatCount(followerCount)} followers",
                            style: kSubtitleTextStyle.copyWith(fontSize: 14),
                          ),
                          //const SizedBox(width: 16), // No SizedBox needed with Wrap spacing
                          Text(
                            "${_formatCount(followingCount)} following",
                            style: kSubtitleTextStyle.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(
                height: 1, thickness: 0.5, color: kScaffoldBackgroundColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProfileStatColumn(
                  _formatCount(totalPosts),
                  "Posts",
                ),
                _buildProfileStatColumn(
                    "${newFollowers >= 0 ? '+' : ''}$newFollowers",
                    "New Followers",
                    color: newFollowers == 0
                        ? kTextColor
                        : (newFollowers > 0 ? kConnectedColor : kErrorColor)),
                _buildProfileStatColumn(
                    // Original logic for 'Removed' seemed tied to followingDifference?
                    // Clarified Label and logic: Shows change in *your* following count
                    "${followingDifference >= 0 ? '+' : ''}$followingDifference",
                    "Following +/-", // More accurate label
                    color: followingDifference == 0
                        ? kTextColor // Neutral
                        : (followingDifference > 0
                            ? kErrorColor
                            : kConnectedColor)), // Red if you followed more, Green if you followed fewer
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to format large numbers (UNCHANGED)
  String _formatCount(int count) {
    /* ... same as before ... */ if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      double kValue = count / 1000;
      return '${kValue.toStringAsFixed(kValue.truncateToDouble() == kValue ? 0 : 1)}K';
    } else {
      return count.toString();
    }
  }

  // Stat Column widget for the Profile Card (UNCHANGED)
  Widget _buildProfileStatColumn(String value, String label, {Color? color}) {
    /* ... same as before ... */ return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: kStatsNumberStyle.copyWith(color: color ?? kTextColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: kStatsLabelStyle,
        ),
      ],
    );
  }

  // --- Card widget for Tracking Tools - CENTERED ICON --- (UNCHANGED)
  Widget _buildTrackingToolCard({
    required String imagePath,
    required Color backgroundColor,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    final String countLabel = count == 1 ? 'account' : 'accounts';
    Color countColor; // Determine color based on background
    switch (backgroundColor) {
      case kPinkIconBg:
        countColor = kPinkIcon;
        break;
      case kOrangeIconBg:
        countColor = kOrangeIcon;
        break;
      case kPurpleIconBg:
        countColor = kPurpleIcon;
        break;
      case kBlueIconBg:
        countColor = kBlueIcon;
        break;
      default:
        countColor = kSecondaryTextColor;
    }

    return Card(
      elevation: 3, // Adjusted elevation
      shadowColor: Colors.grey.withOpacity(0.15), // Adjusted shadow
      color: kCardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    imagePath,
                    width: 32,
                    height: 32,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.error_outline,
                        color: kErrorColor,
                        size: 32), // Added error builder
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: kCardTitleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "$count $countLabel",
                    style: TextStyle(
                      fontSize: 14,
                      color: countColor, // Use determined color
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: kSecondaryTextColor, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Card widget for the Profile Checker - ICON STAYS LEFT ALIGNED (ROW) --- (UNCHANGED)
  Widget _buildProfileCheckerCard({
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            // Keep original gradient
            colors: [
              kOrangeIconBg, // Use defined colors
              kOrangeIcon,
              // Color(0xFFFFD700), // Light gold
              // Color(0xFFFFC300), // Deeper gold
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15), // Adjusted shadow
              blurRadius: 5,
              offset: const Offset(0, 3), // Adjusted offset
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 12.0), // Adjusted padding
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: kTealIconBg, // Keep original icon background
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                imagePath,
                width: 30, // Adjusted size
                height: 30, // Adjusted size
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.search,
                    color: kTextColor,
                    size: 30), // Added error builder
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Profile Checker",
                    style: kCardTitleStyle.copyWith(
                        color: kTextColor), // Adjusted color
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check other profiles' activity",
                    style: kSubtitleTextStyle.copyWith(
                      fontSize: 13,
                      color: kTextColor.withOpacity(0.8), // Adjusted color
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: kTextColor.withOpacity(0.8),
                size: 24), // Adjusted color & size
          ],
        ),
      ),
    );
  }
} // End of _HomePageState
