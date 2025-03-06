import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'instagram_login.dart';
import 'api_service.dart';
import 'instagram_service.dart';
import 'first_time_flag_service.dart';
import 'who_unfollowed_you.dart';
import 'followed_but_not_followed_back.dart';
import 'not_followed_but_following_me.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool isInstagramConnected = false;
  var instagramData;
  bool isLoading = false;
  bool isMoreThanCount = false;
  bool isFirstTimeUser = false;
  Map<String, dynamic>? instagramUserProfile;
  String errorMessage = "";
  late AnimationController _profileAnimationController;
  late final Animation<double> _profileScaleAnimation;

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InstagramLogin()),
      );

      bool status = await ApiService.checkInstagramStatus(accessToken);
      if (status) {
        final data = await ApiService.getInstagramData(accessToken);

        String csrftoken = data['csrftoken'];
        String userId = data['user1_id'];
        String sessionId = data['session_id'];
        String xIgAppId = data['x_ig_app_id'];

        bool userInfoSaved = await ApiService.getInstagramUserInfoAndSave(
            userId, csrftoken, sessionId, xIgAppId, accessToken);

        if (userInfoSaved) {
          final userProfile =
              await ApiService.fetchInstagramUserProfile(accessToken);
          bool checkCounts = await ApiService.checkInstagramCounts(accessToken);

          if (checkCounts) {
            bool instagram_data_feched_saved =
                await fetchAndSendfollowing_followers(
                    accessToken, userId, sessionId, csrftoken, xIgAppId);
            if (instagram_data_feched_saved) {
              bool flagUpdated =
                  await FirstTimeFlagService.postFirstTimeFlag(accessToken, true);
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
                });
                print("Failed to update first-time flag.");
              }
              print("Instagram user info saved, profile fetched, counts checked, and data sent if required.");
            } else {
              setState(() {
                isInstagramConnected = false;
                isLoading = false;
              });
            }
          } else {
              setState(() { //here
                isInstagramConnected = false;
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

        final lastfech = await ApiService.checkIf12HoursPassed(accessToken);
        if (lastfech) {
          bool userInfoSaved = await ApiService.getInstagramUserInfoAndSave(
              userId, csrftoken, sessionId, xIgAppId, accessToken);

          if (userInfoSaved) {
            
            final userProfile =
                await ApiService.fetchInstagramUserProfile(accessToken);
            setState(() {
              isInstagramConnected = true;
              instagramUserProfile = userProfile;
            });
            bool checkCounts = await ApiService.checkInstagramCounts(accessToken);
            if (checkCounts) {
              bool instagram_data_feched_saved =
                  await fetchAndSendfollowing_followers(
                      accessToken, userId, sessionId, csrftoken, xIgAppId);
              if (instagram_data_feched_saved) {
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
                  });
                  print("Failed to update first-time flag.");
                }
                print("Instagram user info saved, profile fetched, counts checked, and data sent if required.");
              }else {
              setState(() {
                isInstagramConnected = false;
                isLoading = false;
              });
            }
            }else {
              setState(() {
                
                isLoading = false;
                isMoreThanCount = checkCounts;//here
              });
            }
          }else {
            setState(() {
                isInstagramConnected = false;
                isLoading = false;
              });
          }
        } else {
          final userProfile =
              await ApiService.fetchInstagramUserProfile(accessToken);
          bool checkCounts = await ApiService.checkInstagramCounts(accessToken); //here
          print("sssssssssssssssssssssssssssssssssss");
          print(checkCounts);
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
    _initialSetup();

    _profileAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _profileScaleAnimation = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(
      parent: _profileAnimationController,
      curve: Curves.easeInOut,
    ));
  }

    Future<void> _initialSetup() async {
      String? accessToken = await _secureStorage.read(key: 'access_token');
      if (accessToken != null) {
        await _checkFirstTimeFlag(accessToken);
        if(!isFirstTimeUser){
           await _handleInstagramReconnection();
        }
      }
    }

  @override
  void dispose() {
    _profileAnimationController.dispose();
    super.dispose();
  }

Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (isInstagramConnected) {
      // Connected
      if (isMoreThanCount) {
        // Connected and isMoreThanCount is true: Show profile and cards
        return Column(
          children: [
            _buildUserProfile(),
            SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
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
                  ],
                ),
              ),
            ),
          ],
        );
      } else {
        // Connected and isMoreThanCount is false: Show message, profile, and button
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // Wrap in Container for styling
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 16),
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
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _handleInstagramLoginAndCheckFirstTime,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 73, 200, 209),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                elevation: 2,
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: Icon(Icons.login), // Add a login icon
              label: Text("Login with Instagram"),
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
                  style: TextStyle(color: Colors.red),
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
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                elevation: 2,
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text("Login with Instagram"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildUserProfile() {
    if (instagramUserProfile == null) {
      return CircularProgressIndicator();
    }

    final userData = instagramUserProfile!['user_data'] as Map<String, dynamic>?;

    if (userData == null) {
        return Text("Error: User data not found.");
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
                offset: Offset(0, 2),
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
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "@$username",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      fullName,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 12),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home"),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 20),
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
}