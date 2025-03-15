// api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'encryption.dart';
import 'package:faker/faker.dart'; 


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


  static String _generateRandomUserAgent() {
    final faker = Faker();
    return faker.internet.userAgent();
  } 


  //bech tfechi profile mta3 user men instagram w tab3thou lel backend
  static Future<bool> getInstagramUserInfoAndSave(
      String userId,
      String csrftoken,
      String sessionId,
      String xIgAppId,
      String token) async {
    String url = "https://www.instagram.com/api/v1/users/$userId/info/";
    print("Request URL: $url");

    try {
      String userAgent = _generateRandomUserAgent();

      final headers = {
        "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
        "referer": "https://www.instagram.com/api/v1/users/$userId/info/",
        "x-csrftoken": csrftoken,
        "x-ig-app-id": xIgAppId,
        "user-agent": userAgent,
      };
      print("Headers: $headers");

      print("Sending request to Instagram...");
      final response = await http.get(Uri.parse(url), headers: headers);

      print("Status Code: ${response.statusCode}");
      print("Response Headers: ${response.headers}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        Map<String, dynamic> userInfo = json.decode(response.body);
        print(userInfo);
        // Check if follower_count and following_count exist
        if (userInfo.containsKey('user') &&
          userInfo['user'].containsKey('follower_count') &&
          userInfo['user'].containsKey('following_count')) {
          // Sending the fetched data to the API endpoint
          String saveUrl = "${AppConfig.baseUrl}api/save-user-instagram-profile/";  // Use your base URL
          final saveResponse = await http.post(
            Uri.parse(saveUrl),
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"user_data": userInfo}),
          );

          if (saveResponse.statusCode == 200) {
            print("User data saved successfully.");
            return true; // Successfully saved the user data
          } else {
            print("Failed to save user data: ${saveResponse.statusCode}");
            print("Save Response Body: ${saveResponse.body}"); // Log the save response body
            return false; // Failed to save user data
          }
        } else {
          print("Missing follower_count or following_count in response.");
          return false; // Required fields are missing
        }
      } else {
        print("Failed to fetch data: ${response.statusCode}");
        return false; // Failed to fetch user info
      }
    } catch (e) {
      print("Exception occurred: $e");
      return false; // Exception occurred
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
          '${AppConfig.baseUrl}api/unfollow-status/'), // Your API endpoint
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

  


  static Future<bool> checkInstagramCounts(String accessToken) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}api/check-instagram-counts/'), // Your updated API endpoint
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status']; // Extract the boolean value from the 'status' key
    } else {
      // Handle errors appropriately (e.g., throw an exception)
      throw Exception(
          'Failed to check Instagram counts: ${response.statusCode}');
    }
  }

  
  static Future<bool> checkIf12HoursPassed(String accessToken) async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}api/check-12-hours-passed/'), // Your Django API endpoint
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['has_12_hours_passed']; // Extract the boolean value from the response
    } else {
      // Handle errors appropriately (e.g., throw an exception)
      throw Exception('Failed to check if 12 hours passed: ${response.statusCode}');
    }
  }



  static Future<Map<String, dynamic>> changeUnfollowStatus(
      String token, bool unfollowStatus) async {
    String url = "${AppConfig.baseUrl}api/change_unfollow_status/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "unfollow_status": unfollowStatus,
        }),
      );

      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          "error": "Failed to update unfollow status: ${response.statusCode}",
          "details": response.body
        };
      }
    } catch (e) {
      return {"error": "Exception occurred", "details": e.toString()};
    }
  }



  static Future<bool> updateLastTimeFetched(String token) async {
    String url = "${AppConfig.baseUrl}api/update-last-time-fetched/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print(response.body);

      if (response.statusCode == 200) {
        return true;  // If status code is 200, return true
      } else {
        print('Error: ${response.statusCode}');
        return false;  // If status code is not 200, return false
      }
    } catch (e) {
      print('Exception: $e');
      return false;  // In case of exception, return false
    }
  }

}
