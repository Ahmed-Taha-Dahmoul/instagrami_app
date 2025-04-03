import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:shimmer/shimmer.dart'; // For loading effect

import 'config.dart';
// --- Data Models (Included directly for completeness) ---
class PaymentInfo {
  final String paymentId;
  final String status; // e.g., 'validated', 'pending', 'rejected'
  final String cardNumber; // Raw card number from API
  final DateTime createdAt;
  final DateTime? validatedAt;

  PaymentInfo({
    required this.paymentId,
    required this.status,
    required this.cardNumber,
    required this.createdAt,
    this.validatedAt,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      paymentId: json['payment_id'] ?? 'unknown_id',
      status: json['status']?.toLowerCase() ?? 'unknown', // Store lowercase for easier comparison
      cardNumber: json['card_number'] ?? '****',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      validatedAt: json['validated_at'] != null
          ? DateTime.tryParse(json['validated_at'])
          : null,
    );
  }
}

class PaymentHistoryEntry {
  final String paymentId;
  final String creditsAdded;

  PaymentHistoryEntry({
    required this.paymentId,
    required this.creditsAdded,
  });

  factory PaymentHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryEntry(
      paymentId: json['payment_id'] ?? 'unknown_id',
      creditsAdded: json['credits_added']?.toString() ?? '0',
    );
  }
}

class DisplayPaymentItem {
  final PaymentInfo paymentInfo;
  final String? creditsAdded;

  DisplayPaymentItem({
    required this.paymentInfo,
    this.creditsAdded,
  });
}
// --- End Data Models ---


class RechargeCardsStatusPage extends StatefulWidget {
  @override
  _RechargeCardsStatusPageState createState() =>
      _RechargeCardsStatusPageState();
}

class _RechargeCardsStatusPageState extends State<RechargeCardsStatusPage> {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  List<DisplayPaymentItem> _displayItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  // --- Define colors ---
  final Color backgroundColor = Colors.grey.shade200;
  final Color cardBackgroundColor = Colors.white;
  final Color headingColor = Colors.grey.shade800;
  final Color textColor = Colors.black87;
  final Color secondaryTextColor = Colors.grey.shade600;
  final Color validatedColor = Colors.green.shade600;
  final Color pendingColor = Colors.orange.shade700;
  final Color rejectedColor = Colors.red.shade600;
  // --- End colors ---

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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
      final results = await Future.wait([
        _fetchPayments(headers),
        _fetchPaymentHistory(headers),
      ]);

