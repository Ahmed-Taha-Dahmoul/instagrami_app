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
        print("gooooooooooooooooooooooooooooooooooooooooooooooooooodddd");
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
}
