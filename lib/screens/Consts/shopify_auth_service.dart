import 'dart:convert';
import 'dart:math';
import 'package:achhafoods/screens/Consts/conts.dart'; // Ensure adminAccessToken_const is here
// IMPORT YOUR TOKEN SERVICE (Adjust path if necessary)
// import 'package:achhafoods/services/ShopifyService.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';

// ---------------------------------------------------------------------------
// 🛡️ TOKEN SERVICE MOCK
// (Paste this class in a separate file like lib/services/ShopifyService.dart if not exists)
// ---------------------------------------------------------------------------
class ShopifyService {
  static Future<bool> initToken() async {
    try {
      if (kDebugMode) print("🔄 Refreshing Shopify Admin Token...");
      final response = await http.get(Uri.parse('$localurl/api/shopify-token'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          adminAccessToken_const = data['access_token']; // Updates global const
          if (kDebugMode) print("✅ Shopify Token Updated: $adminAccessToken_const");
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) print("❌ Error initializing Shopify token: $e");
      return false;
    }
  }
}
// ---------------------------------------------------------------------------

class ShopifyAuthService {
  static const FlutterAppAuth _appAuth = FlutterAppAuth();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _clientId = 'c01bcd45-7b27-49c1-b414-2a4e49f38079';
  static const String _shopId = '69603295509';
  static const String _redirectUrl = 'shop.69603295509.app://callback';

  // API Config
  static const String shopifyStoreUrl = shopifyStoreUrl_const;
  static const String storefrontApiVersion = storefrontApiVersion_const;
  static const String adminApiVersion = adminApiVersion_const;

  // 🔴 DYNAMIC TOKEN GETTER
  static String get adminAccessToken => adminAccessToken_const;

  // ===========================================================================
  // 🔐 OAUTH HELPER METHODS (PKCE)
  // ===========================================================================

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // ===========================================================================
  // 🟢 LOGIN (Customer Account API)
  // ===========================================================================

