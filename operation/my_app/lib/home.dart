import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  bool isFirstTimeUser = false;
  Map<String, dynamic>? instagramUserProfile;
  String errorMessage = "";
  late AnimationController _profileAnimationController;

  // --- ADDED State variable for new UI ---
  Map<String, dynamic>? instagramStats;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  bool get wantKeepAlive => true;

  // Helper to safely update state only if the widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // --- Function to fetch stats (called from original logic below) ---
  Future<void> _fetchStatsAndUpdateState(String accessToken) async {
    final result = await ApiService.fetchInstagramStatsDifference(accessToken);
    _safeSetState(() {
      if (!result.containsKey('error')) {
        instagramStats = result;
      } else {
        instagramStats = null; // Clear stats on error
        print("Error fetching stats: ${result['error']}");
      }
    });
  }

  // ========================================================================
  // --- YOUR ORIGINAL LOGIC METHODS (EXACTLY AS PROVIDED previously) ---
  // ========================================================================
  Future<void> _checkFirstTimeFlag(String token) async {
    /* ... Original Code ... */
    bool firstTimeFlag = await FirstTimeFlagService.fetchFirstTimeFlag(token);
    setState(() {
      isFirstTimeUser = firstTimeFlag;
    });
  }

  Future<void> _handleInstagramLoginAndCheckFirstTime() async {
    /* ... Original Code ... */
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    String? accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      dynamic success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InstagramLogin()),
      );
      if (success == true) {
        bool status = await ApiService.checkInstagramStatus(accessToken);
        if (status) {
          final data = await ApiService.getInstagramData(accessToken);
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
            setState(() {
              isInstagramConnected = true;
              instagramUserProfile = userProfile;
            });
            if (checkCounts) {
              // Counts OK (< 20k)
              bool instagram_data_feched_saved =
                  await fetchAndSendfollowing_followers(
                      accessToken, userId, sessionId, csrftoken, xIgAppId);
              if (instagram_data_feched_saved) {
                // ignore: unused_local_variable
                var response =
                    await ApiService.changeUnfollowStatus(accessToken, false);
                await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                bool flagUpdated = await FirstTimeFlagService.postFirstTimeFlag(
                    accessToken, false);
                if (flagUpdated) {
                  setState(() {
                    instagramData = data;
                    isMoreThanCount = !checkCounts;
                    isLoading = false;
                    isFirstTimeUser = false;
                    errorMessage = "";
                  });
                  print("First-time flag updated successfully.");
                } else {
                  setState(() {
                    isLoading = false;
                    errorMessage = "Failed to update first-time flag.";
                    isMoreThanCount = !checkCounts;
                  });
                  print("Failed to update first-time flag.");
                }
                print(
                    "Instagram user info saved, profile fetched, counts checked, and data sent if required.");
              } else {
                setState(() {
                  isLoading = false;
                  isMoreThanCount = !checkCounts;
                  errorMessage = "Failed to fetch follower/following data.";
                });
              }
            } else {
              // Counts NOT OK (> 20k)
              await _fetchStatsAndUpdateState(accessToken); // Fetch stats
              setState(() {
                isLoading = false;
                isMoreThanCount = !checkCounts;
                errorMessage =
                    "Account follower/following count exceeds limits.";
              });
            }
          } else {
            setState(() {
              isInstagramConnected = false;
              isLoading = false;
              errorMessage = "Failed to save Instagram user info.";
            });
            print("Failed to save Instagram user info.");
          }
        } else {
          setState(() {
            isInstagramConnected = false;
            isLoading = false;
            errorMessage = "Failed to check Instagram Status.";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Login cancelled or failed.";
        });
      }
    } else {
      setState(() {
        isLoading = false;
        isInstagramConnected = false;
        errorMessage = "No access token found. Please log in.";
      });
      print("No access token found in secure storage.");
    }
  }

  Future<void> _handleInstagramReconnection() async {
    /* ... Original Code ... */
    setState(() {
      isLoading = true;
      errorMessage = "";
    });
    String? accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      bool status = await ApiService.checkInstagramStatus(accessToken);
      if (status) {
        final data = await ApiService.getInstagramData(accessToken);
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
          print("requesting to the instagram to get the profile ");
          bool userInfoSaved = await ApiService.getInstagramUserInfoAndSave(
              userId, csrftoken, sessionId, xIgAppId, accessToken);
          if (userInfoSaved) {
            print("success feching user profile from instagram");
            final userProfile =
                await ApiService.fetchInstagramUserProfile(accessToken);
            setState(() {
              isInstagramConnected = true;
              instagramUserProfile = userProfile;
            });
            bool checkCounts =
                await ApiService.checkInstagramCounts(accessToken);
            print("check counts");
            print(checkCounts);
            if (checkCounts) {
              // Counts OK (< 20k)
              bool unfollowstatus =
                  await ApiService.checkUnfollowStatus(accessToken);
              print("unfollow status :");
              print(unfollowstatus);
              if (unfollowstatus) {
                bool instagram_data_feched_saved =
                    await fetchAndSendfollowing_followers(
                        accessToken, userId, sessionId, csrftoken, xIgAppId);
                print("fetchAndSendfollowing_followers");
                if (instagram_data_feched_saved) {
                  // ignore: unused_local_variable
                  bool changedlasttime =
                      await ApiService.updateLastTimeFetched(accessToken);
                  var response =
                      await ApiService.changeUnfollowStatus(accessToken, false);
                  print(response);
                  await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                  bool flagUpdated =
                      await FirstTimeFlagService.postFirstTimeFlag(
                          accessToken, false);
                  if (flagUpdated) {
                    setState(() {
                      instagramData = data;
                      isMoreThanCount = !checkCounts;
                      isLoading = false;
                      isFirstTimeUser = false;
                      errorMessage = "";
                    });
                    print("First-time flag updated successfully.");
                  } else {
                    setState(() {
                      isLoading = false;
                      errorMessage = "Failed to update first-time flag.";
                      isMoreThanCount = !checkCounts;
                    });
                    print("Failed to update first-time flag.");
                  }
                  print(
                      "Instagram user info saved, profile fetched, counts checked, and data sent if required.");
                } else {
                  // ignore: unused_local_variable
                  bool flagUpdated =
                      await FirstTimeFlagService.postFirstTimeFlag(
                          accessToken, true);
                  setState(() {
                    isLoading = false;
                    isFirstTimeUser = true;
                    isInstagramConnected = false;
                    isMoreThanCount = !checkCounts;
                    errorMessage =
                        "Failed to fetch follower/following data on reconnect.";
                  });
                }
              } else {
                // ignore: unused_local_variable
                bool changedlasttime =
                    await ApiService.updateLastTimeFetched(accessToken);
                // Unfollow status false
                await _fetchStatsAndUpdateState(accessToken); // Fetch stats
                setState(() {
                  isLoading = false;
                  isMoreThanCount = !checkCounts;
                  errorMessage = "";
                });
              }
            } else {
              // ignore: unused_local_variable
              bool changedlasttime =
                  await ApiService.updateLastTimeFetched(accessToken);
              // Counts NOT OK (> 20k)
              await _fetchStatsAndUpdateState(accessToken); // Fetch stats
              setState(() {
                isLoading = false;
                isMoreThanCount = !checkCounts;
                errorMessage =
                    "Account follower/following count exceeds limits.";
              });
            }
          } else {
            setState(() {
              isLoading = false;
              errorMessage =
                  "Failed to refresh user info. Data might be outdated.";
            });
          }
        } else {
          // Less than 12 hours
          final userProfile =
              await ApiService.fetchInstagramUserProfile(accessToken);
          bool checkCounts = await ApiService.checkInstagramCounts(accessToken);
          await _fetchStatsAndUpdateState(accessToken); // Fetch stats
          setState(() {
            instagramUserProfile = userProfile;
            isInstagramConnected = true;
            isLoading = false;
            isMoreThanCount = !checkCounts;
            errorMessage = "";
          });
        }
      } else {
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
          isFirstTimeUser = true;
          errorMessage = "Instagram connection check failed.";
          instagramUserProfile = null;
          instagramStats = null;
        });
        print("Instagram status check failed.");
      }
    } else {
      setState(() {
        isLoading = false;
        isInstagramConnected = false;
        errorMessage = "No access token found. Please log in.";
      });
      print("No access token found in secure storage.");
    }
  }

  @override
  void initState() {
    /* ... Original Code ... */
    super.initState();
    _initializeApp();
    _profileAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    /* ... Original Code ... */
    setState(() {
      isLoading = true;
    });
    String? accessToken = await _secureStorage.read(key: 'access_token');
    if (accessToken != null) {
      await _checkFirstTimeFlag(accessToken);
      if (!isFirstTimeUser) {
        await _handleInstagramReconnection();
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: kScaffoldBackgroundColor,
      appBar: AppBar(
        /* ... New AppBar Code ... */
        backgroundColor: kScaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 16.0,
        title: Row(
          children: [
            const Icon(Icons.install_mobile_sharp,
                color: kPrimaryColor, size: 28),
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
          if (!isLoading || isInstagramConnected)
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                  "This account's follower or following count may limit detailed tracking features.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange[800], fontSize: 14),
                ),
              ),
              if (errorMessage.isNotEmpty &&
                  !errorMessage.contains("exceeds limits"))
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
                onPressed: _handleInstagramLoginAndCheckFirstTime,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                icon: const Icon(Icons.sync_alt),
                label: const Text("Connect Different Account"),
              ),
            ],
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
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: kErrorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              // --- Reduced top padding ---
              Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, top: 5.0, bottom: 6.0, right: 16.0),
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
                    left: 16.0, right: 16.0, top: 16.0, bottom: 16.0),
                child: _buildProfileCheckerCard(
                  imagePath: 'assets/icons/search.png',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SearchSomeoneScreen()));
                  },
                ),
              ), // End Profile Checker Padding
              // --- Reduced bottom padding ---
              const SizedBox(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05, // Keep aspect ratio
                  children: [
                    // --- UPDATED Calls using imagePath ---
                    _buildTrackingToolCard(
                      imagePath: 'assets/icons/unfollow.png',
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
                      imagePath: 'assets/icons/unfollow.png',
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
                      imagePath: 'assets/icons/not_following_you.png',
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
                      imagePath: 'assets/icons/not_following.png',
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
            ],
          ),
        ),
      ); // End SingleChildScrollView
    }
  }

  Widget _buildUserProfile() {
    return _buildProfileContent();
  }

  Widget _buildProfileContent() {
    if (instagramUserProfile == null && isInstagramConnected) {
      /* ... Placeholder ... */ return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: kCardBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.25),
                  /* <-- More shadow */ spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Center(
                child:
                    Text("Loading profile data...", style: kSubtitleTextStyle)),
          ));
    }
    if (instagramUserProfile == null) {
      return const SizedBox.shrink();
    }
    final userData =
        instagramUserProfile!['user_data'] as Map<String, dynamic>?;
    if (userData == null) {
      return const Center(child: Text("Error: User data format incorrect."));
    }
    final profilePictureUrl =
        userData['instagram_profile_picture_url'] as String?;
    final username = userData['instagram_username'] as String? ?? 'username';
    final followerCount = userData['instagram_follower_count'] as int? ?? 0;
    final followingCount = userData['instagram_following_count'] as int? ?? 0;
    final totalPosts = userData['instagram_total_posts'] as int? ?? 0;
    final int newFollowers = instagramStats?['follower_difference'] ?? 0;
    final int followingDifference =
        instagramStats?['following_difference'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        // Profile Card Container
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: kCardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            // --- Enhanced Shadow for Profile Card ---
            BoxShadow(
              color: Colors.grey.withOpacity(0.25),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            /* ... Profile content columns/rows ... */
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: (profilePictureUrl != null &&
                          profilePictureUrl.isNotEmpty)
                      ? NetworkImage(profilePictureUrl)
                      : const AssetImage('assets/placeholder_avatar.png')
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
                      Row(
                        children: [
                          Text(
                            "${_formatCount(followerCount)} followers",
                            style: kSubtitleTextStyle.copyWith(fontSize: 14),
                          ),
                          const SizedBox(width: 16),
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
                    "${followingDifference > 0 ? '+' : ''}${followingDifference < 0 ? '' : ''}${followingDifference != 0 ? followingDifference : '0'}",
                    "Removed",
                    color: followingDifference == 0
                        ? kTextColor
                        : (followingDifference > 0
                            ? kConnectedColor
                            : kErrorColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to format large numbers
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

  // Stat Column widget for the Profile Card
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

  // --- Card widget for Tracking Tools - CENTERED ICON ---
  Widget _buildTrackingToolCard({
    required String imagePath,
    required Color backgroundColor,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    final String countLabel = count == 1 ? 'account' : 'accounts';
    return Card(
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.25),
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
            // Main layout column
            crossAxisAlignment:
                CrossAxisAlignment.start, // Keep text aligned left
            // mainAxisAlignment: MainAxisAlignment.start, // Let Spacer handle vertical space
            children: [
              // --- Wrap icon Container in Center for horizontal centering ---
              Center(
                child: Container(
                  // Icon Background Circle
                  padding: const EdgeInsets.all(10), // Padding inside circle
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    imagePath,
                    width: 32,
                    height: 32,
                  ), // Icon
                ),
              ),
              // --- End Center Wrap ---
              const Spacer(), // Pushes text content down
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
                      color: backgroundColor == kPinkIconBg
                          ? kPinkIcon
                          : backgroundColor == kOrangeIconBg
                              ? kOrangeIcon
                              : backgroundColor == kPurpleIconBg
                                  ? kPurpleIcon
                                  : backgroundColor == kBlueIconBg
                                      ? kBlueIcon
                                      : kSecondaryTextColor,
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

  // --- Card widget for the Profile Checker - ICON STAYS LEFT ALIGNED (ROW) ---
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
            colors: [
              Color(0xFFFFD700), // Light gold
              Color(0xFFFFC300), // Deeper gold
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.25),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: kTealIconBg,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                imagePath,
                width: 32,
                height: 32,
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
                    style: kCardTitleStyle.copyWith(color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Check other profiles' activity",
                    style: kSubtitleTextStyle.copyWith(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black87, size: 20),
          ],
        ),
      ),
    );
  }
} // End of _HomePageState
