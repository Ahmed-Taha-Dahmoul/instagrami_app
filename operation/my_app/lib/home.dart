import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'instagram_login.dart';
import 'api_service.dart';
import 'instagram_service.dart';
import 'first_time_flag_service.dart';
import 'who_unfollowed_you.dart';
import 'followed_but_not_followed_back.dart';
import 'not_followed_but_following_me.dart';
import 'search_someone_screen.dart';
import 'who_removed_you.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin { // Add AutomaticKeepAliveClientMixin

  bool isInstagramConnected = false;
  var instagramData;
  bool isLoading = false;
  bool isMoreThanCount = false;
  bool isFirstTimeUser = false;
  Map<String, dynamic>? instagramUserProfile;
  String errorMessage = "";
  late AnimationController _profileAnimationController;
  late final Animation<double> _profileScaleAnimation;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

   @override
  bool get wantKeepAlive => true; // VERY IMPORTANT: Keep state alive

  Future<void> _checkFirstTimeFlag(String token) async {
    bool firstTimeFlag = await FirstTimeFlagService.fetchFirstTimeFlag(token);
    setState(() {
      isFirstTimeUser = firstTimeFlag;
    });
  }

  Future<void> _handleInstagramLoginAndCheckFirstTime() async {
    setState(() {
      isLoading = true;
    });

    String? accessToken = await _secureStorage.read(key: 'access_token');

    if (accessToken != null) {

      bool success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InstagramLogin()),
      );

      if (success) {
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
            bool checkCounts = await ApiService.checkInstagramCounts(accessToken);

            setState(() {
              isInstagramConnected = true;
              instagramUserProfile = userProfile;
            });

            if (checkCounts) {
              bool instagram_data_feched_saved =
                  await fetchAndSendfollowing_followers(
                      accessToken, userId, sessionId, csrftoken, xIgAppId);
              if (instagram_data_feched_saved) {
                // ignore: unused_local_variable
                var response = await ApiService.changeUnfollowStatus(accessToken, false);
                bool flagUpdated =
                    await FirstTimeFlagService.postFirstTimeFlag(accessToken, false);
                if (flagUpdated) {
                  setState(() {
                    instagramData = data;
                    isInstagramConnected = true;
                    isMoreThanCount = checkCounts;
                    isLoading = false;
                    isFirstTimeUser = false;
                  });
                  print("First-time flag updated successfully.");
                } else {
                  setState(() {
                    isLoading = false;
                    errorMessage = "Failed to update first-time flag.";
                  });
                  print("Failed to update first-time flag.");
                }
                print("Instagram user info saved, profile fetched, counts checked, and data sent if required.");
              } else {
                setState(() {

                  isLoading = false;
                });
              }
            } else {
                setState(() { //here
                  isLoading = false;
                  isMoreThanCount = checkCounts;
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
      });
    }


    } else {
      setState(() {
        isLoading = false;
        isInstagramConnected = false;
        errorMessage = "No access token found in secure storage.";
      });
      print("No access token found in secure storage.");
    }
  }

  Future<void> _handleInstagramReconnection() async {
    setState(() {
      isLoading = true;
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
        await _secureStorage.write(
            key: 'csrftoken', value: data['csrftoken']);
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
            print(userInfoSaved);
            final userProfile =
                await ApiService.fetchInstagramUserProfile(accessToken);

            setState(() {
              isInstagramConnected = true;
              instagramUserProfile = userProfile;
            });
            bool checkCounts = await ApiService.checkInstagramCounts(accessToken);


            if (checkCounts) {

              bool unfollowstatus = await ApiService.checkUnfollowStatus(accessToken);

              // ignore: unused_local_variable
              bool updatelasttime = await ApiService.updateLastTimeFetched(accessToken);
              print(unfollowstatus);
              if (unfollowstatus) {
                  bool instagram_data_feched_saved =
                      await fetchAndSendfollowing_followers(
                          accessToken, userId, sessionId, csrftoken, xIgAppId);
                  if (instagram_data_feched_saved) {
                    var response = await ApiService.changeUnfollowStatus(accessToken, false);
                    print(response);
                    bool flagUpdated = await FirstTimeFlagService.postFirstTimeFlag(
                        accessToken, false);
                    if (flagUpdated) {
                      setState(() {
                        instagramData = data;
                        isInstagramConnected = true;
                        isMoreThanCount = checkCounts;
                        isLoading = false;
                        isFirstTimeUser = false;
                        instagramUserProfile = userProfile;

                      });
                      print("First-time flag updated successfully.");
                    } else {
                      setState(() {
                        isInstagramConnected = false;
                        isLoading = false;
                        errorMessage = "Failed to update first-time flag.";
                        isMoreThanCount = checkCounts;
                      });
                      print("Failed to update first-time flag.");
                    }
                    print("Instagram user info saved, profile fetched, counts checked, and data sent if required.");
                  }else {
                  setState(() {
                    isInstagramConnected = false;
                    isLoading = false;
                    isMoreThanCount = checkCounts;
                  });
                }
              }else {
                isLoading = false;
                isMoreThanCount = checkCounts;
              }

            }else {
              setState(() {

                isLoading = false;
                isMoreThanCount = checkCounts;//here
              });
            }
          }else {
            setState(() {
                isLoading = false;
              });
          }
        } else {
          final userProfile =
              await ApiService.fetchInstagramUserProfile(accessToken);
          bool checkCounts = await ApiService.checkInstagramCounts(accessToken); //here
          setState(() {
            instagramUserProfile = userProfile;
            isInstagramConnected = true;
            isLoading = false;
            isMoreThanCount = checkCounts; // And here
          });
        }
      } else {
        setState(() {
          isInstagramConnected = false;
          isLoading = false;
          isFirstTimeUser = true;
        });
        print("Instagram status check failed.");
      }
    } else {
      setState(() {
        isLoading = false;
        isInstagramConnected = false;
      });
      print("No access token found in secure storage.");
    }
  }

  @override
