// lib/services/coupon_api_service.dart
import 'dart:convert';
import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CouponApiService {
  // Replace with your Laravel API URL
  static const String baseUrl = '$localurl/api';
  static const String apiKey =
      '87435345e473b5f04042c5d6c43aa737a74587c7184b4945c0926fbe6ace0b05';

  static Future<Map<String, dynamic>> generateCoupon(double discountValue) async {
    try {
      // Get customer access token if available
      final prefs = await SharedPreferences.getInstance();
      final customerAccessToken = prefs.getString('laravelUser');
      final laravelToken = prefs.getString('laravelToken');

      print("🔑 Laravel Token: $laravelToken");
      print("👤 Laravel User (if any): $customerAccessToken");
      print("➡️ Sending request to: $baseUrl/generate-coupon");
      print("📦 Request body: ${json.encode({
        'discount_value': discountValue,
        'api_key': apiKey,
      })}");

      final response = await http.post(
        Uri.parse('$baseUrl/generate-coupon'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $laravelToken',
        },
        body: json.encode({
          'discount_value': discountValue,
          'api_key': apiKey,
        }),
      );

      print("⬅️ Response status: ${response.statusCode}");
      print("⬅️ Response body: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception(
            'Failed to generate coupon: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stack) {
      print("❌ Exception while generating coupon: $e");
      print("📌 Stacktrace: $stack");
      throw Exception('Failed to generate coupon: $e');
    }
  }
}