  static Future<Map<String, dynamic>?> loginWithShopify() async {
    try {
      if (kDebugMode) print('🚀 Starting Shopify Customer OAuth...');

      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateRandomString(32);

      final authUri = Uri.parse('https://shopify.com/$_shopId/auth/oauth/authorize').replace(queryParameters: {
        'client_id': _clientId,
        'scope': 'openid email https://api.customers.com/auth/customer.graphql',
        'redirect_uri': _redirectUrl,
        'response_type': 'code',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: 'shop.69603295509.app',
      );

      final callbackUri = Uri.parse(result);
      final code = callbackUri.queryParameters['code'];

      if (code == null) throw Exception('No authorization code received');

      final tokenUrl = Uri.parse('https://shopify.com/$_shopId/auth/oauth/token');

      final tokenResponse = await http.post(
        tokenUrl,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'redirect_uri': _redirectUrl,
          'code': code,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Token Exchange Failed: ${tokenResponse.body}');
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      final idToken = tokenData['id_token'];

      if (accessToken == null) throw Exception('No access token in response');

      // Save Tokens
      await _storage.write(key: 'customer_access_token', value: accessToken);
      if (idToken != null) {
        await _storage.write(key: 'id_token', value: idToken);
      }

      return await getCustomerDetails(accessToken);

    } catch (e) {
      if (kDebugMode) print('❌ Shopify OAuth Error: $e');
      return null;
    }
  }

  // ===========================================================================
  // 📋 GET CUSTOMER DETAILS (GraphQL)
  // ===========================================================================

  static Future<Map<String, dynamic>?> getCustomerDetails(String customerAccessToken) async {
    try {
      const query = '''
        query {
          customer {
            id
            firstName
            lastName
            emailAddress {
              emailAddress
            }
            phoneNumber {
              phoneNumber
            }
            defaultAddress {
              id
              address1
              address2
              city
              province
              country
              zip
            }
            addresses(first: 10) {
              nodes {
                id
                address1
                address2
                city
                province
                country
                zip
              }
            }
          }
        }
      ''';

      final data = await _makeCustomerApiRequest(
        accessToken: customerAccessToken,
        query: query,
      );

      final rawCust = data['customer'];

      final mappedCustomer = {
        'id': rawCust['id'],
        'firstName': rawCust['firstName'] ?? '',
        'lastName': rawCust['lastName'] ?? '',
        'email': rawCust['emailAddress']?['emailAddress'] ?? '',
        'phone': rawCust['phoneNumber']?['phoneNumber'] ?? '',
        'defaultAddress': rawCust['defaultAddress'],
        'addresses': rawCust['addresses']?['nodes'] ?? [],
      };

      return {
        'accessToken': customerAccessToken,
        'customer': mappedCustomer,
        'timestamp': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      if (kDebugMode) print('❌ Error in getCustomerDetails: $e');
      return null;
    }
  }

  // ===========================================================================
  // 📦 GET ORDERS (GraphQL - Customer Account API)
  // ===========================================================================

  // static Future<List<Map<String, dynamic>>> getCustomerOrdersStorefront(
  //     String customerAccessToken) async {
  //   try {
  //     const ordersQuery = '''
  //     query {
  //       customer {
  //         orders(first: 10, sortKey: PROCESSED_AT, reverse: true) {
  //           nodes {
  //             id
  //             name
  //             processedAt
  //             financialStatus
  //             fulfillmentStatus
  //             totalPrice {
  //               amount
  //               currencyCode
  //             }
  //             lineItems(first: 5) {
  //               nodes {
  //                 title
  //                 quantity
  //                 image {
  //                   url
  //                 }
  //                 price {
  //                   amount
  //                   currencyCode
  //                 }
  //               }
  //             }
  //             shippingAddress {
  //               address1
  //               city
  //               zip
  //               country
  //             }
  //           }
  //         }
  //       }
  //     }
  //     ''';
  //
  //     final data = await _makeCustomerApiRequest(
  //       accessToken: customerAccessToken,
  //       query: ordersQuery,
  //     );
  //
  //     if (data['customer'] != null && data['customer']['orders'] != null) {
  //       final nodes = data['customer']['orders']['nodes'] as List;
  //       return nodes.map((node) {
  //         final order = Map<String, dynamic>.from(node);
  //         order['orderNumber'] = node['name'];
  //         return order;
  //       }).toList();
  //     }
  //     return [];
  //
  //   } catch (e) {
  //     if (kDebugMode) print('Error fetching customer orders: $e');
  //     return [];
  //   }
  // }

  // --- GraphQL Fetch Logic inside ShopifyAuthService ---

  // static Future<List<Map<String, dynamic>>> getCustomerOrdersStorefront(String customerAccessToken) async {
  //   try {
  //     const ordersQuery = r'''
  //   query {
  //     customer {
  //       orders(first: 20, sortKey: PROCESSED_AT, reverse: true) {
  //         nodes {
  //           id
  //           name
  //           processedAt
  //           totalPrice {
  //             amount
  //             currencyCode
  //           }
  //           lineItems(first: 10) {
  //             nodes {
  //               title
  //               quantity
  //               image { url }
  //               price { amount }
  //             }
  //           }
  //         }
  //       }
  //     }
  //   }
  //   ''';
  //
  //     final data = await _makeCustomerApiRequest(
  //       accessToken: customerAccessToken,
  //       query: ordersQuery,
  //     );
  //
  //     if (data['customer'] != null && data['customer']['orders'] != null) {
  //       final List nodes = data['customer']['orders']['nodes'] ?? [];
  //       return nodes.map((node) => Map<String, dynamic>.from(node)).toList();
  //     }
  //     return [];
  //   } catch (e) {
  //     return [];
  //   }
  // }

  static Future<List<Map<String, dynamic>>> getCustomerOrdersStorefront(String customerAccessToken) async {
    try {
      const ordersQuery = r'''
    query {
      customer {
        orders(first: 20, sortKey: PROCESSED_AT, reverse: true) {
          nodes {
            id
            name 
            processedAt
            totalPrice {
              amount
              currencyCode
            }
            lineItems(first: 20) {
              nodes {
                title
                quantity
                variantTitle
                image { url }
                price { 
                  amount 
                  currencyCode 
                }
              }
            }
            shippingAddress {
              firstName
              lastName
              name
              address1
              address2
              city
              province
              country
              zip
              phoneNumber # 👈 FIXED: Removed { phoneNumber } because this is a String here
            }
          }
        }
      }
    }
    ''';

      final data = await _makeCustomerApiRequest(
        accessToken: customerAccessToken,
        query: ordersQuery,
      );

      if (data['customer'] != null && data['customer']['orders'] != null) {
        final List nodes = data['customer']['orders']['nodes'] ?? [];
        return nodes.map((node) {
          final order = Map<String, dynamic>.from(node);

          // --- Standardize for UI ---
          if (order['shippingAddress'] != null) {
            // Map 'phoneNumber' string to 'phone' so your UI finds it
            order['shippingAddress']['phone'] = order['shippingAddress']['phoneNumber'];
          }

          order['orderNumber'] = node['name'];
          return order;
        }).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Error fetching customer orders: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> _makeCustomerApiRequest({
    required String accessToken,
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    final url = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2024-04/graphql');

    final headers = {
      'Content-Type': 'application/json',
      // DO NOT add "Bearer ". The shcat_ token is used directly.
      'Authorization': accessToken.trim(),
      'X-Shopify-Customer-Account-Api-Version': '2024-04',
    };

    final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'query': query, 'variables': variables ?? {}})
    );

    final responseData = jsonDecode(response.body);
    if (responseData['errors'] != null) {
      throw Exception(responseData['errors'][0]['message']);
    }
    return responseData['data'] ?? {};
  }

  // ===========================================================================
  // 🚪 LOGOUT
  // ===========================================================================

  static Future<void> logout() async {
    try {
      // 1. Get ID Token (Required by Shopify to verify WHO is logging out)
      String? idToken = await _storage.read(key: 'id_token');

      // 2. Clear Local Data FIRST
      // We clean up the app state immediately so it's ready even if the network fails later.
      await _storage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (idToken != null) {
        // 3. Construct the Logout URL
        // We pass 'post_logout_redirect_uri' so Shopify knows where to send the user back.
        final logoutUri = Uri.parse('https://shopify.com/$_shopId/auth/logout').replace(queryParameters: {
          'id_token_hint': idToken,
          'post_logout_redirect_uri': _redirectUrl, // This is 'shop.69603295509.app://callback'
        });

        try {
          if (kDebugMode) print("🚀 Launching Logout Flow: $logoutUri");

          // 4. Authenticate (Wait for the Redirect)
          // This opens the browser, clears cookies, and waits for Shopify to hit the callback scheme.
          await FlutterWebAuth2.authenticate(
            url: logoutUri.toString(),
            callbackUrlScheme: 'shop.69603295509.app', // MUST match the scheme in your redirect URL
          );

          // If we reach here, the browser closed automatically!
        } catch (e) {
          // If the user manually closes the browser or hits back, we catch it here.
          // Since we already cleared local data in Step 2, this is fine.
          if (kDebugMode) print("⚠️ Browser closed by user or error: $e");
        }
      }

      if (kDebugMode) print('✅ Logout flow complete.');
    } catch (e) {
      if (kDebugMode) print("❌ Logout error: $e");
    }
  }
  // static Future<void> logout() async {
  //   try {
  //     // 1. Clear Secure Storage (Access Token, ID Token)
  //     await _storage.deleteAll();
  //
  //     // 2. Clear Shared Preferences (Cached User Data)
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.clear();
  //
  //     // 3. Clear Browser Session inside the app
  //     // We use inAppWebView so the user stays in the app context.
  //     final logoutUri = Uri.parse('https://shopify.com/$_shopId/auth/logout');
  //
  //     if (await canLaunchUrl(logoutUri)) {
  //       await launchUrl(
  //         logoutUri,
  //         mode: LaunchMode.inAppWebView, // 🟢 FIX: Do not use externalApplication
  //         webViewConfiguration: const WebViewConfiguration(
  //           enableJavaScript: true,
  //         ),
  //       );
  //     }
  //
  //     if (kDebugMode) print('✅ Local data cleared and session logout triggered.');
  //   } catch (e) {
  //     if (kDebugMode) print("❌ Logout error: $e");
  //   }
  // }

  // ===========================================================================
  // 🛠️ HELPER: CUSTOMER API REQUEST (GraphQL)
  // ===========================================================================

  // static Future<Map<String, dynamic>> _makeCustomerApiRequest({
  //   required String accessToken,
  //   required String query,
  //   Map<String, dynamic>? variables,
  // }) async {
  //   final url = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2026-01/graphql');
  //
  //   final headers = {
  //     'Content-Type': 'application/json',
  //     'Authorization': accessToken, // No 'Bearer' prefix for shcat_ tokens
  //     'X-Shopify-Customer-Account-Api-Version': '2026-01',
  //   };
  //
  //   final body = jsonEncode({
  //     'query': query,
  //     'variables': variables ?? {},
  //   });
  //
  //   final response = await http.post(url, headers: headers, body: body);
  //   final responseData = jsonDecode(response.body);
  //
  //   if (responseData['errors'] != null) {
  //     final errors = responseData['errors'] as List;
  //     throw Exception('GraphQL Error: ${errors.map((e) => e['message']).join(', ')}');
  //   }
  //
  //   if (responseData['data'] == null) {
  //     throw Exception('API returned null data.');
  //   }
  //
  //   return responseData['data'];
  // }

  // ===========================================================================
  // 🛡️ HELPER: ADMIN API REQUEST (REST - Self-Healing)
  // ===========================================================================

  static Future<http.Response> _makeShopifyAdminRequest(
      String endpoint, {
        String method = 'GET',
        Map<String, dynamic>? body,
        bool isRetry = false,
      }) async {

    try {
      final uri = Uri.https(shopifyStoreUrl, '/admin/api/$adminApiVersion/$endpoint');
      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken,
      };

      if (kDebugMode) print('Admin Request ($method): $uri');

      http.Response response;
      switch (method) {
        case 'GET': response = await http.get(uri, headers: headers); break;
        case 'POST': response = await http.post(uri, headers: headers, body: json.encode(body)); break;
        case 'PUT': response = await http.put(uri, headers: headers, body: json.encode(body)); break;
        case 'DELETE': response = await http.delete(uri, headers: headers); break;
        default: return http.Response('{"error": "Unsupported method"}', 400);
      }

      // 🔄 AUTO-REFRESH LOGIC
      if (response.statusCode == 401 && !isRetry) {
        if (kDebugMode) print("⚠️ 401 Unauthorized. Refreshing token...");
        bool refreshed = await ShopifyService.initToken();
        if (refreshed) {
          return _makeShopifyAdminRequest(endpoint, method: method, body: body, isRetry: true);
        }
      }

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Admin Request Error: $e');
      return http.Response('{"error": "Network exception"}', 500);
    }
  }

  // ===========================================================================
  // 👤 PROFILE UPDATE METHODS (Customer Account API)
  // ===========================================================================

  static Future<void> updateCustomerStorefront({
    required String customerAccessToken,
    String? firstName,
    String? lastName,
    String? password,
    String? phone,
  }) async {
    try {
      if (kDebugMode) {
        print('--- 👤 Shopify Profile Update Start ---');
      }

      // 1. Correct Mutation (removed phoneNumber from return selection if you aren't updating it)
      const mutation = r'''
      mutation customerUpdate($input: CustomerUpdateInput!) {
        customerUpdate(input: $input) {
          customer { 
            firstName 
            lastName 
          }
          userErrors { 
            field 
            message 
          }
        }
      }
    ''';

      final Map<String, dynamic> input = {};
      if (firstName != null && firstName.isNotEmpty) input['firstName'] = firstName;
      if (lastName != null && lastName.isNotEmpty) input['lastName'] = lastName;

      // Password usually cannot be updated here in the new API either,
      // but we leave it if you want to try. Usually, it's ignored or fails safely.
      if (password != null && password.isNotEmpty) input['password'] = password;

      // ❌ REMOVE THIS BLOCK ❌
      // The Customer Account API does NOT allow updating phoneNumber here.
      /*
      if (phone != null && phone.isNotEmpty) {
        String formattedPhone = phone.trim();
        if (formattedPhone.startsWith('0')) {
          formattedPhone = '+92${formattedPhone.substring(1)}';
        } else if (!formattedPhone.startsWith('+')) {
          formattedPhone = '+92$formattedPhone';
        }
        input['phoneNumber'] = formattedPhone;
      }
      */

      if (kDebugMode) print('📤 Sending Final Input Variables: $input');

      final data = await _makeCustomerApiRequest(
        accessToken: customerAccessToken,
        query: mutation,
        variables: {'input': input},
      );

      if (kDebugMode) print('📥 Full Response Data: $data');

      if (data['customerUpdate'] != null) {
        final result = data['customerUpdate'];
        final userErrors = result['userErrors'] as List?;

        if (userErrors != null && userErrors.isNotEmpty) {
          throw Exception(userErrors[0]['message']);
        }
        if (kDebugMode) print('✅ Profile updated successfully!');
      }
    } catch (e) {
      if (kDebugMode) print('🔥 Critical Error: $e');
      rethrow;
    }
  }

  static Future<void> createCustomerAddress({
    required String customerAccessToken,
    required Map<String, dynamic> addressInput,
  }) async {
    const mutation = '''
      mutation customerAddressCreate(\$address: CustomerAddressInput!) {
        customerAddressCreate(address: \$address) {
          customerAddress { id }
          userErrors { field message }
        }
      }
    ''';

    final data = await _makeCustomerApiRequest(
      accessToken: customerAccessToken,
      query: mutation,
      variables: {'address': addressInput},
    );

    final result = data['customerAddressCreate'];
    if (result['userErrors'] != null && (result['userErrors'] as List).isNotEmpty) {
      throw Exception(result['userErrors'][0]['message']);
    }
  }

  static Future<void> updateCustomerAddress({
    required String customerAccessToken,
    required String addressId,
    required Map<String, dynamic> addressInput,
  }) async {
    const mutation = '''
      mutation customerAddressUpdate(\$addressId: ID!, \$address: CustomerAddressInput!) {
        customerAddressUpdate(addressId: \$addressId, address: \$address) {
          customerAddress { id }
          userErrors { field message }
        }
      }
    ''';

    final data = await _makeCustomerApiRequest(
      accessToken: customerAccessToken,
      query: mutation,
      variables: {'addressId': addressId, 'address': addressInput},
    );

    final result = data['customerAddressUpdate'];
    if (result['userErrors'] != null && (result['userErrors'] as List).isNotEmpty) {
      throw Exception(result['userErrors'][0]['message']);
    }
  }
  // ---------------------------------------------------------------------------
  // 🗑️ DELETE CUSTOMER (Admin API - Smart Handle)
  // ---------------------------------------------------------------------------
  static Future<bool> deleteCustomer(String customerId) async {
    try {
      // 1. Clean ID (Remove gid://shopify/Customer/...)
      String numericId = customerId;
      if (customerId.contains('/')) {
        numericId = customerId.split('/').last;
      }

      print("🗑️ Attempting to delete Shopify customer: $numericId");

      final response = await _makeShopifyAdminRequest(
        'customers/$numericId.json',
        method: 'DELETE',
      );

      // ✅ SUCCESS (200): Customer deleted permanently.
      if (response.statusCode == 200) {
        if (kDebugMode) print("✅ Shopify Customer Deleted Permanently.");
        return true;
      }

      // ⚠️ PARTIAL SUCCESS (422): Customer has orders, cannot hard delete.
      // We return TRUE here so the app proceeds to delete the local account/Laravel data
      // effectively treating this as a "Deactivation".
      else if (response.statusCode == 422) {
        if (kDebugMode) print("⚠️ Customer has orders. Cannot hard delete from Shopify. Proceeding with Soft Delete.");
        return true;
      }

      // ❌ FAILURE
      if (kDebugMode) print("❌ Delete failed. Status: ${response.statusCode}");
      return false;

    } catch (e) {
      if (kDebugMode) print("❌ Delete Exception: $e");
      return false;
    }
  }

  static Future<void> deleteCustomerAddress(
      String customerAccessToken, String addressId) async {
    const mutation = '''
      mutation customerAddressDelete(\$addressId: ID!) {
        customerAddressDelete(addressId: \$addressId) {
          deletedAddressId
          userErrors { field message }
        }
      }
    ''';

    final data = await _makeCustomerApiRequest(
      accessToken: customerAccessToken,
      query: mutation,
      variables: {'addressId': addressId},
    );

    final result = data['customerAddressDelete'];
    if (result['userErrors'] != null && (result['userErrors'] as List).isNotEmpty) {
      throw Exception(result['userErrors'][0]['message']);
    }
  }

  // ===========================================================================
  // ⚙️ ADMIN API METHODS (Registration, Discounts)
  // ===========================================================================

  static Future<Map<String, dynamic>?> registerCustomer(
      String firstName, String lastName, String email, String password) async {
    final body = {
      'customer': {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'send_email_welcome': true,
      }
    };

    final response = await _makeShopifyAdminRequest('customers.json', method: 'POST', body: body);
    if (response.statusCode == 201) return jsonDecode(response.body)['customer'];
    return null;
  }

  static Future<Map<String, dynamic>> validateShopifyDiscountCode(String code) async {
    if (code.isEmpty) return {'valid': false, 'message': 'Code empty'};

    try {
      if (kDebugMode) print("🎟️ Looking up coupon: $code");

      // 1. Construct the URL carefully
      // Use Uri.https to let Dart handle the formatting correctly
      final queryParameters = {'code': code.trim()};
      final uri = Uri.https(
          shopifyStoreUrl,
          '/admin/api/$adminApiVersion/discount_codes/lookup.json',
          queryParameters
      );

      if (kDebugMode) print('🔗 Corrected URL: $uri');

      // 2. Make the lookup request
      final lookupRes = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': adminAccessToken,
        },
      );

      if (lookupRes.statusCode != 200) {
        if (kDebugMode) print('❌ Lookup failed: ${lookupRes.statusCode}');
        return {'valid': false, 'message': 'Coupon not found.'};
      }

      final lookupData = json.decode(lookupRes.body);
      final priceRuleId = lookupData['discount_code']['price_rule_id'];

      // 3. Get the price rule details
      final ruleUri = Uri.https(
          shopifyStoreUrl,
          '/admin/api/$adminApiVersion/price_rules/$priceRuleId.json'
      );

      final ruleRes = await http.get(
        ruleUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': adminAccessToken,
        },
      );

      if (ruleRes.statusCode != 200) return {'valid': false, 'message': 'Coupon details error.'};

      final priceRule = json.decode(ruleRes.body)['price_rule'];
      final value = (double.tryParse(priceRule['value'].toString()) ?? 0.0).abs();

      return {
        'valid': true,
        'message': 'Coupon applied!',
        'value': value,
        'value_type': priceRule['value_type'], // "percentage" or "fixed_amount"
      };
    } catch (e) {
      if (kDebugMode) print("🔥 Coupon Logic Error: $e");
      return {'valid': false, 'message': 'Validation system error.'};
    }
  }

