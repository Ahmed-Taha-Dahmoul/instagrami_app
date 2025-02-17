import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class InstagramLogin extends StatefulWidget {
  @override
  _InstagramLoginState createState() => _InstagramLoginState();
}

class _InstagramLoginState extends State<InstagramLogin> {
  InAppWebViewController? webViewController;
  String? xIgAppId;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Instagram Login")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri("https://www.instagram.com/accounts/login/"),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            cacheEnabled: false,
          ),
          android: AndroidInAppWebViewOptions(
            useHybridComposition: true,
          ),
          ios: IOSInAppWebViewOptions(
            allowsInlineMediaPlayback: true,
          ),
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
          clearCookiesAndCache();
        },
        onLoadStop: (controller, url) async {
          try {
            // Add a delay to ensure the page is fully loaded
            await Future.delayed(Duration(seconds: 3));

            // Get all cookies associated with the Instagram domain
            CookieManager cookieManager = CookieManager.instance();
            List<Cookie> cookies = await cookieManager.getCookies(url: url!);

            // Check if the 'ds_user_id' cookie is present (indicating the user is logged in)
            bool isLoggedIn =
                cookies.any((cookie) => cookie.name == 'ds_user_id');

            if (isLoggedIn) {
              // User is logged in, proceed with your actions
              Map<String, String> cookieData = {};
              for (var cookie in cookies) {
                cookieData[cookie.name] = cookie.value;
              }

              if (cookieData.isNotEmpty) {
                await saveUserData(cookieData);
                await scrapeXIgAppId();
                await sendCookies(cookieData);

                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            } else {
              print("User is not logged in yet.");
            }
          } catch (e) {
            print("Error checking login status: $e");
          }
        },
      ),
    );
  }

  Future<void> clearCookiesAndCache() async {
    CookieManager cookieManager = CookieManager.instance();
    await cookieManager.deleteAllCookies();
    print("Cookies and Cache cleared!");
  }

  Future<void> saveUserData(Map<String, String> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String jsonCookies = jsonEncode(userData);
    await prefs.setString("cookies_json", jsonCookies);
    print("Cookies saved: $jsonCookies");
  }

  Future<void> sendCookies(Map<String, String> cookies) async {
    try {
      String? accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        print("Access token is null or empty.");
        return;
      }

      Uri apiUrl = Uri.parse("${AppConfig.baseUrl}api/data/");
      Map<String, dynamic> requestBody = {
        "cookies": cookies,
        "x_ig_app_id": xIgAppId ?? "",
      };

      print("Request body: ${jsonEncode(requestBody)}");

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      };

      final response = await http.post(
        apiUrl,
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("Cookies and x_ig_app_id sent successfully!");
      } else {
        print("Failed to send data. Status code: ${response.statusCode}");
        print("Error message: ${response.body}");
      }
    } catch (e) {
      print("Error sending cookies via request: $e");
    }
  }

  Future<void> scrapeXIgAppId() async {
    try {
      // Ensure WebViewController is not disposed before running the script
      if (webViewController == null) {
        print("WebViewController is disposed.");
        return;
      }

      String? script = """
        (function() {
          // Simple function to find the appId from the page's script content
          const allScripts = Array.from(document.querySelectorAll('script'))
            .map(script => script.textContent) // Collect all inline script content
            .join("\\n");

          // Try to match the appId pattern
          const appIdMatch = allScripts.match(/\\"appId\\":\\"(\\d+)\\"/);

          if (appIdMatch) {
            console.log('Found appId:', appIdMatch[1]);
            return appIdMatch[1];
          } else {
            console.warn('App ID not found.');
            return null;
          }
        })();
      """;

      // Run the script in the web view and await the result
      String? scrapedXIgAppId =
          await webViewController?.evaluateJavascript(source: script);

      print("Scraped x_ig_app_id result: $scrapedXIgAppId"); // Debugging line

      // Check if the result is null or empty
      if (scrapedXIgAppId != null && scrapedXIgAppId.isNotEmpty) {
        setState(() {
          xIgAppId = scrapedXIgAppId;
        });
        print("Extracted x_ig_app_id: $xIgAppId");
      } else {
        print("Failed to extract x_ig_app_id.");
      }
    } catch (e) {
      print("Error during script execution: $e");
    }
  }
}
