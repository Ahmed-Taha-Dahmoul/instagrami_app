import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:faker/faker.dart';
import 'config.dart';

class InstagramService {
  // Method to generate random user-agent using the faker package
  // ignore: unused_element
  static String _generateRandomUserAgent() {
    final faker = Faker();
    return faker.internet.userAgent();
  }


  


   static Future<List<Map<String, dynamic>>?> getInstagramFollowing(
    String userId,
    String sessionId,
    String csrftoken,
    String xIgAppId,
  ) async {
    List<Map<String, dynamic>> allFollowing = [];
    String? nextMaxId;
    String url = "https://www.instagram.com/graphql/query/";
    String queryHash = "58712303d941c6855d4e888c5f0cd22f"; // Correct query hash for FOLLOWING
    const int first = 50;

    String userAgent = _generateRandomUserAgent();

    final Map<String, String> headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      "user-agent": userAgent,
    };
    print("Fetching Instagram following for user ID: $userId");
    try {
      while (true) {
        final Map<String, dynamic> variables = {
          "id": userId,
          "first": first,
          "after": nextMaxId,
        };

        final Map<String, String> params = {
          "query_hash": queryHash,
          "variables": jsonEncode(variables),
        };

        final Uri uri = Uri.parse(url).replace(queryParameters: params);
        final http.Response response = await http.get(uri, headers: headers);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);

          if (data.containsKey('data') &&
              data['data'] != null &&
              data['data'].containsKey('user') &&
              data['data']['user'] != null &&
              data['data']['user'].containsKey('edge_follow') &&
              data['data']['user']['edge_follow'] != null) {
            final List<dynamic> edges =
                data['data']['user']['edge_follow']['edges'];

            for (var edge in edges) {
              final node = edge['node'];
              allFollowing.add({
                'id': node['id'],
                'username': node['username'],
                'full_name': node['full_name'],
                'profile_pic_url': node['profile_pic_url'],
                'is_verified' : node['is_verified'],
              });
            }

            if (data['data']['user']['edge_follow'].containsKey('page_info') &&
                data['data']['user']['edge_follow']['page_info'] != null) {
              final pageInfo = data['data']['user']['edge_follow']['page_info'];

              // Check both 'has_next_page' and 'end_cursor'
              if (pageInfo.containsKey('has_next_page') &&
                  pageInfo['has_next_page'] == false) {
                break; // No more pages, exit the loop
              }

              if (pageInfo.containsKey('end_cursor')) {
                nextMaxId = pageInfo['end_cursor'];
                if (nextMaxId == null || nextMaxId.isEmpty) {
                    break;  // Exit if end_cursor is null or empty
                }

              } else {
                nextMaxId = null;
                break; // No end_cursor, assume no more pages
              }
            } else {
              break; // No page_info, exit loop
            }
          } else {
            print(
                "Error: Unexpected response structure. 'data', 'user', or 'edge_follow' is missing.");
            return null;
          }
        } else {
          print(
              "Error fetching following: ${response.statusCode} - ${response.body}");
          return null;
        }
      }

      return allFollowing;
    } catch (e) {
      print("An error occurred: $e");
      return null;
    }
  }




  static Future<List<Map<String, dynamic>>?> getInstagramFollowers(
      String userId,
      String sessionId,
      String csrftoken,
      String xIgAppId,
    ) async {
      List<Map<String, dynamic>> allFollowers = [];
      String? nextMaxId;
      String url = "https://www.instagram.com/graphql/query/";
      String queryHash = "37479f2b8209594dde7facb0d904896a"; // Correct query hash for FOLLOWERS
      const int first = 50;

      String userAgent = _generateRandomUserAgent();

      final Map<String, String> headers = {
        "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": xIgAppId,
        "user-agent": userAgent,
      };
      print("Fetching Instagram followers for user ID: $userId");

      try {
        while (true) {
          final Map<String, dynamic> variables = {
            "id": userId,
            "first": first,
            "after": nextMaxId,
          };

          final Map<String, String> params = {
            "query_hash": queryHash,
            "variables": jsonEncode(variables),
          };

          final Uri uri = Uri.parse(url).replace(queryParameters: params);
          final http.Response response = await http.get(uri, headers: headers);

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(response.body);

            if (data.containsKey('data') &&
                data['data'] != null &&
                data['data'].containsKey('user') &&
                data['data']['user'] != null &&
                data['data']['user'].containsKey('edge_followed_by') &&
                data['data']['user']['edge_followed_by'] != null) {
              final List<dynamic> edges =
                  data['data']['user']['edge_followed_by']['edges'];

              for (var edge in edges) {
                final node = edge['node'];
                allFollowers.add({
                  'id': node['id'],
                  'username': node['username'],
                  'full_name': node['full_name'],
                  'profile_pic_url': node['profile_pic_url'],
                  'is_verified': node['is_verified'],
                });
              }

              if (data['data']['user']['edge_followed_by'].containsKey('page_info') &&
                  data['data']['user']['edge_followed_by']['page_info'] != null) {
                final pageInfo = data['data']['user']['edge_followed_by']['page_info'];

                if (pageInfo.containsKey('has_next_page') &&
                    pageInfo['has_next_page'] == false) {
                  break;
                }

                if (pageInfo.containsKey('end_cursor')) {
                  nextMaxId = pageInfo['end_cursor'];
                  if (nextMaxId == null || nextMaxId.isEmpty) {
                      break;
                  }

                } else {
                  nextMaxId = null;
                  break;
                }
              } else {
                break;
              }
            } else {
              print(
                  "Error: Unexpected response structure. 'data', 'user', or 'edge_followed_by' is missing.");
              return null;
            }
          } else {
            print(
                "Error fetching followers: ${response.statusCode} - ${response.body}");
            return null;
          }
        }

        return allFollowers;
      } catch (e) {
        print("An error occurred: $e");
        return null;
      }
    }




}