  // --- Check First Order Discount ---
  static Future<Map<String, dynamic>?> checkFirstOrderDiscount(String email) async {
    try {
      // 1. Check Orders
      final orderRes = await _makeShopifyAdminRequest('customers/search.json?query=email:$email');
      if (orderRes.statusCode == 200) {
        final customers = jsonDecode(orderRes.body)['customers'] as List;
        if (customers.isNotEmpty) {
          if (customers.first['orders_count'] > 0) {
            return {'eligible': false, 'message': 'Not valid for existing customers.'};
          }
        }
      }
      return {'eligible': true, 'message': 'Eligible for first order discount!'};
    } catch (e) {
      return {'eligible': false, 'message': 'Verification failed.'};
    }
  }
}


// // import 'dart:convert';
// // import 'package:achhafoods/screens/Consts/conts.dart';
// // import 'package:flutter_appauth/flutter_appauth.dart';
// // import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:flutter/foundation.dart'; // For kDebugMode
// // import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
// // class ShopifyAuthService {
// //
// // static const FlutterAppAuth _appAuth = FlutterAppAuth();
// // static const FlutterSecureStorage _storage = FlutterSecureStorage();
// //
// // // 🔴 PASTE YOUR CLIENT ID HERE (From Shopify Admin)
// // static const String _clientId = 'c01bcd45-7b27-49c1-b414-2a4e49f38079';
// //
// // // ✅ YOUR SHOP ID
// // static const String _shopId = '69603295509';
// //
// // static const String _redirectUrl = 'shop.$_shopId.app://callback';
// // static const String _logoutUrl = 'shop.$_shopId://logout';
// // static const String _authorizationUrl = 'https://shopify.com/$_shopId/auth/oauth/authorize';
// // static const String _tokenUrl = 'https://shopify.com/$_shopId/auth/oauth/token';
// //
// // static String storefrontAccessToken = adminAccessToken_const;
// // static const String shopifyStoreUrl = shopifyStoreUrl_const;
// // static const String storefrontApiVersion = storefrontApiVersion_const;
// // static String adminAccessToken = adminAccessToken_const;
// // static const String adminApiVersion = adminApiVersion_const;
// //
// // /// 🟢 **LOGIN WITH SHOPIFY (OAUTH)**
// // /// Opens the browser, logs the user in, and returns the Access Token.
// // static Future<Map<String, dynamic>?> loginWithShopify() async {
// //   try {
// //     if (kDebugMode) print("🚀 Starting Shopify OAuth Login...");
// //
// //     final AuthorizationTokenResponse? result = await _appAuth.authorizeAndExchangeCode(
// //       AuthorizationTokenRequest(
// //         _clientId,
// //         _redirectUrl,
// //         serviceConfiguration: const AuthorizationServiceConfiguration(
// //           authorizationEndpoint: _authorizationUrl,
// //           tokenEndpoint: _tokenUrl,
// //         ),
// //         scopes: ['openid', 'email', 'https://api.customers.com/auth/customer.graphql'],
// //       ),
// //     );
// //
// //     if (result != null && result.accessToken != null) {
// //       if (kDebugMode) print("✅ OAuth Success! Token: ${result.accessToken}");
// //
// //       // Save secure tokens
// //       await _storage.write(key: 'customer_access_token', value: result.accessToken);
// //       await _storage.write(key: 'id_token', value: result.idToken);
// //
// //       // Fetch Customer Details using the new token
// //       // Note: The new Customer Account API uses a different query structure
// //       // But for compatibility with your app, we will try to fetch basic details
// //       // or construct the customer object from the ID Token if possible.
// //
// //       // For now, we will use the fetch detail function.
// //       // NOTE: You might need to update getCustomerDetails to support the new API endpoint
// //       // 'https://shopify.com/$_shopId/account/customer/api/2026-01/graphql'
// //       // depending on how strict your permissions are.
// //
// //       // Return a basic map to satisfy the login flow
// //       return await getCustomerDetails(result.accessToken!);
// //     }
// //   } catch (e) {
// //     if (kDebugMode) print("💥 OAuth Error: $e");
// //   }
// //   return null;
//
//
// import 'dart:convert';
// import 'dart:math';
// import 'package:achhafoods/screens/Consts/conts.dart';
// import 'package:crypto/crypto.dart';
// import 'package:flutter_appauth/flutter_appauth.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/foundation.dart'; // For kDebugMode
// import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class ShopifyAuthService {
//   static const FlutterAppAuth _appAuth = FlutterAppAuth();
//   static const FlutterSecureStorage _storage = FlutterSecureStorage();
//
//   // 🔴 PASTE YOUR CLIENT ID HERE (Matches image_5eb22d.png)
//   static const String _clientId = 'c01bcd45-7b27-49c1-b414-2a4e49f38079';
//
//   // ✅ YOUR SHOP ID
//   static const String _shopId = '69603295509';
//
//   // ✅ IMPORTANT: Redirect URI must match what's configured in your Shopify app
//   static const String _redirectUrl = 'shop.69603295509.app://callback';
//
//   // API Configuration
//   static String storefrontAccessToken = adminAccessToken_const;
//   static const String shopifyStoreUrl = shopifyStoreUrl_const;
//   static const String storefrontApiVersion = storefrontApiVersion_const;
//   static String adminAccessToken = adminAccessToken_const;
//   static const String adminApiVersion = adminApiVersion_const;
//
//   /// 🔐 HELPER: Generate PKCE Verifier
//   static String _generateCodeVerifier() {
//     final random = Random.secure();
//     final values = List<int>.generate(32, (i) => random.nextInt(256));
//     return base64UrlEncode(values).replaceAll('=', '');
//   }
//
//   /// 🔐 HELPER: Generate PKCE Challenge
//   static String _generateCodeChallenge(String codeVerifier) {
//     final bytes = utf8.encode(codeVerifier);
//     final digest = sha256.convert(bytes);
//     return base64UrlEncode(digest.bytes).replaceAll('=', '');
//   }
//
//   /// 🟢 **LOGIN WITH SHOPIFY (Customer Account API w/ PKCE) - UPDATED PER DOCS**
//   static Future<Map<String, dynamic>?> loginWithShopify() async {
//     try {
//       if (kDebugMode) print('🚀 Starting Shopify Customer OAuth...');
//
//       // 1. Generate PKCE Codes
//       final codeVerifier = _generateCodeVerifier();
//       final codeChallenge = _generateCodeChallenge(codeVerifier);
//       final state = _generateRandomString(32); // Random state for security
//
//       // 2. Build the Auth URL according to Shopify docs
//       // Docs: https://shopify.dev/docs/api/customer/latest/authentication/oauth
//       final authUri = Uri.parse('https://shopify.com/$_shopId/auth/oauth/authorize').replace(queryParameters: {
//         'client_id': _clientId,
//         'scope': 'openid email https://api.customers.com/auth/customer.graphql',
//         'redirect_uri': _redirectUrl,
//         'response_type': 'code',
//         'state': state,
//         // PKCE parameters as per docs
//         'code_challenge': codeChallenge,
//         'code_challenge_method': 'S256',
//       });
//
//       if (kDebugMode) {
//         print('🔗 Auth URL: $authUri');
//         print('📱 Redirect URI: $_redirectUrl');
//         print('🔐 Code Verifier: $codeVerifier');
//         print('🔐 Code Challenge: $codeChallenge');
//       }
//
//       // 3. Launch Web Auth with proper configuration
//       final result = await FlutterWebAuth2.authenticate(
//         url: authUri.toString(),
//         callbackUrlScheme: 'shop.69603295509.app',
//         // Important parameters for iOS/Android
//         // preferEphemeral: false, // Set to true for incognito mode
//       );
//
//       // 4. Parse the callback URL
//       final callbackUri = Uri.parse(result);
//       if (kDebugMode) print('🔗 Callback URI received: $callbackUri');
//
//       final code = callbackUri.queryParameters['code'];
//       final error = callbackUri.queryParameters['error'];
//       final returnedState = callbackUri.queryParameters['state'];
//
//       // Validate state to prevent CSRF
//       if (returnedState != state) {
//         throw Exception('State mismatch - possible CSRF attack');
//       }
//
//       if (error != null) {
//         final errorDescription = callbackUri.queryParameters['error_description'];
//         throw Exception('OAuth Error: $error - $errorDescription');
//       }
//
//       if (code == null) throw Exception('No authorization code received');
//
//       if (kDebugMode) print('✅ Authorization Code received: $code');
//
//       // 5. Exchange Code for Token (Token endpoint as per docs)
//       final tokenUrl = Uri.parse('https://shopify.com/$_shopId/auth/oauth/token');
//
//       final tokenResponse = await http.post(
//         tokenUrl,
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: {
//           'grant_type': 'authorization_code',
//           'client_id': _clientId,
//           'redirect_uri': _redirectUrl,
//           'code': code,
//           // ⬇️ CRITICAL: Send the verifier to prove identity
//           'code_verifier': codeVerifier,
//         },
//       );
//
//       if (kDebugMode) {
//         print('📦 Token Response Status: ${tokenResponse.statusCode}');
//         print('📦 Token Response Body: ${tokenResponse.body}');
//       }
//
//       if (tokenResponse.statusCode != 200) {
//         throw Exception('Token Exchange Failed (${tokenResponse.statusCode}): ${tokenResponse.body}');
//       }
//
//       final tokenData = jsonDecode(tokenResponse.body);
//       final accessToken = tokenData['access_token'];
//       final idToken = tokenData['id_token'];
//       final expiresIn = tokenData['expires_in'];
//
//       if (accessToken == null) throw Exception('No access token in response');
//
//       // 6. Save tokens securely
//       await _storage.write(key: 'customer_access_token', value: accessToken);
//       if (idToken != null) {
//         await _storage.write(key: 'id_token', value: idToken);
//       }
//
//       // Calculate expiration
//       if (expiresIn != null) {
//         final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
//         await _storage.write(key: 'token_expires_at', value: expiresAt.toIso8601String());
//       }
//
//       // 7. Fetch customer data using the Customer Account API
//       final customerData = await getCustomerDetails(accessToken);
//
//       if (customerData == null) {
//         throw Exception('Failed to fetch customer data after login');
//       }
//
//       return customerData;
//
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ Shopify OAuth Error: $e');
//         print('❌ Stack trace: ${e.toString()}');
//       }
//       rethrow;
//     }
//   }
//
//   /// Helper to generate random string for state
//   static String _generateRandomString(int length) {
//     const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
//     final random = Random.secure();
//     return String.fromCharCodes(
//         Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
//     );
//   }
//
//   /// 🟢 **GET CUSTOMER DETAILS (Customer Account API)**
//   /// Docs: https://shopify.dev/docs/api/customer/latest/queries/customer
//   static Future<Map<String, dynamic>?> getCustomerDetails(String customerAccessToken) async {
//     try {
//       // Customer Account API endpoint as per docs
//       final queryUrl = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2026-01/graphql');
//
// // NEW (Correct)
//       final headers = {
//         'Content-Type': 'application/json',
//         // Shopify checks if the header string starts immediately with 'shcat_',
//         // so 'Bearer ' causes the "missing prefix" error.
//         'Authorization': customerAccessToken,
//         'X-Shopify-Customer-Account-Api-Version': '2026-01',
//       };
//
//       // Query as per Customer Account API documentation
//       final customerQuery = '''
//         query {
//           customer {
//             id
//             firstName
//             lastName
//             emailAddress {
//               emailAddress
//             }
//             phoneNumber {
//               phoneNumber
//             }
//             defaultAddress {
//               id
//               address1
//               address2
//               city
//               province
//               # countryCodeV2 is invalid in this API version
//               country
//               zip
//             }
//             addresses(first: 10) {
//               nodes {
//                 id
//                 address1
//                 address2
//                 city
//                 province
//                 # countryCodeV2 is invalid in this API version
//                 country
//                 zip
//               }
//             }
//           }
//         }
//       ''';
//
//       if (kDebugMode) {
//         print('🔍 Customer API Request: $queryUrl');
//         print('🔍 Headers: $headers');
//       }
//
//       final response = await http.post(
//         queryUrl,
//         headers: headers,
//         body: jsonEncode({'query': customerQuery}),
//       );
//
//       if (kDebugMode) {
//         print('🔍 Customer API Response Status: ${response.statusCode}');
//         print('🔍 Customer API Response Body: ${response.body}');
//       }
//
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//
//         // Check for GraphQL errors
//         if (responseData['errors'] != null) {
//           final errors = responseData['errors'] as List;
//           throw Exception('GraphQL Errors: ${errors.map((e) => e['message']).join(', ')}');
//         }
//
//         if (responseData['data'] != null && responseData['data']['customer'] != null) {
//           final rawCust = responseData['data']['customer'];
//
//           // Map to your app's expected format
//           final mappedCustomer = {
//             'id': rawCust['id'],
//             'firstName': rawCust['firstName'] ?? '',
//             'lastName': rawCust['lastName'] ?? '',
//             'email': rawCust['emailAddress']?['emailAddress'] ?? '',
//             'phone': rawCust['phoneNumber']?['phoneNumber'] ?? '',
//             'defaultAddress': rawCust['defaultAddress'],
//             'addresses': rawCust['addresses']?['nodes'] ?? [],
//           };
//
//           final prefs = await SharedPreferences.getInstance();
//           final Map<String, dynamic> fullCustomerData = {
//             'accessToken': customerAccessToken,
//             'customer': mappedCustomer,
//             'timestamp': DateTime.now().toIso8601String(),
//           };
//
//           await prefs.setString('customerData', json.encode(fullCustomerData));
//           await prefs.setString('shopifyCustomer', json.encode(fullCustomerData));
//
//           if (kDebugMode) print('✅ Customer data saved successfully');
//           return fullCustomerData;
//         }
//       } else if (response.statusCode == 401) {
//         // Token expired or invalid
//         throw Exception('Access token is invalid or expired. Please login again.');
//       } else {
//         throw Exception('Customer API Error (${response.statusCode}): ${response.body}');
//       }
//     } catch (e) {
//       if (kDebugMode) print('❌ Error in getCustomerDetails: $e');
//       rethrow;
//     }
//     return null;
//   }
//
//   /// 🔄 **REFRESH TOKEN (if supported)**
//   static Future<String?> refreshAccessToken(String refreshToken) async {
//     try {
//       final tokenUrl = Uri.parse('https://shopify.com/$_shopId/auth/oauth/token');
//
//       final response = await http.post(
//         tokenUrl,
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: {
//           'grant_type': 'refresh_token',
//           'client_id': _clientId,
//           'refresh_token': refreshToken,
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final tokenData = jsonDecode(response.body);
//         final accessToken = tokenData['access_token'];
//
//         if (accessToken != null) {
//           await _storage.write(key: 'customer_access_token', value: accessToken);
//           return accessToken;
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) print('❌ Token refresh failed: $e');
//     }
//     return null;
//   }
//
//   /// 🚪 **LOGOUT**
//   static Future<void> logout() async {
//     try {
//       // 1. Clear Secure Storage (Access Token, ID Token)
//       await _storage.deleteAll();
//
//       // 2. Clear Shared Preferences (Cached User Data)
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.clear();
//
//       // 3. Clear Browser Session (Crucial for "Switch Account")
//       // If we don't do this, the next "Login" click will auto-login the same user.
//       final logoutUri = Uri.parse('https://shopify.com/$_shopId/auth/logout');
//
//       try {
//         // We launch this in an external browser (or SFSafariViewController/CustomTabs)
//         // This clears the Shopify session cookie.
//         if (await canLaunchUrl(logoutUri)) {
//           await launchUrl(logoutUri, mode: LaunchMode.externalApplication);
//         }
//       } catch (e) {
//         if (kDebugMode) print("⚠️ Could not launch browser logout: $e");
//       }
//
//       if (kDebugMode) print('✅ Logout completed successfully');
//     } catch (e) {
//       if (kDebugMode) print('❌ Logout error: $e');
//     }
//   }
//
//   /// 🔍 **DEBUG: Test the OAuth URL**
//   static Future<Map<String, dynamic>> testAuthConfiguration() async {
//     final codeVerifier = _generateCodeVerifier();
//     final codeChallenge = _generateCodeChallenge(codeVerifier);
//     final state = _generateRandomString(32);
//
//     final authUri = Uri.parse('https://shopify.com/$_shopId/auth/oauth/authorize').replace(queryParameters: {
//       'client_id': _clientId,
//       'scope': 'openid email https://api.customers.com/auth/customer.graphql',
//       'redirect_uri': _redirectUrl,
//       'response_type': 'code',
//       'state': state,
//       'code_challenge': codeChallenge,
//       'code_challenge_method': 'S256',
//     });
//
//     return {
//       'authUrl': authUri.toString(),
//       'redirectUri': _redirectUrl,
//       'codeVerifier': codeVerifier,
//       'codeChallenge': codeChallenge,
//       'state': state,
//       'clientId': _clientId,
//       'shopId': _shopId,
//     };
//   }
//   /// 🟢 **LOGIN CUSTOMER**
//   /// Authenticates a customer and fetches their profile, including addresses.
//   static Future<Map<String, dynamic>?> loginCustomer(
//       String email, String password) async {
//     try {
//       final authUrl = Uri.https(
//         shopifyStoreUrl,
//         '/admin/api/$storefrontApiVersion/customers.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': storefrontAccessToken,
//       };
//
// // Step 1: Get customerAccessToken
//       const loginMutation = '''
//       mutation customerAccessTokenCreate(\$input: CustomerAccessTokenCreateInput!) {
//         customerAccessTokenCreate(input: \$input) {
//           customerAccessToken {
//             accessToken
//             expiresAt
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final loginResponse = await http.post(
//         authUrl,
//         headers: headers,
//         body: jsonEncode({
//           'query': loginMutation,
//           'variables': {
//             'input': {
//               'email': email,
//               'password': password,
//             },
//           },
//         }),
//       );
//
//       final loginData = json.decode(loginResponse.body);
//       final result = loginData['data']['customerAccessTokenCreate'];
//       final tokenData = result['customerAccessToken'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print('Login response: ${loginResponse.body}');
//       }
//
//       if (tokenData != null) {
//         final accessToken = tokenData['accessToken'] as String;
//
// // Step 2: Fetch comprehensive customer data using the obtained token
//         final customerDetails = await getCustomerDetails(accessToken);
//
//         if (customerDetails != null) {
// // The getCustomerDetails method already saves to SharedPreferences
//           return customerDetails;
//         } else {
//           if (kDebugMode) {
//             print("Failed to fetch comprehensive customer data after login.");
//           }
//           return null; // Customer details couldn't be fetched
//         }
//       } else if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print("Login failed: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception(errors.first['message'] ?? 'Login failed');
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Login error: $e');
//       }
//       rethrow; // Re-throw to be caught by UI for specific error messages
//     }
//     return null;
//   }
//
//
//   /// ❌ **DELETE CUSTOMER (Admin API)**
//   static Future<bool> deleteCustomer(String customerId) async {
//     print("----------------------------------------------------------------");
//     print("🚀 STARTING SHOPIFY DELETE PROCESS");
//     print("----------------------------------------------------------------");
//
//     try {
// // 1. ID Parsing
//       String numericId = customerId;
//       if (customerId.contains('/')) {
//         numericId = customerId.split('/').last;
//       }
//       print("🔍 Original ID: $customerId");
//       print("🔢 Parsed Numeric ID: $numericId");
//
// // 2. URL Construction
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/admin/api/$adminApiVersion/customers/$numericId.json',
//       );
//       print("🌐 Request URL: $url");
//
// // 3. Headers
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       };
// // BE CAREFUL printing tokens in production logs, ok for debug
//       print("🔑 Headers Sent: $headers");
//
// // 4. API Call
//       print("⏳ Sending DELETE request...");
//       final response = await http.delete(url, headers: headers);
//       print("📨 Request Sent.");
//
// // 5. Response Logging
//       print("----------------------------------------------------------------");
//       print("📥 SHOPIFY RESPONSE RECEIVED");
//       print("----------------------------------------------------------------");
//       print("📊 Status Code: ${response.statusCode}");
//       print("📄 Body: ${response.body}");
//       print("----------------------------------------------------------------");
//
//       if (response.statusCode == 200) {
//         if (kDebugMode) print('✅ Customer deleted successfully: $numericId');
//         return true;
//       } else {
// // Handle 422 specifically (Customer has orders)
//         if (response.statusCode == 422) {
//           print("⚠️ ERROR 422 DETECTED: Unprocessable Entity.");
//           print("👉 REASON: This usually means the customer has placed orders.");
//           print("ℹ️ Shopify does not allow deleting customers with financial history.");
//           print("👉 ACTION: The app should proceed to 'Soft Delete' (Local Logout + Laravel Status Update).");
//         } else {
//           print("❌ DELETE FAILED with unexpected status: ${response.statusCode}");
//         }
//         return false;
//       }
//     } catch (e) {
//       print("💥 CRITICAL EXCEPTION in deleteCustomer:");
//       print(e);
//       return false;
//     }
//   }
//
//   static Future<Map<String, dynamic>?> updateCustomerPassword({
//     required String customerId,
//     required String newPassword,
//   }) async {
//     try {
// // Use Admin API REST endpoint instead of Storefront GraphQL
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/admin/api/$adminApiVersion/customers/$customerId.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       };
//
//       final body = {
//         'customer': {
//           'id': customerId,
//           'password': newPassword,
//           'password_confirmation': newPassword,
//         }
//       };
//
//       final response = await http.put(
//         url,
//         headers: headers,
//         body: json.encode(body),
//       );
//
//       final responseBody = json.decode(response.body);
//
//       if (kDebugMode) {
//         print('Shopify Admin Password Update Status: ${response.statusCode}');
//         print('Shopify Admin Password Update Body: $responseBody');
//       }
//
//       if (response.statusCode == 200) {
// // Success - password updated
//         if (kDebugMode) {
//           print('✅ Password updated successfully for customer: $customerId');
//         }
//         return responseBody;
//       } else {
// // Handle errors
//         if (responseBody.containsKey('errors')) {
//           final errors = responseBody['errors'];
//           if (kDebugMode) {
//             print("⚠️ Password update failed: $errors");
//           }
//           throw Exception('Password update failed: $errors');
//         } else {
//           throw Exception('Failed to update password. Status: ${response.statusCode}');
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Shopify Admin password update failed: $e');
//       }
//       rethrow;
//     }
//   }
//
//   static Future<Map<String, dynamic>?> updateCustomerInfo({
//     required String customerId,
//     required String firstName,
//     required String lastName,
//     required String email,
//     required String phone,
//   }) async {
//     try {
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/admin/api/$adminApiVersion/customers/$customerId.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       };
//
//       final body = {
//         'customer': {
//           'id': customerId,
//           'first_name': firstName,
//           'last_name': lastName,
//           'email': email,
//           'phone': phone,
//         }
//       };
//
//       final response = await http.put(
//         url,
//         headers: headers,
//         body: json.encode(body),
//       );
//
//       final responseBody = json.decode(response.body);
//
//       if (kDebugMode) {
//         print('Shopify Admin Customer Update Status: ${response.statusCode}');
//         print('Shopify Admin Customer Update Body: $responseBody');
//       }
//
//       if (response.statusCode == 200) {
//         if (kDebugMode) {
//           print('✅ Customer info updated successfully for customer: $customerId');
//         }
//         return responseBody;
//       } else {
//         if (responseBody.containsKey('errors')) {
//           final errors = responseBody['errors'];
//           if (kDebugMode) {
//             print("⚠️ Customer info update failed: $errors");
//           }
//           throw Exception('Customer info update failed: $errors');
//         } else {
//           throw Exception('Failed to update customer info. Status: ${response.statusCode}');
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Shopify Admin customer info update failed: $e');
//       }
//       rethrow;
//     }}
//
//   static Future<Map<String, dynamic>> validateShopifyDiscountCode(
//       String code) async {
//     if (code.isEmpty) {
//       return {'valid': false, 'message': 'Coupon code cannot be empty.'};
//     }
//
//     try {
// // --- 1. Find the Discount Code to get its Price Rule ID (using direct lookup.json) ---
//       final lookupUri = Uri.parse(
//           'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/discount_codes/lookup.json?code=${Uri.encodeComponent(code)}');
//
//       final lookupResponse = await http.get(
//         lookupUri,
//         headers: {
//           'Content-Type': 'application/json',
//           'X-Shopify-Access-Token': adminAccessToken_const,
//         },
//       );
//
//       if (lookupResponse.statusCode != 200) {
//         if (kDebugMode) print('Discount code lookup failed: ${lookupResponse.statusCode} - ${lookupResponse.body}');
//         return {'valid': false, 'message': 'Invalid or inaccessible coupon code.'};
//       }
//
//       final lookupData = json.decode(lookupResponse.body);
//       final discountCodeData = lookupData['discount_code'] as Map<String, dynamic>?;
//
//       if (discountCodeData == null || discountCodeData['price_rule_id'] == null) {
//         return {'valid': false, 'message': 'Invalid coupon code or rule not found.'};
//       }
//
//       final priceRuleId = discountCodeData['price_rule_id'];
//       final usageCount = (discountCodeData['usage_count'] as num?)?.toInt() ?? 0;
//
//
// // --- 2. Fetch the Price Rule to check eligibility, dates, and value ---
//       final ruleUri = Uri.parse(
//           'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/price_rules/$priceRuleId.json');
//
//       final ruleResponse = await http.get(
//         ruleUri,
//         headers: {
//           'Content-Type': 'application/json',
//           'X-Shopify-Access-Token': adminAccessToken_const,
//         },
//       );
//
//       if (ruleResponse.statusCode != 200) {
//         if (kDebugMode) print('Price rule fetch failed: ${ruleResponse.statusCode} - ${ruleResponse.body}');
//         return {'valid': false, 'message': 'Error retrieving discount details.'};
//       }
//
//       final priceRule = json.decode(ruleResponse.body)['price_rule'] as Map<String, dynamic>;
//
// // Check date validity
//       final now = DateTime.now();
//       final startsAt = DateTime.parse(priceRule['starts_at']);
//       final endsAt = priceRule['ends_at'] != null
//           ? DateTime.parse(priceRule['ends_at'])
//           : null;
//
//       if (now.isBefore(startsAt)) {
//         return {'valid': false, 'message': 'Coupon is not yet active.'};
//       }
//       if (endsAt != null && now.isAfter(endsAt)) {
//         return {'valid': false, 'message': 'Coupon has expired.'};
//       }
//
// // Check usage limits (uses the Price Rule's limit and the Discount Code's count)
//       final usageLimit = (priceRule['usage_limit'] as num?)?.toInt();
//       if (usageLimit != null && usageCount >= usageLimit) {
//         return {'valid': false, 'message': 'Coupon limit reached.'};
//       }
//
// // Determine the discount value (The value field is typically negative for discounts, so we take the absolute value)
// // FIX: Safely convert the 'value' field from String (which Shopify often returns) to double.
//       final rawValue = priceRule['value'].toString();
//       final value = (double.tryParse(rawValue) ?? 0.0).abs();
//
//       final valueType = priceRule['value_type']; // 'fixed_amount' or 'percentage'
//
//       return {
//         'valid': true,
//         'message': 'Coupon applied successfully!',
//         'value': value,
//         'value_type': valueType,
//       };
//     } catch (e) {
//       if (kDebugMode) print('Shopify discount validation error: $e');
//       return {'valid': false, 'message': 'An unexpected error occurred.'};
//     }
//   }
//   /// ✅ **VALIDATE PASSWORD**
//   /// Uses the login mutation to check if credentials are valid without returning a token.
//   static Future<bool> validatePassword(String email, String password) async {
//     try {
//       final authUrl = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       const loginMutation = '''
//       mutation customerAccessTokenCreate(\$input: CustomerAccessTokenCreateInput!) {
//         customerAccessTokenCreate(input: \$input) {
//           customerAccessToken {
//             accessToken
//             expiresAt
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         authUrl,
//         headers: headers,
//         body: jsonEncode({
//           'query': loginMutation,
//           'variables': {
//             'input': {
//               'email': email,
//               'password': password,
//             },
//           },
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//       final result = responseData['data']['customerAccessTokenCreate'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print("Password validation response: ${response.body}");
//       }
//
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print(
//               "Password validation errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         return false; // Authentication failed
//       }
//
//       final customerAccessToken = result['customerAccessToken'];
//       return customerAccessToken !=
//           null; // Password is valid if a token is returned
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error validating password: $e');
//       }
//       return false;
//     }
//   }
//
//   /// 🔄 **UPDATE CUSTOMER (Personal Info & Password)**
//   /// Updates `firstName`, `lastName`, and `password` for a customer via Storefront API.
//   /// Does NOT directly handle email, phone, or address updates.
//   static Future<Map<String, dynamic>?> updateCustomerStorefront({
//     required String customerAccessToken,
//     String? firstName,
//     String? lastName,
//     String? password,
// // Email updates are complex and usually require re-verification or are handled
// // by specific apps/Admin API. Avoid direct updates here unless Shopify's
// // Storefront API explicitly supports it with a clear flow.
// // String? email,
//   }) async {
//     try {
//       final updateUrl = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       final Map<String, dynamic> customerInput = {};
//       if (firstName != null && firstName.isNotEmpty) {
//         customerInput['firstName'] = firstName;
//       }
//       if (lastName != null && lastName.isNotEmpty) {
//         customerInput['lastName'] = lastName;
//       }
//       if (password != null && password.isNotEmpty) {
//         customerInput['password'] = password;
//       }
//
//       const updateMutation = '''
//       mutation customerUpdate(\$customerAccessToken: String!, \$customer: CustomerUpdateInput!) {
//         customerUpdate(customerAccessToken: \$customerAccessToken, customer: \$customer) {
//           customer {
//             id
//             firstName
//             lastName
//             email
//             phone
//             defaultAddress { # Query default address to get latest state
//               id
//               address1
//               address2
//               city
//               province
//               zip
//               country
//               phone
//               name # Include name from address
//             }
//           }
//           customerAccessToken {
//             accessToken
//             expiresAt
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         updateUrl,
//         headers: headers,
//         body: jsonEncode({
//           'query': updateMutation,
//           'variables': {
//             'customerAccessToken': customerAccessToken,
//             'customer': customerInput,
//           },
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//       final result = responseData['data']['customerUpdate'];
//       final updatedCustomer = result['customer'];
//       final newAccessTokenData = result['customerAccessToken'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print("Shopify Customer Update Request Body: ${jsonEncode({
//           'query': updateMutation,
//           'variables': {
//             'customerAccessToken': customerAccessToken,
//             'customer': customerInput
//           }
//         })}");
//         print(
//             "Shopify Customer Update Response Status: ${response.statusCode}");
//         print("Shopify Customer Update Response Body: ${response.body}");
//       }
//
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print(
//               "Update customer storefront errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception(
//             'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
//       }
//
//       if (updatedCustomer != null) {
// // Save the *entire updated customer object* received from Shopify,
// // which now includes the latest personal info and defaultAddress data.
//         final prefs = await SharedPreferences.getInstance();
//         final Map<String, dynamic> customerDataToSave = {
//           'accessToken':
//           newAccessTokenData?['accessToken'] ?? customerAccessToken,
//           'expiresAt': newAccessTokenData?['expiresAt'],
//           'customer': updatedCustomer,
//         };
//         await prefs.setString('customerData', json.encode(customerDataToSave));
//         if (kDebugMode) {
//           print(
//               "Updated customer data saved to SharedPreferences: $customerDataToSave");
//         }
//         return customerDataToSave; // Return the full structure
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Update customer storefront error: $e');
//       }
//       rethrow;
//     }
//     return null;
//   }
//
//   /// 🔄 **CREATE CUSTOMER ADDRESS**
//   /// Adds a new address for the customer.
//   static Future<Map<String, dynamic>?> createCustomerAddress({
//     required String customerAccessToken,
//     required Map<String, dynamic> addressInput,
//   }) async {
//     try {
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       const createAddressMutation = '''
//       mutation customerAddressCreate(\$customerAccessToken: String!, \$address: MailingAddressInput!) {
//         customerAddressCreate(customerAccessToken: \$customerAccessToken, address: \$address) {
//           customerAddress {
//             id
//             address1
//             address2
//             city
//             province
//             zip
//             country
//             phone
//             name
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         url,
//         headers: headers,
//         body: jsonEncode({
//           'query': createAddressMutation,
//           'variables': {
//             'customerAccessToken': customerAccessToken,
//             'address': addressInput,
//           },
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//       final result = responseData['data']['customerAddressCreate'];
//       final newAddress = result['customerAddress'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print("Create Customer Address Response: ${response.body}");
//       }
//
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print(
//               "Create customer address errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception(
//             'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
//       }
//
//       return newAddress;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error creating customer address: $e');
//       }
//       rethrow;
//     }
//   }
//
//   /// 🔄 **UPDATE CUSTOMER ADDRESS**
//   /// Modifies an existing address for the customer.
//   static Future<Map<String, dynamic>?> updateCustomerAddress({
//     required String customerAccessToken,
//     required String addressId,
//     required Map<String, dynamic> addressInput,
//   }) async {
//     try {
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       const updateAddressMutation = '''
//       mutation customerAddressUpdate(\$customerAccessToken: String!, \$id: ID!, \$address: MailingAddressInput!) {
//         customerAddressUpdate(customerAccessToken: \$customerAccessToken, id: \$id, address: \$address) {
//           customerAddress {
//             id
//             address1
//             address2
//             city
//             province
//             zip
//             country
//             phone
//             name
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         url,
//         headers: headers,
//         body: jsonEncode({
//           'query': updateAddressMutation,
//           'variables': {
//             'customerAccessToken': customerAccessToken,
//             'id': addressId,
//             'address': addressInput,
//           },
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//       final result = responseData['data']['customerAddressUpdate'];
//       final updatedAddress = result['customerAddress'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print("Update Customer Address Response: ${response.body}");
//       }
//
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print(
//               "Update customer address errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception(
//             'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
//       }
//
//       return updatedAddress;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error updating customer address: $e');
//       }
//       rethrow;
//     }
//   }
//
//   /// 🔄 **SET DEFAULT CUSTOMER ADDRESS**
//   /// Sets a specific address as the customer's default.
//   static Future<bool> customerDefaultAddressUpdate({
//     required String customerAccessToken,
//     required String addressId,
//   }) async {
//     try {
//       final url = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       const defaultAddressMutation = '''
//       mutation customerDefaultAddressUpdate(\$customerAccessToken: String!, \$addressId: ID!) {
//         customerDefaultAddressUpdate(customerAccessToken: \$customerAccessToken, addressId: \$addressId) {
//           customer {
//             id
//             defaultAddress { # Query default address to get latest state
//               id
//               address1
//               name
//             }
//           }
//           customerUserErrors {
//             field
//             message
//           }
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         url,
//         headers: headers,
//         body: jsonEncode({
//           'query': defaultAddressMutation,
//           'variables': {
//             'customerAccessToken': customerAccessToken,
//             'addressId': addressId,
//           },
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//       final result = responseData['data']['customerDefaultAddressUpdate'];
//       final errors = result['customerUserErrors'];
//
//       if (kDebugMode) {
//         print("Set Default Address Response: ${response.body}");
//       }
//
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print(
//               "Set default address errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception(
//             'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
//       }
//       return true;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error setting default address: $e');
//       }
//       rethrow;
//     }
//   }
//
//   /// ⭐️ **GET CUSTOMER DETAILS**
//   /// Fetches the latest, comprehensive customer details, including addresses,
//   /// and saves the full customer data object to SharedPreferences.
// // static Future<Map<String, dynamic>?> getCustomerDetails(
// //     String customerAccessToken) async {
// //   try {
// //     final queryUrl = Uri.https(
// //       shopifyStoreUrl,
// //       '/api/$storefrontApiVersion/graphql.json',
// //     );
// //
// //     final headers = {
// //       'Content-Type': 'application/json',
// //       'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
// //     };
// //
// //     final customerQuery = '''
// //     query {
// //       customer(customerAccessToken: "$customerAccessToken") {
// //         id
// //         firstName
// //         lastName
// //         email
// //         phone
// //         defaultAddress {
// //           id
// //           address1
// //           address2
// //           city
// //           province
// //           zip
// //           country
// //           phone
// //           name
// //         }
// //         addresses(first: 25) { # Fetch up to 25 addresses
// //           edges {
// //             node {
// //               id
// //               address1
// //               address2
// //               city
// //               province
// //               zip
// //               country
// //               phone
// //               name
// //             }
// //           }
// //         }
// //       }
// //     }
// //     ''';
// //
// //     final response = await http.post(
// //       queryUrl,
// //       headers: headers,
// //       body: jsonEncode({'query': customerQuery}),
// //     );
// //
// //     final responseData = json.decode(response.body);
// //     final customerData = responseData['data']['customer'];
// //     final errors = responseData['errors'];
// //
// //     if (kDebugMode) {
// //       print("Get Customer Details Response: ${response.body}");
// //     }
// //
// //     if (errors != null && errors.isNotEmpty) {
// //       if (kDebugMode) {
// //         print(
// //             "Get customer details errors: ${errors.map((e) => e['message']).join(', ')}");
// //       }
// //       throw Exception(
// //           'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
// //     }
// //
// //     if (customerData != null) {
// //       final prefs = await SharedPreferences.getInstance();
// //       final Map<String, dynamic> fullCustomerData = {
// //         'accessToken': customerAccessToken, // Preserve the current token
// //         // If you fetch a new expiry with the token, update it here too.
// //         'customer': customerData,
// //       };
// //       await prefs.setString('customerData', json.encode(fullCustomerData));
// //       if (kDebugMode) {
// //         print(
// //             "Full customer data saved to SharedPreferences: $fullCustomerData");
// //       }
// //       return fullCustomerData;
// //     }
// //   } catch (e) {
// //     if (kDebugMode) {
// //       print('Error fetching customer details: $e');
// //     }
// //     rethrow;
// //   }
// //   return null;
// // }
//
//   /// ⭐️ **GET CUSTOMER DETAILS**
//   /// Updated to handle fetching data.
//   /// Note: The new Customer Account API endpoint is different from Storefront API.
// // static Future<Map<String, dynamic>?> getCustomerDetails(String customerAccessToken) async {
// // try {
// // // ⚠️ IMPORTANT: The URL for Customer Account API is different
// // final queryUrl = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2026-01/graphql');
// //
// // final headers = {
// // 'Content-Type': 'application/json',
// // 'Authorization': '$customerAccessToken', // Bearer might not be needed for this specific API, check docs
// // };
// //
// // final customerQuery = '''
// //       query {
// //         customer {
// //           id
// //           firstName
// //           lastName
// //           emailAddress {
// //             emailAddress
// //           }
// //           phoneNumber {
// //             phoneNumber
// //           }
// //           defaultAddress {
// //             id
// //             address1
// //             city
// //             country
// //           }
// //         }
// //       }
// //       ''';
// //
// // final response = await http.post(
// // queryUrl,
// // headers: headers,
// // body: jsonEncode({'query': customerQuery}),
// // );
// //
// // final responseData = json.decode(response.body);
// //
// // // Adapt response to your app's expected structure
// // if (responseData['data'] != null && responseData['data']['customer'] != null) {
// // final rawCust = responseData['data']['customer'];
// //
// // // Map new API format to your old App format
// // final mappedCustomer = {
// // 'id': rawCust['id'],
// // 'firstName': rawCust['firstName'],
// // 'lastName': rawCust['lastName'],
// // 'email': rawCust['emailAddress']?['emailAddress'],
// // 'phone': rawCust['phoneNumber']?['phoneNumber'],
// // // Add other fields as needed
// // };
// //
// // final prefs = await SharedPreferences.getInstance();
// // final Map<String, dynamic> fullCustomerData = {
// // 'accessToken': customerAccessToken,
// // 'customer': mappedCustomer,
// // };
// // await prefs.setString('customerData', json.encode(fullCustomerData));
// //
// // return fullCustomerData;
// // }
// // } catch (e) {
// // if (kDebugMode) print('Error fetching customer details: $e');
// // }
// // return null;
// // }
//
//   // static Future<Map<String, dynamic>?> getCustomerDetails(String customerAccessToken) async {
//   //   try {
//   //     // Customer Account API endpoint
//   //     final queryUrl = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2026-01/graphql');
//   //
//   //     final headers = {
//   //       'Content-Type': 'application/json',
//   //       'Authorization': 'Bearer $customerAccessToken',
//   //     };
//   //
//   //     final customerQuery = '''
//   //     query {
//   //       customer {
//   //         id
//   //         firstName
//   //         lastName
//   //         emailAddress {
//   //           emailAddress
//   //         }
//   //         phoneNumber {
//   //           phoneNumber
//   //         }
//   //       }
//   //     }
//   //   ''';
//   //
//   //     final response = await http.post(
//   //       queryUrl,
//   //       headers: headers,
//   //       body: jsonEncode({'query': customerQuery}),
//   //     );
//   //
//   //     if (kDebugMode) {
//   //       print('🔍 Customer API Response Status: ${response.statusCode}');
//   //       print('🔍 Customer API Response Body: ${response.body}');
//   //     }
//   //
//   //     if (response.statusCode == 200) {
//   //       final responseData = jsonDecode(response.body);
//   //
//   //       if (responseData['data'] != null && responseData['data']['customer'] != null) {
//   //         final rawCust = responseData['data']['customer'];
//   //
//   //         // Map to your app's format
//   //         final mappedCustomer = {
//   //           'id': rawCust['id'],
//   //           'firstName': rawCust['firstName'] ?? '',
//   //           'lastName': rawCust['lastName'] ?? '',
//   //           'email': rawCust['emailAddress']?['emailAddress'] ?? '',
//   //           'phone': rawCust['phoneNumber']?['phoneNumber'] ?? '',
//   //         };
//   //
//   //         final prefs = await SharedPreferences.getInstance();
//   //         final Map<String, dynamic> fullCustomerData = {
//   //           'accessToken': customerAccessToken,
//   //           'customer': mappedCustomer,
//   //         };
//   //
//   //         await prefs.setString('customerData', json.encode(fullCustomerData));
//   //         await prefs.setString('shopifyCustomer', json.encode(fullCustomerData));
//   //
//   //         if (kDebugMode) print('✅ Customer data saved successfully');
//   //         return fullCustomerData;
//   //       }
//   //     }
//   //
//   //     // If Customer Account API fails, try Storefront API as fallback
//   //     return await _getCustomerDetailsStorefront(customerAccessToken);
//   //
//   //   } catch (e) {
//   //     if (kDebugMode) print('❌ Error in getCustomerDetails: $e');
//   //     return null;
//   //   }
//   // }
//
//
// // Fallback method using Storefront API
//   static Future<Map<String, dynamic>?> _getCustomerDetailsStorefront(String accessToken) async {
//     try {
//       final queryUrl = Uri.https(
//         shopifyStoreUrl,
//         '/api/$storefrontApiVersion/graphql.json',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       };
//
//       final customerQuery = '''
//       query {
//         customer(customerAccessToken: "$accessToken") {
//           id
//           firstName
//           lastName
//           email
//           phone
//         }
//       }
//     ''';
//
//       final response = await http.post(
//         queryUrl,
//         headers: headers,
//         body: jsonEncode({'query': customerQuery}),
//       );
//
//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);
//         final customerData = responseData['data']['customer'];
//
//         if (customerData != null) {
//           final prefs = await SharedPreferences.getInstance();
//           final Map<String, dynamic> fullCustomerData = {
//             'accessToken': accessToken,
//             'customer': customerData,
//           };
//
//           await prefs.setString('customerData', json.encode(fullCustomerData));
//           await prefs.setString('shopifyCustomer', json.encode(fullCustomerData));
//
//           return fullCustomerData;
//         }
//       }
//     } catch (e) {
//       if (kDebugMode) print('Storefront API fallback error: $e');
//     }
//     return null;
//   }
//
//
//   /// ⭐️ **GET CUSTOMER ORDERS (Customer Account API)**
//   /// Updated to work with the new OAuth 'shcat_' token
//   static Future<List<Map<String, dynamic>>> getCustomerOrdersStorefront(
//       String customerAccessToken) async {
//     try {
//       // 1. CHANGE URL: Point to Customer Account API, not Storefront API
//       final ordersUrl = Uri.parse('https://shopify.com/$_shopId/account/customer/api/2026-01/graphql');
//
//       // 2. CHANGE HEADERS: Use the 'shcat_' token directly (no Bearer prefix)
//       final headers = {
//         'Content-Type': 'application/json',
//         'Authorization': customerAccessToken,
//         'X-Shopify-Customer-Account-Api-Version': '2026-01',
//       };
//
//       // 3. CHANGE QUERY: Updated for Customer Account API schema (uses 'nodes')
//       const ordersQuery = '''
//       query {
//         customer {
//           orders(first: 10, sortKey: PROCESSED_AT, reverse: true) {
//             nodes {
//               id
//               name
//               processedAt
//               financialStatus
//               fulfillmentStatus
//               totalPrice {
//                 amount
//                 currencyCode
//               }
//               lineItems(first: 5) {
//                 nodes {
//                   title
//                   quantity
//                   image {
//                     url
//                   }
//                   price {
//                     amount
//                     currencyCode
//                   }
//                 }
//               }
//               shippingAddress {
//                 address1
//                 city
//                 zip
//                 country
//               }
//             }
//           }
//         }
//       }
//       ''';
//
//       final response = await http.post(
//         ordersUrl,
//         headers: headers,
//         body: jsonEncode({
//           'query': ordersQuery,
//         }),
//       );
//
//       final responseData = json.decode(response.body);
//
//       if (kDebugMode) {
//         print("Get Customer Orders Response: ${response.body}");
//       }
//
//       final errors = responseData['errors'];
//       if (errors != null && errors.isNotEmpty) {
//         if (kDebugMode) {
//           print("Shopify orders API errors: ${errors.map((e) => e['message']).join(', ')}");
//         }
//         throw Exception('Shopify error fetching orders: ${errors.map((e) => e['message']).join(', ')}');
//       }
//
//       final customerData = responseData['data'];
//       if (customerData == null || customerData['customer'] == null) {
//         return [];
//       }
//
//       final customerOrdersData = customerData['customer']['orders'];
//
//       if (customerOrdersData != null && customerOrdersData['nodes'] != null) {
//         List<Map<String, dynamic>> orders = [];
//         for (var node in customerOrdersData['nodes']) {
//           // Map fields to match your app's expected format if necessary
//           // For example, mapping 'name' back to 'orderNumber' if your UI expects that
//           final order = Map<String, dynamic>.from(node);
//           order['orderNumber'] = node['name']; // Allow UI to use orderNumber
//           orders.add(order);
//         }
//         return orders;
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error fetching customer orders: $e');
//       }
//       // Return empty list instead of throwing to prevent app crash
//       return [];
//     }
//     return [];
//   }
//
//   /// Get customer's loyalty points
//   static Future<int> getLoyaltyPoints(String customerId) async {
//     try {
//       final response = await _makeShopifyAdminRequest(
//           'customers/$customerId/metafields.json?namespace=loyalty&key=points');
//
//       if (response.statusCode == 200) {
//         final metafields = json.decode(response.body)['metafields'] as List;
//         if (metafields.isNotEmpty) {
//           return int.tryParse(metafields.first['value'] ?? '0') ?? 0;
//         }
//       }
//       return 0;
//     } catch (e) {
//       if (kDebugMode) print('Error getting loyalty points: $e');
//       return 0;
//     }
//   }
//
//   /// Update customer's loyalty points
//   static Future<bool> updateLoyaltyPoints(String customerId, int points) async {
//     try {
// // First check if metafield exists
//       final checkResponse = await _makeShopifyAdminRequest(
//           'customers/$customerId/metafields.json?namespace=loyalty&key=points');
//
//       final metafields = json.decode(checkResponse.body)['metafields'] as List;
//       final method = metafields.isEmpty ? 'POST' : 'PUT';
//       final endpoint = metafields.isEmpty
//           ? 'customers/$customerId/metafields.json'
//           : 'metafields/${metafields.first['id']}.json';
//
//       final response =
//       await _makeShopifyAdminRequest(endpoint, method: method, body: {
//         'metafield': {
//           'namespace': 'loyalty',
//           'key': 'points',
//           'value': points.toString(),
//           'type': 'integer'
//         }
//       });
//
//       return response.statusCode == 201 || response.statusCode == 200;
//     } catch (e) {
//       if (kDebugMode) print('Error updating loyalty points: $e');
//       return false;
//     }
//   }
//
// // ==================== FIRST ORDER DISCOUNT ====================
//   /// --- Shopify Admin API Request Helper ---
//   static Future<http.Response> _makeShopifyAdminRequestOrderCheck(
//       String endpoint, {
//         String method = 'GET',
//         Map<String, dynamic>? body,
//       }) async {
//     try {
// // Ensure proper URL encoding
//       final encodedEndpoint = Uri.encodeFull(endpoint);
//       final uri = Uri.https(
//         shopifyStoreUrl,
//         '/admin/api/$adminApiVersion/$encodedEndpoint',
//       );
//
//       final headers = {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       };
//
//       if (kDebugMode) {
//         print('Admin API Request: $method ${uri.toString()}');
//         if (body != null) print('Request Body: ${json.encode(body)}');
//       }
//
//       http.Response response;
//       switch (method) {
//         case 'GET':
//           response = await http.get(uri, headers: headers);
//           break;
//         case 'POST':
//           response = await http.post(
//             uri,
//             headers: headers,
//             body: json.encode(body),
//           );
//           break;
//         case 'PUT':
//           response = await http.put(
//             uri,
//             headers: headers,
//             body: json.encode(body),
//           );
//           break;
//         case 'DELETE':
//           response = await http.delete(uri, headers: headers);
//           break;
//         default:
//           throw Exception('Unsupported HTTP method: $method');
//       }
//
//       if (kDebugMode) {
//         print('Admin API Response Status: ${response.statusCode}');
//         print('Admin API Response Body: ${response.body}');
//       }
//
// // Check for HTML response (authentication issue)
//       if (response.body.trim().startsWith('<!DOCTYPE html>') ||
//           response.body.trim().startsWith('<html>')) {
//         throw Exception('''
// Authentication failed - Verify:
// 1. Your admin API credentials are correct
// 2. The access token has proper permissions
// 3. The store URL is correct
// 4. The API version is valid''');
//       }
//
//       return response;
//     } catch (e) {
//       if (kDebugMode) print('Admin API Request Error: $e');
//       rethrow;
//     }
//   }
//
//   /// Check if customer is eligible for first order discount
//   static Future<Map<String, dynamic>?> checkFirstOrderDiscount(
//       String email) async {
//     try {
// // 1. Check if customer has any completed/paid orders
//       final ordersResponse = await _makeShopifyAdminRequestOrderCheck(
//         'customers.json?email=${Uri.encodeComponent(email)}',
//       );
//
//       if (ordersResponse.statusCode != 200) {
//         return {
//           'eligible': false,
//           'message': 'Unable to verify customer information'
//         };
//       }
//
//       final customerData = json.decode(ordersResponse.body);
//       final customers = customerData['customers'] as List? ?? [];
//
//       if (customers.isEmpty) {
//         return {'eligible': false, 'message': 'Customer not found'};
//       }
//
//       final customerId = customers.first['id'];
//
// // Check orders for this customer
//       final customerOrdersResponse = await _makeShopifyAdminRequestOrderCheck(
//         'customers/$customerId/orders.json?status=any',
//       );
//
//       final ordersData = json.decode(customerOrdersResponse.body);
//       final orders = ordersData['orders'] as List? ?? [];
//
// // Filter out cancelled or failed orders
//       final validOrders = orders.where((order) {
//         return order['financial_status'] == 'paid' ||
//             order['financial_status'] == 'partially_paid' ||
//             order['fulfillment_status'] == 'fulfilled';
//       }).toList();
//
//       if (validOrders.isNotEmpty) {
//         return {
//           'eligible': false,
//           'message': 'Discount only available for first orders'
//         };
//       }
//
// // 2. Check discount code
//       final discountResponse = await _makeShopifyAdminRequestOrderCheck(
//         'price_rules.json?title=WELCOME10',
//       );
//
//       if (discountResponse.statusCode != 200) {
//         return {'eligible': false, 'message': 'Discount code not found'};
//       }
//
//       final priceRules =
//           json.decode(discountResponse.body)['price_rules'] as List? ?? [];
//       if (priceRules.isEmpty) {
//         return {'eligible': false, 'message': 'Discount code not active'};
//       }
//
//       final priceRule = priceRules.first;
//       final now = DateTime.now();
//       final startsAt = DateTime.parse(priceRule['starts_at']);
//       final endsAt = priceRule['ends_at'] != null
//           ? DateTime.parse(priceRule['ends_at'])
//           : null;
//
//       if (now.isBefore(startsAt) || (endsAt != null && now.isAfter(endsAt))) {
//         return {
//           'eligible': false,
//           'message': 'Discount code is not currently active'
//         };
//       }
//
//       return {
//         'eligible': true,
//         'code': 'WELCOME10',
//         'message': '10% discount applied to your first order!',
//         'discountValue': 10,
//         'type': 'percentage'
//       };
//     } catch (e) {
//       if (kDebugMode) print('Error checking first order discount: $e');
//       return {
//         'eligible': false,
//         'message': 'Error checking discount. Please try again later.'
//       };
//     }
//   }
//
//   /// Apply discount code to cart
//   static Future<bool> applyDiscountToCart(String discountCode) async {
//     try {
// // This would typically be done through Shopify's Storefront API
// // when creating the checkout. For your implementation:
//
// // 1. Validate the code first
//       final isValid = await validateDiscountCode(discountCode);
//       if (!isValid) return false;
//
// // 2. In a real implementation, you would pass this code to your checkout
//       return true;
//     } catch (e) {
//       if (kDebugMode) print('Error applying discount: $e');
//       return false;
//     }
//   }
//
//   /// Validate discount code
//   static Future<bool> validateDiscountCode(String code) async {
//     try {
//       final response =
//       await _makeShopifyAdminRequest('discount_codes.json?code=$code');
//
//       if (response.statusCode == 200) {
//         final discountCodes =
//         json.decode(response.body)['discount_codes'] as List;
//         return discountCodes.isNotEmpty;
//       }
//       return false;
//     } catch (e) {
//       if (kDebugMode) print('Error validating discount code: $e');
//       return false;
//     }
//   }
//
//   static Future<http.Response> _makeShopifyAdminRequest(
//       String endpoint, {
//         String method = 'GET',
//         Map<String, dynamic>? body,
//       }) async {
//     final uri =
//     Uri.https(shopifyStoreUrl, '/admin/api/$adminApiVersion/$endpoint');
//     final headers = {
//       'Content-Type': 'application/json',
//       'X-Shopify-Access-Token': adminAccessToken,
//     };
//
//     if (kDebugMode) {
//       print('Admin API Request: $method $uri');
//       if (body != null) print('Admin API Request Body: ${json.encode(body)}');
//     }
//
//     http.Response response;
//     switch (method) {
//       case 'GET':
//         response = await http.get(uri, headers: headers);
//         break;
//       case 'POST':
//         response =
//         await http.post(uri, headers: headers, body: json.encode(body));
//         break;
//       case 'PUT':
//         response =
//         await http.put(uri, headers: headers, body: json.encode(body));
//         break;
//       case 'DELETE':
//         response = await http.delete(uri, headers: headers);
//         break;
//       default:
//         throw Exception('Unsupported HTTP method for Admin API');
//     }
//
//     if (kDebugMode) {
//       print('Admin API Response Status: ${response.statusCode}');
//       print('Admin API Response Body: ${response.body}');
//     }
//
//     return response;
//   }
//
//   /// Sends Shopify a password-reset email (customerRecover)
//   static Future<bool> sendResetEmail(String email) async {
//     final url =
//     Uri.https(shopifyStoreUrl, '/api/$storefrontApiVersion/graphql.json');
//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       },
//       body: jsonEncode({
//         'query': '''
//         mutation customerRecover(\$email: String!) {
//           customerRecover(email: \$email) {
//             customerUserErrors { message }
//           }
//         }
//       ''',
//         'variables': {'email': email},
//       }),
//     );
//     final data = json.decode(response.body)['data']['customerRecover'];
//     final errors = data['customerUserErrors'] as List;
//     return errors.isEmpty;
//   }
//
//   /// Resets Shopify password using token from the email (customerReset)
//   static Future<bool> resetPassword(
//       String id, String token, String newPassword) async {
//     final url =
//     Uri.https(shopifyStoreUrl, '/api/$storefrontApiVersion/graphql.json');
//     final response = await http.post(
//       url,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
//       },
//       body: jsonEncode({
//         'query': '''
//         mutation customerReset(\$id: ID!, \$input: CustomerResetInput!) {
//           customerReset(id: \$id, input: \$input) {
//             customerUserErrors { message }
//           }
//         }
//       ''',
//         'variables': {
//           'id': id,
//           'input': {'resetToken': token, 'password': newPassword},
//         },
//       }),
//     );
//     final errors = json.decode(response.body)['data']['customerReset']
//     ['customerUserErrors'] as List;
//     return errors.isEmpty;
//   }
//
//   /// ⚠️ **REGISTER CUSTOMER (Admin API)**
//   /// Creates a new customer account using the Admin API.
//   /// (Secure backend implementation recommended for this function).
//   static Future<Map<String, dynamic>?> registerCustomer(
//       String firstName,
//       String lastName,
//       String email,
//       String password,
//       ) async {
//     try {
//       final url = Uri.parse(
//         'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/customers.json',
//       );
//
//       print('🔹 Admin API Request: POST $url');
//
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'X-Shopify-Access-Token': adminAccessToken_const,
//           'Accept': 'application/json',
//         },
//         body: jsonEncode({
//           'customer': {
//             'first_name': firstName,
//             'last_name': lastName,
//             'email': email,
//             'password': password,
//             'password_confirmation': password,
//             'send_email_welcome': true,
//           },
//         }),
//       );
//
//       print('🔹 Admin API Response Status: ${response.statusCode}');
//       print('🔹 Admin API Response Headers: ${response.headers}');
//       print('🔹 Admin API Response Body: ${response.body}');
//
// // ✅ Handle redirect manually if Shopify returns 301
//       if (response.statusCode == 301 || response.statusCode == 302) {
//         final redirectUrl = response.headers['location'];
//         if (redirectUrl != null) {
//           print('➡️ Redirecting to: $redirectUrl');
//           final redirectedResponse = await http.post(
//             Uri.parse(redirectUrl),
//             headers: {
//               'Content-Type': 'application/json',
//               'X-Shopify-Access-Token': adminAccessToken_const,
//               'Accept': 'application/json',
//             },
//             body: jsonEncode({
//               'customer': {
//                 'first_name': firstName,
//                 'last_name': lastName,
//                 'email': email,
//                 'password': password,
//                 'password_confirmation': password,
//                 'send_email_welcome': true,
//               },
//             }),
//           );
//
//           if (redirectedResponse.statusCode == 201) {
//             return jsonDecode(redirectedResponse.body)['customer'];
//           } else {
//             print('⚠️ Redirected response failed: ${redirectedResponse.body}');
//             return null;
//           }
//         }
//       }
//
//       if (response.statusCode == 201) {
//         final data = jsonDecode(response.body);
//         return data['customer'];
//       }
//
// // Handle unexpected responses
//       if (response.body.isEmpty) {
//         throw Exception('Empty response from Shopify (status ${response.statusCode})');
//       }
//
//       final errorBody = jsonDecode(response.body);
//       print('❌ Admin Register error: ${errorBody['errors'] ?? response.body}');
//       throw Exception('Failed to register customer: ${errorBody['errors'] ?? response.body}');
//     } catch (e) {
//       print('🔥 Admin Register exception: $e');
//       rethrow;
//     }
//   }
//
//
//   /// ⚠️ **UPDATE CUSTOMER (Admin API)**
//   /// Updates existing customer data via Admin API.
//   /// (Secure backend implementation recommended).
//   static Future<bool> updateCustomerAdmin(
//       String customerId, Map<String, dynamic> customerData) async {
//     try {
//       final endpoint = 'customers/$customerId.json';
//       final body = {
//         'customer': {
//           'id': customerId,
// // Admin API expects 'first_name', 'last_name', 'email', 'phone'
//           'first_name': customerData['first_name'],
//           'last_name': customerData['last_name'],
//           'email': customerData['email'],
//           'phone': customerData['phone'],
// // For addresses, use customer_address API endpoints
//         }
//       };
//
//       final response = await _makeShopifyAdminRequest(
//         endpoint,
//         method: 'PUT',
//         body: body,
//       );
//
//       return response.statusCode == 200;
//     } catch (e) {
//       print('Admin Update customer error: $e');
//       rethrow;
//     }
//   }
//
//   /// ⚠️ **GET CUSTOMER (Admin API)**
//   /// Retrieves customer details via Admin API.
//   /// (Secure backend implementation recommended).
//   static Future<Map<String, dynamic>?> getCustomerAdmin(
//       String customerId) async {
//     try {
//       final response = await _makeShopifyAdminRequest(
//         'customers/$customerId.json',
//       );
//
//       if (response.statusCode == 200) {
//         return json.decode(response.body)['customer'];
//       }
//       return null;
//     } catch (e) {
//       print('Admin Get customer error: $e');
//       rethrow;
//     }
//   }
//
//   /// ⚠️ **GET CUSTOMER ORDERS (Admin API)**
//   /// Retrieves customer's orders via Admin API.
//   /// (Secure backend implementation recommended).
//   static Future<List<Map<String, dynamic>>> getCustomerOrdersAdmin(
//       String email) async {
//     try {
//       final searchResponse = await _makeShopifyAdminRequest(
//         'customers/search.json?query=email:$email',
//       );
//
//       if (searchResponse.statusCode != 200) {
//         final errorBody = json.decode(searchResponse.body);
//         throw Exception(
//             'Admin search customer error: ${errorBody['errors'] ?? searchResponse.body}');
//       }
//
//       final customers = json.decode(searchResponse.body)['customers'] as List;
//       if (customers.isEmpty) return [];
//
//       final customerId = customers.first['id'];
//
//       final ordersResponse = await _makeShopifyAdminRequest(
//         'orders.json?customer_id=$customerId',
//       );
//
//       if (ordersResponse.statusCode == 200) {
//         final orders = json.decode(ordersResponse.body)['orders'] as List;
//         return orders.map((order) => order as Map<String, dynamic>).toList();
//       }
//       return [];
//     } catch (e) {
//       print('Admin Get orders error: $e');
//       rethrow;
//     }
//   }
//
// /// **LOGOUT CUSTOMER**
// /// Clears customer data from SharedPreferences.
// // static Future<void> logoutCustomer() async {
// //   final prefs = await SharedPreferences.getInstance();
// //
// //   // Clear all stored preferences
// //   await prefs.clear();
// //
// //   if (kDebugMode) {
// //     print('All SharedPreferences data cleared on logout.');
// //   }
// // }
// }
