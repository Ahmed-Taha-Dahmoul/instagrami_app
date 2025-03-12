// search_someone_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:faker/faker.dart';

class SearchSomeoneApiService {
  static String generateRandomUserAgent() {
    final faker = Faker();
    return faker.internet.userAgent();
  }

  static Future<List<Map<String, dynamic>>> instagramSearch(
      String query,
      String userId,
      String csrftoken,
      String sessionId,
      String xIgAppId) async {
    final String url = "https://www.instagram.com/api/v1/web/search/topsearch/?context=blended&query=$query&include_reel=false";
    
    String userAgent = generateRandomUserAgent();
    
    Map<String, String> headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "referer": "https://www.instagram.com/",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      "user-agent": userAgent,
    };

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    print(url);
    print(headers);
    if (response.statusCode == 200) {
      List<dynamic> users = json.decode(response.body)['users'];
      return users.map((user) => {
        'pk': user['user']['pk'],
        'username': user['user']['username'],
        'full_name': user['user']['full_name'],
        'is_private': user['user']['is_private'],
        'profile_pic_url': user['user']['profile_pic_url'],
        'following': user['user']['friendship_status']['following'],
      }).toList();
    } else {
      print("Error ${response.statusCode}: ${response.body}");
      print(response);
      return [];
    }
  }

  static Future<Map<String, dynamic>> fetchInstagramFollowing (
      String PK,
      String userId,
      int first,
      String sessionId,
      String csrftoken,
      String xIgAppId,
      String userAgent) async {
    
    String url = "https://www.instagram.com/graphql/query/";
    String queryHash = "58712303d941c6855d4e888c5f0cd22f";

    Map<String, dynamic> variables = {
      "id": PK,
      "first": first,
    };

    Map<String, String> headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      "user-agent": userAgent,
    };

    Map<String, String> params = {
      "query_hash": queryHash,
      "variables": jsonEncode(variables),
    };

    Uri uri = Uri.parse(url).replace(queryParameters: params);
    
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"error": "Request failed with status code \${response.statusCode}", "details": response.body};
    }
  }







  static Future<Map<String, dynamic>> fetchInstagramFollowers (
      String PK,
      String userId,
      int first,
      String sessionId,
      String csrftoken,
      String xIgAppId,
      String userAgent) async {
    
    String url = "https://www.instagram.com/graphql/query/";
    String queryHash = "37479f2b8209594dde7facb0d904896a";

    Map<String, dynamic> variables = {
      "id": PK,
      "first": first,
    };

    Map<String, String> headers = {
      "cookie": "csrftoken=$csrftoken; ds_user_id=$userId; sessionid=$sessionId",
      "x-csrftoken": csrftoken,
      "x-ig-app-id": xIgAppId,
      "user-agent": userAgent,
    };

    Map<String, String> params = {
      "query_hash": queryHash,
      "variables": jsonEncode(variables),
    };

    Uri uri = Uri.parse(url).replace(queryParameters: params);
    
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"error": "Request failed with status code \${response.statusCode}", "details": response.body};
    }
  }
}
