import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:achhafoods/screens/Consts/conts.dart';

class ShopifyService {
  /// Fetches the latest Admin API Access Token from Laravel
  /// and updates the global variable `adminAccessToken_const`.
  static Future<bool> initToken() async {
    try {
      if (kDebugMode) print("🔄 Refreshing Shopify Admin Token...");

      final response = await http.get(Uri.parse('$localurl/api/shopify-token'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['access_token'] != null) {
          // ✅ Update the global constant
          adminAccessToken_const = data['access_token'];
          if (kDebugMode) print("✅ Shopify Token Updated: $adminAccessToken_const");
          return true;
        }
      }
      if (kDebugMode) print("⚠️ Failed to fetch token. Status: ${response.statusCode}");
      return false;
    } catch (e) {
      if (kDebugMode) print("❌ Error initializing Shopify token: $e");
      return false;
    }
  }
}