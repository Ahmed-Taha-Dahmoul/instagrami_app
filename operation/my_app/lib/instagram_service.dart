import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'config.dart';

class InstagramService {
  static Future<List<dynamic>?> getInstagramFollowing(String userId,
      String sessionId, String csrftoken, String xIgAppId) async {
    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "referer": "https://www.instagram.com/$userId/following/?next=/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
    };

    List<dynamic> following = [];
    String? nextMaxId;
    int maxRetries = 3;
    int retryDelay = 5;
    int count = 100;

    while (true) {
      String url =
          "https://www.instagram.com/api/v1/friendships/$userId/following/?count=$count";

      if (nextMaxId != null) {
        url += "&max_id=$nextMaxId";
      }

      int retries = 0;
      while (retries < maxRetries) {
        try {
          print(url);
          final response = await http.get(Uri.parse(url), headers: headers);

          if (response.statusCode != 200) {
            throw Exception(
                "Request failed with status: ${response.statusCode}");
          }

          final data = jsonDecode(response.body);
          if (!data.containsKey('users')) {
            return null;
          }

          following.addAll(data['users']);
          nextMaxId = data['next_max_id'];

          if (nextMaxId == null && count == 100) {
            count = 1;
            break;
          }

          if (nextMaxId == null) {
            break;
          }

          break;
        } catch (e) {
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(seconds: retryDelay));
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

  static Future<List<dynamic>?> getInstagramFollowers(String userId,
      String sessionId, String csrftoken, String xIgAppId) async {
    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "referer": "https://www.instagram.com/$userId/followers/?next=/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
    };

    List<dynamic> followers = [];
    String? nextMaxId;
    int maxRetries = 3;
    int retryDelay = 5;
    int count = 100;

    while (true) {
      String url =
          "https://www.instagram.com/api/v1/friendships/$userId/followers/?count=$count";

      if (nextMaxId != null) {
        url += "&max_id=$nextMaxId";
      }

      int retries = 0;
      while (retries < maxRetries) {
        try {
          print(url);
          final response = await http.get(Uri.parse(url), headers: headers);

          if (response.statusCode != 200) {
            throw Exception(
                "Request failed with status: ${response.statusCode}");
          }

          final data = jsonDecode(response.body);
          if (!data.containsKey('users')) {
            return null;
          }

          followers.addAll(data['users']);
          nextMaxId = data['next_max_id'];

          if (nextMaxId == null && count == 100) {
            count = 1;
            break;
          }

          if (nextMaxId == null) {
            break;
          }

          break;
        } catch (e) {
          retries++;
          if (retries < maxRetries) {
            await Future.delayed(Duration(seconds: retryDelay));
          } else {
            return null;
          }
        }
      }

      if (nextMaxId == null && count == 1) {
        break;
      }
    }
    return followers;
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

Future<void> fetchAndSendInstagramData(String token, String userId,
    String sessionId, String csrftoken, String xIgAppId) async {
  // Fetch Following Data
  List<dynamic>? followingData = await InstagramService.getInstagramFollowing(
      userId, sessionId, csrftoken, xIgAppId);

  // Fetch Followers Data
  List<dynamic>? followersData = await InstagramService.getInstagramFollowers(
      userId, sessionId, csrftoken, xIgAppId);

  // Send Following Data
  if (followingData != null) {
    try {
      await InstagramApiService.sendFollowingList(token, followingData);
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
    } catch (e) {
      print("Error sending followers data: $e");
    }
  } else {
    print("Failed to retrieve followers data.");
  }
}