class InstagramApiService {
  static Future<void> sendFollowingList(
      String token, List<dynamic> followingList) async {
    final response = await http.post(
      Uri.parse("${AppConfig.baseUrl}api/save-fetched-following/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"following_list": followingList}),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to send following list. Status: ${response.statusCode}");
    }
  }

  static Future<void> sendFollowerList(
      String token, List<dynamic> followersList) async {
    final response = await http.post(
      Uri.parse("${AppConfig.baseUrl}api/save-fetched-followers/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"followers_list": followersList}),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Failed to send followers list. Status: ${response.statusCode}");
    }
  }
}

Future<bool> fetchAndSendfollowing_followers(
    String token,
    String userId,
    String sessionId,
    String csrftoken,
    String xIgAppId) async {
  try {
    // Fetch Following Data
    List<dynamic>? followingData = await InstagramService.getInstagramFollowing(
        userId, sessionId, csrftoken, xIgAppId);
    print("following data !!!!!!!!!!!!!!!!!!!!!!");
    
    // Fetch Followers Data
    List<dynamic>? followersData = await InstagramService.getInstagramFollowers(
        userId, sessionId, csrftoken, xIgAppId);

    print("follower data ??????????????????????????????????????????????");
    print(followersData);

    bool followingSuccess = false;
    bool followersSuccess = false;

    // Send Following Data
    if (followingData != null) {
      try {
        await InstagramApiService.sendFollowingList(token, followingData);
        followingSuccess = true;
      } catch (e) {
        print("Error sending following data: $e");
      }
    } else {
      print("Failed to retrieve following data.");
    }

    // Send Followers Data
    if (followersData != null) {
      try {
        await InstagramApiService.sendFollowerList(token, followersData);
        followersSuccess = true;
      } catch (e) {
        print("Error sending followers data: $e");
      }
    } else {
      print("Failed to retrieve followers data.");
    }

    return followingSuccess && followersSuccess;
  } catch (e) {
    print("Unexpected error: $e");
    return false;
  }
}








