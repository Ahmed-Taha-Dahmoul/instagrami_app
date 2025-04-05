import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import 'config.dart';

class Subscription {
  final String plan;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String creditsReduced;

  Subscription({
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.creditsReduced,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      plan: json['plan'] ?? 'Unknown Plan',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'] ?? 'Unknown',
      creditsReduced: json['credits_reduced']?.toString() ?? '0',
    );
  }
}

class SubscriptionHistoryPage extends StatefulWidget {
  @override
  _SubscriptionHistoryPageState createState() =>
      _SubscriptionHistoryPageState();
}

class _SubscriptionHistoryPageState extends State<SubscriptionHistoryPage> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<Subscription> _subscriptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String? token = await _secureStorage.read(key: 'access_token');
    if (token == null) {
      if (mounted) {
        setState(() {
          _errorMessage = "Authentication error. Please log in again.";
          _isLoading = false;
        });
      }
      return;
    }

    final headers = {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };

    try {
      final url = Uri.parse("${AppConfig.baseUrl}subscription/all/");
      final response = await http.get(url, headers: headers);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> decodedBody = jsonDecode(response.body);
        setState(() {
          _subscriptions =
              decodedBody.map((json) => Subscription.fromJson(json)).toList();
        });
      } else {
        setState(() {
          _errorMessage =
              "Failed to load subscriptions: ${response.statusCode}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An error occurred: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  Widget _buildSubscriptionItem(Subscription subscription) {
    IconData planIcon;
    Color planColor;

    switch (subscription.plan.toLowerCase()) {
      case 'premium':
        planIcon = Icons.star;
        planColor = Color(0xFFE6C76A);
        break;
      case 'vip':
        planIcon = Icons.star_half;
        planColor = Color(0xFFFA8282);
        break;
      default:
        planIcon = Icons.circle;
        planColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 2,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(planIcon, color: planColor, size: 16),
                    SizedBox(width: 6),
                    Text(
                      subscription.plan.toUpperCase(),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Text(
                  subscription.status,
                  style: TextStyle(
                    color: subscription.status == 'Active'
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14),
                    SizedBox(width: 6),
                    Text("Start: ${_formatDate(subscription.startDate)}"),
                  ],
                ),
                Text(
                  "- ${subscription.creditsReduced}",
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.event_available, size: 14),
                SizedBox(width: 6),
                Text("End: ${_formatDate(subscription.endDate)}"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (_, __) => Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 160, height: 16, color: Colors.white),
                SizedBox(height: 12),
                Container(width: 120, height: 14, color: Colors.white),
                SizedBox(height: 8),
                Container(width: 200, height: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      );
    } else if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 10),
              Text(
                "Error loading subscriptions:\n$_errorMessage",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchSubscriptions,
                child: Text("Retry"),
              ),
            ],
          ),
        ),
      );
    } else if (_subscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 50, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "No subscriptions found.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        itemCount: _subscriptions.length,
        itemBuilder: (context, index) {
          return _buildSubscriptionItem(_subscriptions[index]);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Subscription History"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchSubscriptions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSubscriptions,
        child: _buildContent(),
      ),
    );
  }
}
