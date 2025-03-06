import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart'; // Ensure this file contains AppConfig.baseUrl

// Class to represent the flag data and make the requests
class FirstTimeFlagService {
  // Fetch the current first-time flag (static method)
  static Future<bool> fetchFirstTimeFlag(String token) async {
    String url = "${AppConfig.baseUrl}api/get-first-time-flag/";

    try {
      print(url);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Response status: ${response.statusCode}");  // Debugging
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        // Return true if the first-time flag is true, otherwise false
        return data['is_first_time_connected_flag'] == true;
      } else {
        print("Failed to fetch first-time flag: ${response.statusCode}");
        return false;  // In case of failure, we return false
      }
    } catch (e) {
      print("Error fetching first-time flag: $e");
      return false;  // If there's an error, return false
    }
  }

  // Send the updated first-time flag status (true or false) via POST (static method)
  static Future<bool> postFirstTimeFlag(String token, bool flagValue) async {
    String url = "${AppConfig.baseUrl}api/update-first-time-flag/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: json.encode({
          'is_first_time_connected_flag': flagValue,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        // If the flag is updated successfully, return the updated value
        return data['is_first_time_connected_flag'] == flagValue;
      } else {
        print("Failed to update first-time flag: ${response.statusCode}");
        return false;  // Return false in case of failure
      }
    } catch (e) {
      print("Error updating first-time flag: $e");
      return false;  // If there's an error, return false
    }
  }
}