      if (results[0] is List<PaymentInfo> && results[1] is List<PaymentHistoryEntry>) {
        final List<PaymentInfo> payments = results[0] as List<PaymentInfo>;
        final List<PaymentHistoryEntry> history = results[1] as List<PaymentHistoryEntry>;
        _combineAndSetData(payments, history);
      } else {
         if(_errorMessage == null) {
            _errorMessage = "Failed to process fetched data.";
         }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _errorMessage ?? "An error occurred: $e";
        });
         print("Error in _fetchData: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<PaymentInfo>> _fetchPayments(Map<String, String> headers) async {
    final url = Uri.parse("${AppConfig.baseUrl}payment/payments");
    try {
      final response = await http.get(url, headers: headers);
      if (!mounted) return [];

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        if (decodedBody is Map && decodedBody.containsKey('payments')) {
           final List<dynamic> paymentsJson = decodedBody['payments'];
           return paymentsJson.map((json) => PaymentInfo.fromJson(json)).toList();
        } else {
           throw Exception("Invalid response format for payments.");
        }
      } else {
         String errorDetail = "(${response.statusCode})";
         try {
             final errorBody = jsonDecode(response.body);
             if(errorBody is Map && errorBody.containsKey('error')){
                 errorDetail += " ${errorBody['error']}";
                 if(errorBody.containsKey('details')){ errorDetail += " (${errorBody['details']})"; }
             }
         } catch(_) {/* Ignore */}
        throw Exception("Failed to load payments $errorDetail");
      }
    } catch (e) {
       if (mounted) setState(() => _errorMessage = "Error fetching payments: $e");
       print("Error in _fetchPayments: $e");
       rethrow;
    }
  }

  Future<List<PaymentHistoryEntry>> _fetchPaymentHistory(Map<String, String> headers) async {
    final url = Uri.parse("${AppConfig.baseUrl}payment/history/");
     try {
        final response = await http.get(url, headers: headers);
        if (!mounted) return [];

        if (response.statusCode == 200) {
          final decodedBody = jsonDecode(response.body);
          if (decodedBody is Map && decodedBody.containsKey('payment_history')) {
            final List<dynamic> historyJson = decodedBody['payment_history'];
            return historyJson.map((json) => PaymentHistoryEntry.fromJson(json)).toList();
          } else {
             throw Exception("Invalid response format for payment history.");
          }
        } else {
          String errorDetail = "(${response.statusCode})";
          try {
              final errorBody = jsonDecode(response.body);
              if(errorBody is Map && errorBody.containsKey('error')){
                  errorDetail += " ${errorBody['error']}";
                  if(errorBody.containsKey('details')){ errorDetail += " (${errorBody['details']})"; }
              }
          } catch(_) {/* Ignore */}
          throw Exception("Failed to load payment history $errorDetail");
        }
     } catch(e) {
        if (mounted) setState(() => _errorMessage = (_errorMessage ?? "") + "\nError fetching history: $e");
        print("Error in _fetchPaymentHistory: $e");
        rethrow;
     }
  }

  void _combineAndSetData(List<PaymentInfo> payments, List<PaymentHistoryEntry> history) {
    final Map<String, String> historyMap = {
      for (var entry in history) entry.paymentId: entry.creditsAdded
    };

    final List<DisplayPaymentItem> combinedItems = payments.map((payment) {
      // Using lowercase status from model now
      bool isPaymentValidated = payment.status == 'validated';

      return DisplayPaymentItem(
        paymentInfo: payment,
        creditsAdded: isPaymentValidated ? historyMap[payment.paymentId] : null,
      );
    }).toList();

    if(mounted){
       setState(() {
         _displayItems = combinedItems;
       });
    }
  }

  // --- REMOVED _maskCardNumber function ---

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
       return DateFormat('MMM d, yyyy - hh:mm a').format(dateTime);
    } catch (e) {
       print("Error formatting date: $e");
       return dateTime.toIso8601String();
    }
  }

  Widget _getStatusWidget(String status) {
    IconData icon;
    Color color;
    String text = status.toUpperCase(); // Use uppercase for display consistency

    // Using lowercase status from model for comparison
    switch (status) {
      case 'validated':
        icon = Icons.check_circle;
        color = validatedColor;
        text = 'VALIDATED';
        break;
      case 'pending':
        icon = Icons.hourglass_top_rounded;
        color = pendingColor;
        text = 'PENDING';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = rejectedColor;
        text = 'REJECTED';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        text = status.isNotEmpty ? text : 'UNKNOWN'; // Show original if unknown but non-empty
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPaymentItem(DisplayPaymentItem item) {
    bool isItemValidated = item.paymentInfo.status == 'validated';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 6,
            spreadRadius: 1,
            offset: Offset(0, 2),
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
                // --- CHANGE: Display full card number ---
                Flexible( // Use Flexible to prevent overflow if number is very long
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Don't take full width unless needed
                    children: [
                      Icon(Icons.credit_card, color: secondaryTextColor, size: 20),
                      SizedBox(width: 8),
                      Flexible( // Allow text to wrap or shrink if needed
                        child: Text(
                          item.paymentInfo.cardNumber, // Display raw card number
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
                          overflow: TextOverflow.ellipsis, // Handle overflow
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Widget
                _getStatusWidget(item.paymentInfo.status),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey[200]),
            SizedBox(height: 12),

            if (isItemValidated && item.creditsAdded != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                   children: [
                     Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                     SizedBox(width: 6),
                     Text(
                       "Credits Added: ${item.creditsAdded}",
                       style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                     ),
                   ],
                ),
              ),
            Row(
              children: [
                 Icon(Icons.calendar_today, color: secondaryTextColor, size: 14),
                 SizedBox(width: 6),
                 Text(
                   "Requested: ${_formatDate(item.paymentInfo.createdAt)}",
                   style: TextStyle(fontSize: 13, color: secondaryTextColor),
                 ),
              ],
            ),
            if (item.paymentInfo.validatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                   children: [
                      Icon(Icons.event_available, color: secondaryTextColor, size: 14),
                      SizedBox(width: 6),
                      Text(
                        isItemValidated ? "Validated: " : "Processed: ",
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                      Text(
                        _formatDate(item.paymentInfo.validatedAt),
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                   ],
                ),
              ),
          ],
        ),
      ),
    );
  }

   Widget _buildLoadingShimmer() {
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
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Container(width: 160, height: 16, color: Colors.white),
                   Container(width: 80, height: 16, color: Colors.white),
                 ],
               ),
               SizedBox(height: 12),
               Divider(height: 1),
               SizedBox(height: 12),
               Container(width: 120, height: 14, color: Colors.white),
               SizedBox(height: 8),
               Container(width: 200, height: 14, color: Colors.white),
             ],
           ),
         ),
       ),
     );
   }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Recharge Status"),
        backgroundColor: cardBackgroundColor,
        foregroundColor: headingColor,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: headingColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: headingColor),
              onPressed: _isLoading ? null : _fetchData,
              tooltip: "Refresh",
            )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: Theme.of(context).primaryColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
     if (_isLoading && _displayItems.isEmpty) {
       return _buildLoadingShimmer();
     }
     else if (_errorMessage != null) {
       return LayoutBuilder(
          builder: (context, constraints) {
             return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                   constraints: BoxConstraints(minHeight: constraints.maxHeight),
                   child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             Icon(Icons.error_outline, color: Colors.red, size: 40),
                             SizedBox(height: 10),
                             Text(
                                "Error loading status:\n$_errorMessage",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: headingColor, fontSize: 16),
                             ),
                              SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _fetchData,
                                child: Text("Retry"),
                              )
                          ],
                        ),
                      ),
                   ),
                ),
             );
          }
       );
     }
     else if (!_isLoading && _displayItems.isEmpty) {
       return LayoutBuilder(
          builder: (context, constraints) {
             return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                   constraints: BoxConstraints(minHeight: constraints.maxHeight),
                   child: Center(
                      child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                            Icon(Icons.history_toggle_off, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              "No payment history found.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: secondaryTextColor, fontSize: 16),
                            ),
                         ],
                      ),
                   ),
                ),
             );
          }
       );
     }
     else {
       return ListView.builder(
         itemCount: _displayItems.length,
         itemBuilder: (context, index) {
           return _buildPaymentItem(_displayItems[index]);
         },
       );
     }
   }
}