void initState() {
  super.initState();
  _initializeApp();

  _profileAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _profileScaleAnimation = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(
      parent: _profileAnimationController,
      curve: Curves.easeInOut,
    ));
}

Future<void> _initializeApp() async {
  setState(() {
    isLoading = true; // Show the loading indicator while checking the token.
  });

  String? accessToken = await _secureStorage.read(key: 'access_token');
  if (accessToken != null) {
    await _checkFirstTimeFlag(accessToken);
    if (!isFirstTimeUser) {
      await _handleInstagramReconnection();
    }
  } else {
    setState(() {
      isLoading = false; // Stop loading when token check is complete.
    });
    return; // Exit early if no access token found.
  }

  setState(() {
    isLoading = false; // Stop loading after completing all checks.
  });
}

@override
void dispose() {
  _profileAnimationController.dispose();
  super.dispose();
}
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
      // No need to call _initializeApp here anymore
  }
  @override
  Widget build(BuildContext context) {
    super.build(context); //  Important for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                Text(
                  "Instagram account: ",
                  style: TextStyle(
                    color: isInstagramConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  isInstagramConnected ? Icons.check_circle : Icons.cancel,
                  color: isInstagramConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }


Widget _buildBody() {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator()); // Show loading while checking token.
  }

  if (isInstagramConnected) {
    // Instagram is connected
    if (isMoreThanCount) {
      // Connected and the account has less than 20k followers/following
      return Column(
        children: [
          _buildUserProfile(),
          const SizedBox(height: 20),
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 25,
                crossAxisSpacing: 25,
                primary: false,
                children: [
                  _buildCard(
                    'assets/icons/unfollow.png',
                    'Who Unfollowed You',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => UnfollowedYouScreen()),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/unfollow.png',
                    'Who Removed You',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => WhoRemovedYouScreen()),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/not_following_you.png',
                    'Who is not following you back',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                               FollowedButNotFollowedBackScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/not_following.png',
                    'Who you are not following',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                               NotFollowedButFollowingMeScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    'assets/icons/search.png',
                    'View Recent Follows & Followers of someone ',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const SearchSomeoneScreen(),
                        ),
                      );
                    },
                  ),


                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Account connected but has more than 20k followers/following
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Wrap in Container for styling
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              "The account you tried to connect has more than 20k followers and following. Try to connect with another account.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _buildUserProfile(),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _handleInstagramLoginAndCheckFirstTime,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 73, 200, 209),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 2,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            icon: const Icon(Icons.login), // Add a login icon
            label: const Text("Login with Instagram"),
          ),
        ],
      );
    }
  } else {
    // Not connected: Show ONLY login button and error message
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            onPressed: _handleInstagramLoginAndCheckFirstTime,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              elevation: 2,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text("Login with Instagram"),
          ),
        ],
      ),
    );
  }
}

Widget _buildUserProfile() {
  if (instagramUserProfile == null) {
    return const CircularProgressIndicator();
  }

  final userData = instagramUserProfile!['user_data'] as Map<String, dynamic>?;

  if (userData == null) {
    return const Text("Error: User data not found.");
  }

  final profilePictureUrl = userData['instagram_profile_picture_url'] as String?;
  final username = userData['instagram_username'] as String? ?? 'No Username';
  final fullName = userData['instagram_full_name'] as String? ?? 'No Name';
  final totalPosts = userData['instagram_total_posts'] as int? ?? 0;
  final followerCount = userData['instagram_follower_count'] as int? ?? 0;
  final followingCount = userData['instagram_following_count'] as int? ?? 0;

  return ScaleTransition(
    scale: _profileScaleAnimation,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: profilePictureUrl != null
                  ? NetworkImage(profilePictureUrl)
                  : null,
              radius: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "@$username",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fullName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(totalPosts, "posts"),
                      _buildStatColumn(followerCount, "followers"),
                      _buildStatColumn(followingCount, "following"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildStatColumn(int value, String label) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value.toString(),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    ],
  );
}

Widget _buildCard(String imagePath, String title, VoidCallback onTap) {
  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 4,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(imagePath, width: 64, height: 64),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}

}