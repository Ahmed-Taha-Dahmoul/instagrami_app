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
    int count = 32;

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

          if (nextMaxId == null && count == 32) {
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
}

class InstagramApiService {
  static Future<void> sendFollowerList(
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
          "Failed to send follower list. Status: ${response.statusCode}");
    }
  }
}

Future<void> fetchAndSendFollowing(String token, String userId,
    String sessionId, String csrftoken, String xIgAppId) async {
  List<dynamic>? followingData = await InstagramService.getInstagramFollowing(
      userId, sessionId, csrftoken, xIgAppId);

  if (followingData != null) {
    try {
      await InstagramApiService.sendFollowerList(token, followingData);
    } catch (e) {
      print("Error sending data: $e");
    }
  } else {
    print("Failed to retrieve following data.");
  }
}
