import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:faker/faker.dart';
import 'config.dart';

class InstagramService {
  // Method to generate random user-agent using the faker package
  static String _generateRandomUserAgent() {
    final faker = Faker();
    return faker.internet.userAgent();
  }

  static Future<List<dynamic>?> getInstagramFollowing(
      String userId, String sessionId, String csrftoken, String xIgAppId) async {
    
    List<dynamic> following = [];
    String? nextMaxId;
    int maxRetries = 3;
    int count = 200;
    Random random = Random();

    while (true) {
      String url =
          "https://www.instagram.com/api/v1/friendships/$userId/following/?count=$count";

      if (nextMaxId != null) {
        url += "&max_id=$nextMaxId";
      }

      int retries = 0;
      while (retries < maxRetries) {
        try {
          // Generate a new User-Agent for each request
          String userAgent = _generateRandomUserAgent();

          final headers = {
            "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
            "referer": "https://www.instagram.com/$userId/following/",
            "x-csrftoken": csrftoken,
            "x-ig-app-id": xIgAppId,
            "user-agent": userAgent, // Add random user-agent here
          };

          print("Fetching: $url");
          final response = await http.get(Uri.parse(url), headers: headers);

          if (response.statusCode != 200) {
            throw Exception("Request failed with status: ${response.statusCode}");
          }

          final data = jsonDecode(response.body);
          if (!data.containsKey('users')) {
            return null;
          }

          following.addAll(data['users']);
          nextMaxId = data['next_max_id'];

          if (nextMaxId == null && count == 200) {
            count = 1;
            break;
          }

          if (nextMaxId == null) {
            break;
          }

          // Random delay between 1 and 3 seconds
          int delay = random.nextInt(3) + 1;
          print("Waiting for $delay seconds...");
          await Future.delayed(Duration(seconds: delay));

          break;
        } catch (e) {
          retries++;
          if (retries < maxRetries) {
            print("Retrying in 5 seconds...");
            await Future.delayed(Duration(seconds: 5));
          } else {
            return null;
          }
        }
      }

      if (nextMaxId == null && count == 1) {
        break;
      }
    }

    return following;
  }

  static Future<List<dynamic>?> getInstagramFollowers(
      String userId, String sessionId, String csrftoken, String xIgAppId) async {
    List<dynamic> allFollowers = [];  // List to store all fetched followers
    String? nextMaxId = '';  // Variable to store nextMaxId for pagination

    // URL to fetch followers
    String url = 'https://www.instagram.com/api/v1/friendships/$userId/followers/?count=200';

    // Headers
    Map<String, String> headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "referer": "https://www.instagram.com/$userId/followers/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
    };

    try {
      while (true) {
        // Generate a new random user-agent for each request
        String userAgent = _generateRandomUserAgent();
        headers["user-agent"] = userAgent;

        // If there's a nextMaxId, append it to the URL for pagination
        String paginatedUrl = nextMaxId != '' ? '$url&max_id=$nextMaxId' : url;
        print(paginatedUrl);
        // Perform the GET request
        final response = await http.get(Uri.parse(paginatedUrl), headers: headers);

        // Check if the request was successful
        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);

          // Add fetched followers to the list
          allFollowers.addAll(data['users']);

          // Check if there is more data to fetch
          nextMaxId = data['next_max_id'];
          if (nextMaxId == null || nextMaxId.isEmpty) {
            break;  // No more followers to fetch, exit the loop
          }
        } else {
          print('Error fetching followers: ${response.statusCode} - ${response.body}');
          break;  // Exit the loop if there is an error
        }
      }

      // Return the list of all followers
      return allFollowers;
    } catch (e) {
      print('An error occurred: $e');
      return null;  // Return null in case of an error
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
    print(followingData);
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








