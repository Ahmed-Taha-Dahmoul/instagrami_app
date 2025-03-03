// api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'encryption.dart';

class ApiService {
  static Future<Map<String, dynamic>> getInstagramData(String token) async {
    final response = await http.get(
      Uri.parse("${AppConfig.baseUrl}api/instagram-data/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      String encryptedData = jsonDecode(response.body)['encrypted_data'];
      String decryptedData = EncryptionHelper.decryptData(encryptedData);

      return jsonDecode(decryptedData);
    } else {
      throw Exception(
          "Failed to fetch Instagram credentials. Status: ${response.statusCode}");
    }
  }

  static Future<bool> checkInstagramStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${AppConfig.baseUrl}api/check_instagram_status/"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['connected'];
      } else {
        print("Failed to check Instagram status: ${response.statusCode}");
        return false; // Or throw an exception, depending on your error handling strategy
      }
    } catch (e) {
      print("Error checking Instagram status: $e");
      return false; // Or rethrow the exception
    }
  }

  //bech tfechi profile mta3 user men instagram w tab3thou lel backend
  static Future<Map<String, dynamic>> getInstagramUserInfoAndSave(String userId,
      String csrftoken, String sessionId, String xIgAppId, String token) async {
    String url = "https://www.instagram.com/api/v1/users/$userId/info/";
    print("haw url");
    print(url);

    final headers = {
      "cookie":
          "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "referer": "https://www.instagram.com/api/v1/users/$userId/info/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
    };

    try {
      print("haw url");
      print(url);
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        Map<String, dynamic> userInfo = json.decode(response.body);

        // Sending the fetched data to the API endpoint
        String saveUrl = "${AppConfig.baseUrl}api/save-user-instagram-profile/";
        final saveResponse = await http.post(
          Uri.parse(saveUrl),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"user_data": userInfo}),
        );

        if (saveResponse.statusCode == 200) {
          return {"success": "User data saved successfully"};
        } else {
          return {
            "error": "Failed to save user data: ${saveResponse.statusCode}",
            "details": saveResponse.body
          };
        }
      } else {
        return {
          "error": "Failed to fetch data: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      return {"error": "Exception occurred", "details": e.toString()};
    }
  }

  //hedhi bech tjib user profile mel backend
  static Future<Map<String, dynamic>> fetchInstagramUserProfile(
      String token) async {
    String url = "${AppConfig.baseUrl}api/get-user-instagram-profile/";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "error": "Failed to fetch user profile: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      return {"error": "Exception occurred", "details": e.toString()};
    }
  }

  static Future<bool> checkUnfollowStatus(String accessToken) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.baseUrl}/api/unfollow-status/'), // Your API endpoint
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['unfollowed']; // Extract the boolean value
    } else {
      // Handle errors appropriately (e.g., throw an exception)
      throw Exception(
          'Failed to check unfollow status: ${response.statusCode}');
    }
  }
}
