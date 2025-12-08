import 'dart:convert';
import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class ShopifyAuthService {

  static const String storefrontAccessToken = storeAccessToken_const;
  static const String shopifyStoreUrl = shopifyStoreUrl_const;
  static const String storefrontApiVersion = storefrontApiVersion_const;
  static const String adminAccessToken = adminAccessToken_const;
  static const String adminApiVersion = adminApiVersion_const;

  /// --- Storefront API Operations ---

  /// 🟢 **LOGIN CUSTOMER**
  /// Authenticates a customer and fetches their profile, including addresses.
  static Future<Map<String, dynamic>?> loginCustomer(
      String email, String password) async {
    try {
      final authUrl = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      // Step 1: Get customerAccessToken
      const loginMutation = '''
      mutation customerAccessTokenCreate(\$input: CustomerAccessTokenCreateInput!) {
        customerAccessTokenCreate(input: \$input) {
          customerAccessToken {
            accessToken
            expiresAt
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final loginResponse = await http.post(
        authUrl,
        headers: headers,
        body: jsonEncode({
          'query': loginMutation,
          'variables': {
            'input': {
              'email': email,
              'password': password,
            },
          },
        }),
      );

      final loginData = json.decode(loginResponse.body);
      final result = loginData['data']['customerAccessTokenCreate'];
      final tokenData = result['customerAccessToken'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print('Login response: ${loginResponse.body}');
      }

      if (tokenData != null) {
        final accessToken = tokenData['accessToken'] as String;

        // Step 2: Fetch comprehensive customer data using the obtained token
        final customerDetails = await getCustomerDetails(accessToken);

        if (customerDetails != null) {
          // The getCustomerDetails method already saves to SharedPreferences
          return customerDetails;
        } else {
          if (kDebugMode) {
            print("Failed to fetch comprehensive customer data after login.");
          }
          return null; // Customer details couldn't be fetched
        }
      } else if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print("Login failed: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(errors.first['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      rethrow; // Re-throw to be caught by UI for specific error messages
    }
    return null;
  }

  static Future<Map<String, dynamic>?> updateCustomerPassword({
    required String customerId,
    required String newPassword,
  }) async {
    try {
      // Use Admin API REST endpoint instead of Storefront GraphQL
      final url = Uri.https(
        shopifyStoreUrl,
        '/admin/api/$adminApiVersion/customers/$customerId.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken,
      };

      final body = {
        'customer': {
          'id': customerId,
          'password': newPassword,
          'password_confirmation': newPassword,
        }
      };

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final responseBody = json.decode(response.body);

      if (kDebugMode) {
        print('Shopify Admin Password Update Status: ${response.statusCode}');
        print('Shopify Admin Password Update Body: $responseBody');
      }

      if (response.statusCode == 200) {
        // Success - password updated
        if (kDebugMode) {
          print('✅ Password updated successfully for customer: $customerId');
        }
        return responseBody;
      } else {
        // Handle errors
        if (responseBody.containsKey('errors')) {
          final errors = responseBody['errors'];
          if (kDebugMode) {
            print("⚠️ Password update failed: $errors");
          }
          throw Exception('Password update failed: $errors');
        } else {
          throw Exception('Failed to update password. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Shopify Admin password update failed: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateCustomerInfo({
    required String customerId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    try {
      final url = Uri.https(
        shopifyStoreUrl,
        '/admin/api/$adminApiVersion/customers/$customerId.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken,
      };

      final body = {
        'customer': {
          'id': customerId,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone,
        }
      };

      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final responseBody = json.decode(response.body);

      if (kDebugMode) {
        print('Shopify Admin Customer Update Status: ${response.statusCode}');
        print('Shopify Admin Customer Update Body: $responseBody');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Customer info updated successfully for customer: $customerId');
        }
        return responseBody;
      } else {
        if (responseBody.containsKey('errors')) {
          final errors = responseBody['errors'];
          if (kDebugMode) {
            print("⚠️ Customer info update failed: $errors");
          }
          throw Exception('Customer info update failed: $errors');
        } else {
          throw Exception('Failed to update customer info. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Shopify Admin customer info update failed: $e');
      }
      rethrow;
    }}

  static Future<Map<String, dynamic>> validateShopifyDiscountCode(
      String code) async {
    if (code.isEmpty) {
      return {'valid': false, 'message': 'Coupon code cannot be empty.'};
    }

    try {
      // --- 1. Find the Discount Code to get its Price Rule ID (using direct lookup.json) ---
      final lookupUri = Uri.parse(
          'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/discount_codes/lookup.json?code=${Uri.encodeComponent(code)}');

      final lookupResponse = await http.get(
        lookupUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': adminAccessToken_const,
        },
      );

      if (lookupResponse.statusCode != 200) {
        if (kDebugMode) print('Discount code lookup failed: ${lookupResponse.statusCode} - ${lookupResponse.body}');
        return {'valid': false, 'message': 'Invalid or inaccessible coupon code.'};
      }

      final lookupData = json.decode(lookupResponse.body);
      final discountCodeData = lookupData['discount_code'] as Map<String, dynamic>?;

      if (discountCodeData == null || discountCodeData['price_rule_id'] == null) {
        return {'valid': false, 'message': 'Invalid coupon code or rule not found.'};
      }

      final priceRuleId = discountCodeData['price_rule_id'];
      final usageCount = (discountCodeData['usage_count'] as num?)?.toInt() ?? 0;


      // --- 2. Fetch the Price Rule to check eligibility, dates, and value ---
      final ruleUri = Uri.parse(
          'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/price_rules/$priceRuleId.json');

      final ruleResponse = await http.get(
        ruleUri,
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': adminAccessToken_const,
        },
      );

      if (ruleResponse.statusCode != 200) {
        if (kDebugMode) print('Price rule fetch failed: ${ruleResponse.statusCode} - ${ruleResponse.body}');
        return {'valid': false, 'message': 'Error retrieving discount details.'};
      }

      final priceRule = json.decode(ruleResponse.body)['price_rule'] as Map<String, dynamic>;

      // Check date validity
      final now = DateTime.now();
      final startsAt = DateTime.parse(priceRule['starts_at']);
      final endsAt = priceRule['ends_at'] != null
          ? DateTime.parse(priceRule['ends_at'])
          : null;

      if (now.isBefore(startsAt)) {
        return {'valid': false, 'message': 'Coupon is not yet active.'};
      }
      if (endsAt != null && now.isAfter(endsAt)) {
        return {'valid': false, 'message': 'Coupon has expired.'};
      }

      // Check usage limits (uses the Price Rule's limit and the Discount Code's count)
      final usageLimit = (priceRule['usage_limit'] as num?)?.toInt();
      if (usageLimit != null && usageCount >= usageLimit) {
        return {'valid': false, 'message': 'Coupon limit reached.'};
      }

      // Determine the discount value (The value field is typically negative for discounts, so we take the absolute value)
      // FIX: Safely convert the 'value' field from String (which Shopify often returns) to double.
      final rawValue = priceRule['value'].toString();
      final value = (double.tryParse(rawValue) ?? 0.0).abs();

      final valueType = priceRule['value_type']; // 'fixed_amount' or 'percentage'

      return {
        'valid': true,
        'message': 'Coupon applied successfully!',
        'value': value,
        'value_type': valueType,
      };
    } catch (e) {
      if (kDebugMode) print('Shopify discount validation error: $e');
      return {'valid': false, 'message': 'An unexpected error occurred.'};
    }
  }
  /// ✅ **VALIDATE PASSWORD**
  /// Uses the login mutation to check if credentials are valid without returning a token.
  static Future<bool> validatePassword(String email, String password) async {
    try {
      final authUrl = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      const loginMutation = '''
      mutation customerAccessTokenCreate(\$input: CustomerAccessTokenCreateInput!) {
        customerAccessTokenCreate(input: \$input) {
          customerAccessToken {
            accessToken
            expiresAt
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final response = await http.post(
        authUrl,
        headers: headers,
        body: jsonEncode({
          'query': loginMutation,
          'variables': {
            'input': {
              'email': email,
              'password': password,
            },
          },
        }),
      );

      final responseData = json.decode(response.body);
      final result = responseData['data']['customerAccessTokenCreate'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print("Password validation response: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Password validation errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        return false; // Authentication failed
      }

      final customerAccessToken = result['customerAccessToken'];
      return customerAccessToken !=
          null; // Password is valid if a token is returned
    } catch (e) {
      if (kDebugMode) {
        print('Error validating password: $e');
      }
      return false;
    }
  }

  /// 🔄 **UPDATE CUSTOMER (Personal Info & Password)**
  /// Updates `firstName`, `lastName`, and `password` for a customer via Storefront API.
  /// Does NOT directly handle email, phone, or address updates.
  static Future<Map<String, dynamic>?> updateCustomerStorefront({
    required String customerAccessToken,
    String? firstName,
    String? lastName,
    String? password,
    // Email updates are complex and usually require re-verification or are handled
    // by specific apps/Admin API. Avoid direct updates here unless Shopify's
    // Storefront API explicitly supports it with a clear flow.
    // String? email,
  }) async {
    try {
      final updateUrl = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      final Map<String, dynamic> customerInput = {};
      if (firstName != null && firstName.isNotEmpty) {
        customerInput['firstName'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        customerInput['lastName'] = lastName;
      }
      if (password != null && password.isNotEmpty) {
        customerInput['password'] = password;
      }

      const updateMutation = '''
      mutation customerUpdate(\$customerAccessToken: String!, \$customer: CustomerUpdateInput!) {
        customerUpdate(customerAccessToken: \$customerAccessToken, customer: \$customer) {
          customer {
            id
            firstName
            lastName
            email
            phone
            defaultAddress { # Query default address to get latest state
              id
              address1
              address2
              city
              province
              zip
              country
              phone
              name # Include name from address
            }
          }
          customerAccessToken {
            accessToken
            expiresAt
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final response = await http.post(
        updateUrl,
        headers: headers,
        body: jsonEncode({
          'query': updateMutation,
          'variables': {
            'customerAccessToken': customerAccessToken,
            'customer': customerInput,
          },
        }),
      );

      final responseData = json.decode(response.body);
      final result = responseData['data']['customerUpdate'];
      final updatedCustomer = result['customer'];
      final newAccessTokenData = result['customerAccessToken'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print("Shopify Customer Update Request Body: ${jsonEncode({
              'query': updateMutation,
              'variables': {
                'customerAccessToken': customerAccessToken,
                'customer': customerInput
              }
            })}");
        print(
            "Shopify Customer Update Response Status: ${response.statusCode}");
        print("Shopify Customer Update Response Body: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Update customer storefront errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
      }

      if (updatedCustomer != null) {
        // Save the *entire updated customer object* received from Shopify,
        // which now includes the latest personal info and defaultAddress data.
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> customerDataToSave = {
          'accessToken':
              newAccessTokenData?['accessToken'] ?? customerAccessToken,
          'expiresAt': newAccessTokenData?['expiresAt'],
          'customer': updatedCustomer,
        };
        await prefs.setString('customerData', json.encode(customerDataToSave));
        if (kDebugMode) {
          print(
              "Updated customer data saved to SharedPreferences: $customerDataToSave");
        }
        return customerDataToSave; // Return the full structure
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update customer storefront error: $e');
      }
      rethrow;
    }
    return null;
  }

  /// 🔄 **CREATE CUSTOMER ADDRESS**
  /// Adds a new address for the customer.
  static Future<Map<String, dynamic>?> createCustomerAddress({
    required String customerAccessToken,
    required Map<String, dynamic> addressInput,
  }) async {
    try {
      final url = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      const createAddressMutation = '''
      mutation customerAddressCreate(\$customerAccessToken: String!, \$address: MailingAddressInput!) {
        customerAddressCreate(customerAccessToken: \$customerAccessToken, address: \$address) {
          customerAddress {
            id
            address1
            address2
            city
            province
            zip
            country
            phone
            name
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'query': createAddressMutation,
          'variables': {
            'customerAccessToken': customerAccessToken,
            'address': addressInput,
          },
        }),
      );

      final responseData = json.decode(response.body);
      final result = responseData['data']['customerAddressCreate'];
      final newAddress = result['customerAddress'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print("Create Customer Address Response: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Create customer address errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
      }

      return newAddress;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating customer address: $e');
      }
      rethrow;
    }
  }

  /// 🔄 **UPDATE CUSTOMER ADDRESS**
  /// Modifies an existing address for the customer.
  static Future<Map<String, dynamic>?> updateCustomerAddress({
    required String customerAccessToken,
    required String addressId,
    required Map<String, dynamic> addressInput,
  }) async {
    try {
      final url = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      const updateAddressMutation = '''
      mutation customerAddressUpdate(\$customerAccessToken: String!, \$id: ID!, \$address: MailingAddressInput!) {
        customerAddressUpdate(customerAccessToken: \$customerAccessToken, id: \$id, address: \$address) {
          customerAddress {
            id
            address1
            address2
            city
            province
            zip
            country
            phone
            name
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'query': updateAddressMutation,
          'variables': {
            'customerAccessToken': customerAccessToken,
            'id': addressId,
            'address': addressInput,
          },
        }),
      );

      final responseData = json.decode(response.body);
      final result = responseData['data']['customerAddressUpdate'];
      final updatedAddress = result['customerAddress'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print("Update Customer Address Response: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Update customer address errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
      }

      return updatedAddress;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating customer address: $e');
      }
      rethrow;
    }
  }

  /// 🔄 **SET DEFAULT CUSTOMER ADDRESS**
  /// Sets a specific address as the customer's default.
  static Future<bool> customerDefaultAddressUpdate({
    required String customerAccessToken,
    required String addressId,
  }) async {
    try {
      final url = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      const defaultAddressMutation = '''
      mutation customerDefaultAddressUpdate(\$customerAccessToken: String!, \$addressId: ID!) {
        customerDefaultAddressUpdate(customerAccessToken: \$customerAccessToken, addressId: \$addressId) {
          customer {
            id
            defaultAddress { # Query default address to get latest state
              id
              address1
              name
            }
          }
          customerUserErrors {
            field
            message
          }
        }
      }
    ''';

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'query': defaultAddressMutation,
          'variables': {
            'customerAccessToken': customerAccessToken,
            'addressId': addressId,
          },
        }),
      );

      final responseData = json.decode(response.body);
      final result = responseData['data']['customerDefaultAddressUpdate'];
      final errors = result['customerUserErrors'];

      if (kDebugMode) {
        print("Set Default Address Response: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Set default address errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting default address: $e');
      }
      rethrow;
    }
  }

  /// ⭐️ **GET CUSTOMER DETAILS**
  /// Fetches the latest, comprehensive customer details, including addresses,
  /// and saves the full customer data object to SharedPreferences.
  static Future<Map<String, dynamic>?> getCustomerDetails(
      String customerAccessToken) async {
    try {
      final queryUrl = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      final customerQuery = '''
      query {
        customer(customerAccessToken: "$customerAccessToken") {
          id
          firstName
          lastName
          email
          phone
          defaultAddress {
            id
            address1
            address2
            city
            province
            zip
            country
            phone
            name
          }
          addresses(first: 25) { # Fetch up to 25 addresses
            edges {
              node {
                id
                address1
                address2
                city
                province
                zip
                country
                phone
                name
              }
            }
          }
        }
      }
      ''';

      final response = await http.post(
        queryUrl,
        headers: headers,
        body: jsonEncode({'query': customerQuery}),
      );

      final responseData = json.decode(response.body);
      final customerData = responseData['data']['customer'];
      final errors = responseData['errors'];

      if (kDebugMode) {
        print("Get Customer Details Response: ${response.body}");
      }

      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Get customer details errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error: ${errors.map((e) => e['message']).join(', ')}');
      }

      if (customerData != null) {
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> fullCustomerData = {
          'accessToken': customerAccessToken, // Preserve the current token
          // If you fetch a new expiry with the token, update it here too.
          'customer': customerData,
        };
        await prefs.setString('customerData', json.encode(fullCustomerData));
        if (kDebugMode) {
          print(
              "Full customer data saved to SharedPreferences: $fullCustomerData");
        }
        return fullCustomerData;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching customer details: $e');
      }
      rethrow;
    }
    return null;
  }

  /// ⭐️ **GET CUSTOMER ORDERS**
  /// Fetches customer's order history using Storefront API.
  static Future<List<Map<String, dynamic>>> getCustomerOrdersStorefront(
      String customerAccessToken) async {
    try {
      final ordersUrl = Uri.https(
        shopifyStoreUrl,
        '/api/$storefrontApiVersion/graphql.json',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

      const ordersQuery = '''
  query (\$customerAccessToken: String!) {
    customer(customerAccessToken: \$customerAccessToken) {
      orders(first: 10, sortKey: PROCESSED_AT, reverse: true) { # Get most recent 10 orders
        edges {
          node {
            id
            orderNumber
            processedAt
            statusUrl
            totalPrice {
              amount
              currencyCode
            }
            fulfillmentStatus
            lineItems(first: 5) {
              edges {
                node {
                  quantity
                  title
                  variant {
                    title
                    image { # This is the correct place to get the image (from the variant)
                      url
                    }
                  }
                  originalTotalPrice {
                      amount
                      currencyCode
                  }
                }
              }
            }
            shippingAddress {
              name
              address1
              address2
              city
              province
              zip
              country
              phone
            }
            billingAddress {
              name
              address1
              address2
              city
              province
              zip
              country
              phone
            }
          }
        }
      }
    }
  }
'''; // End of ordersQuery

      final response = await http.post(
        ordersUrl,
        headers: headers,
        body: jsonEncode({
          'query': ordersQuery,
          'variables': {
            'customerAccessToken': customerAccessToken,
          },
        }),
      );

      final responseData = json.decode(response.body);

      if (kDebugMode) {
        print("Get Customer Orders Response: ${response.body}");
      }

      // Check for errors first, as they often indicate 'data' will be null
      final errors = responseData['errors'];
      if (errors != null && errors.isNotEmpty) {
        if (kDebugMode) {
          print(
              "Shopify orders API errors: ${errors.map((e) => e['message']).join(', ')}");
        }
        throw Exception(
            'Shopify error fetching orders: ${errors.map((e) => e['message']).join(', ')}');
      }

      // Add null checks for 'data' and 'customer'
      final customerData = responseData['data'];
      if (customerData == null) {
        if (kDebugMode) {
          print("Shopify orders API: 'data' field is null in response.");
        }
        return []; // Or throw an exception if this state is unexpected
      }

      final customerNode = customerData['customer'];
      if (customerNode == null) {
        if (kDebugMode) {
          print(
              "Shopify orders API: 'customer' field is null in response data.");
        }
        return []; // No customer found or linked, return empty list
      }

      final customerOrdersData = customerNode['orders'];
      // The subsequent check for customerOrdersData != null and customerOrdersData['edges'] != null
      // is already good.

      if (customerOrdersData != null && customerOrdersData['edges'] != null) {
        List<Map<String, dynamic>> orders = [];
        for (var edge in customerOrdersData['edges']) {
          orders.add(edge['node']);
        }
        return orders;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching customer orders: $e');
      }
      rethrow;
    }
    return [];
  }

  /// Get customer's loyalty points
  static Future<int> getLoyaltyPoints(String customerId) async {
    try {
      final response = await _makeShopifyAdminRequest(
          'customers/$customerId/metafields.json?namespace=loyalty&key=points');

      if (response.statusCode == 200) {
        final metafields = json.decode(response.body)['metafields'] as List;
        if (metafields.isNotEmpty) {
          return int.tryParse(metafields.first['value'] ?? '0') ?? 0;
        }
      }
      return 0;
    } catch (e) {
      if (kDebugMode) print('Error getting loyalty points: $e');
      return 0;
    }
  }

  /// Update customer's loyalty points
  static Future<bool> updateLoyaltyPoints(String customerId, int points) async {
    try {
      // First check if metafield exists
      final checkResponse = await _makeShopifyAdminRequest(
          'customers/$customerId/metafields.json?namespace=loyalty&key=points');

      final metafields = json.decode(checkResponse.body)['metafields'] as List;
      final method = metafields.isEmpty ? 'POST' : 'PUT';
      final endpoint = metafields.isEmpty
          ? 'customers/$customerId/metafields.json'
          : 'metafields/${metafields.first['id']}.json';

      final response =
          await _makeShopifyAdminRequest(endpoint, method: method, body: {
        'metafield': {
          'namespace': 'loyalty',
          'key': 'points',
          'value': points.toString(),
          'type': 'integer'
        }
      });

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Error updating loyalty points: $e');
      return false;
    }
  }

  // ==================== FIRST ORDER DISCOUNT ====================
  /// --- Shopify Admin API Request Helper ---
  static Future<http.Response> _makeShopifyAdminRequestOrderCheck(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      // Ensure proper URL encoding
      final encodedEndpoint = Uri.encodeFull(endpoint);
      final uri = Uri.https(
        shopifyStoreUrl,
        '/admin/api/$adminApiVersion/$encodedEndpoint',
      );

      final headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken,
      };

      if (kDebugMode) {
        print('Admin API Request: $method ${uri.toString()}');
        if (body != null) print('Request Body: ${json.encode(body)}');
      }

      http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: json.encode(body),
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: json.encode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (kDebugMode) {
        print('Admin API Response Status: ${response.statusCode}');
        print('Admin API Response Body: ${response.body}');
      }

      // Check for HTML response (authentication issue)
      if (response.body.trim().startsWith('<!DOCTYPE html>') ||
          response.body.trim().startsWith('<html>')) {
        throw Exception('''
Authentication failed - Verify:
1. Your admin API credentials are correct
2. The access token has proper permissions
3. The store URL is correct
4. The API version is valid''');
      }

      return response;
    } catch (e) {
      if (kDebugMode) print('Admin API Request Error: $e');
      rethrow;
    }
  }

  /// Check if customer is eligible for first order discount
  static Future<Map<String, dynamic>?> checkFirstOrderDiscount(
      String email) async {
    try {
      // 1. Check if customer has any completed/paid orders
      final ordersResponse = await _makeShopifyAdminRequestOrderCheck(
        'customers.json?email=${Uri.encodeComponent(email)}',
      );

      if (ordersResponse.statusCode != 200) {
        return {
          'eligible': false,
          'message': 'Unable to verify customer information'
        };
      }

      final customerData = json.decode(ordersResponse.body);
      final customers = customerData['customers'] as List? ?? [];

      if (customers.isEmpty) {
        return {'eligible': false, 'message': 'Customer not found'};
      }

      final customerId = customers.first['id'];

      // Check orders for this customer
      final customerOrdersResponse = await _makeShopifyAdminRequestOrderCheck(
        'customers/$customerId/orders.json?status=any',
      );

      final ordersData = json.decode(customerOrdersResponse.body);
      final orders = ordersData['orders'] as List? ?? [];

      // Filter out cancelled or failed orders
      final validOrders = orders.where((order) {
        return order['financial_status'] == 'paid' ||
            order['financial_status'] == 'partially_paid' ||
            order['fulfillment_status'] == 'fulfilled';
      }).toList();

      if (validOrders.isNotEmpty) {
        return {
          'eligible': false,
          'message': 'Discount only available for first orders'
        };
      }

      // 2. Check discount code
      final discountResponse = await _makeShopifyAdminRequestOrderCheck(
        'price_rules.json?title=WELCOME10',
      );

      if (discountResponse.statusCode != 200) {
        return {'eligible': false, 'message': 'Discount code not found'};
      }

      final priceRules =
          json.decode(discountResponse.body)['price_rules'] as List? ?? [];
      if (priceRules.isEmpty) {
        return {'eligible': false, 'message': 'Discount code not active'};
      }

      final priceRule = priceRules.first;
      final now = DateTime.now();
      final startsAt = DateTime.parse(priceRule['starts_at']);
      final endsAt = priceRule['ends_at'] != null
          ? DateTime.parse(priceRule['ends_at'])
          : null;

      if (now.isBefore(startsAt) || (endsAt != null && now.isAfter(endsAt))) {
        return {
          'eligible': false,
          'message': 'Discount code is not currently active'
        };
      }

      return {
        'eligible': true,
        'code': 'WELCOME10',
        'message': '10% discount applied to your first order!',
        'discountValue': 10,
        'type': 'percentage'
      };
    } catch (e) {
      if (kDebugMode) print('Error checking first order discount: $e');
      return {
        'eligible': false,
        'message': 'Error checking discount. Please try again later.'
      };
    }
  }

  /// Apply discount code to cart
  static Future<bool> applyDiscountToCart(String discountCode) async {
    try {
      // This would typically be done through Shopify's Storefront API
      // when creating the checkout. For your implementation:

      // 1. Validate the code first
      final isValid = await validateDiscountCode(discountCode);
      if (!isValid) return false;

      // 2. In a real implementation, you would pass this code to your checkout
      return true;
    } catch (e) {
      if (kDebugMode) print('Error applying discount: $e');
      return false;
    }
  }

  /// Validate discount code
  static Future<bool> validateDiscountCode(String code) async {
    try {
      final response =
          await _makeShopifyAdminRequest('discount_codes.json?code=$code');

      if (response.statusCode == 200) {
        final discountCodes =
            json.decode(response.body)['discount_codes'] as List;
        return discountCodes.isNotEmpty;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Error validating discount code: $e');
      return false;
    }
  }

  static Future<http.Response> _makeShopifyAdminRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final uri =
        Uri.https(shopifyStoreUrl, '/admin/api/$adminApiVersion/$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': adminAccessToken,
    };

    if (kDebugMode) {
      print('Admin API Request: $method $uri');
      if (body != null) print('Admin API Request Body: ${json.encode(body)}');
    }

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response =
            await http.post(uri, headers: headers, body: json.encode(body));
        break;
      case 'PUT':
        response =
            await http.put(uri, headers: headers, body: json.encode(body));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method for Admin API');
    }

    if (kDebugMode) {
      print('Admin API Response Status: ${response.statusCode}');
      print('Admin API Response Body: ${response.body}');
    }

    return response;
  }

  /// Sends Shopify a password-reset email (customerRecover)
  static Future<bool> sendResetEmail(String email) async {
    final url =
        Uri.https(shopifyStoreUrl, '/api/$storefrontApiVersion/graphql.json');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      },
      body: jsonEncode({
        'query': '''
        mutation customerRecover(\$email: String!) {
          customerRecover(email: \$email) {
            customerUserErrors { message }
          }
        }
      ''',
        'variables': {'email': email},
      }),
    );
    final data = json.decode(response.body)['data']['customerRecover'];
    final errors = data['customerUserErrors'] as List;
    return errors.isEmpty;
  }

  /// Resets Shopify password using token from the email (customerReset)
  static Future<bool> resetPassword(
      String id, String token, String newPassword) async {
    final url =
        Uri.https(shopifyStoreUrl, '/api/$storefrontApiVersion/graphql.json');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      },
      body: jsonEncode({
        'query': '''
        mutation customerReset(\$id: ID!, \$input: CustomerResetInput!) {
          customerReset(id: \$id, input: \$input) {
            customerUserErrors { message }
          }
        }
      ''',
        'variables': {
          'id': id,
          'input': {'resetToken': token, 'password': newPassword},
        },
      }),
    );
    final errors = json.decode(response.body)['data']['customerReset']
        ['customerUserErrors'] as List;
    return errors.isEmpty;
  }

  /// ⚠️ **REGISTER CUSTOMER (Admin API)**
  /// Creates a new customer account using the Admin API.
  /// (Secure backend implementation recommended for this function).
  static Future<Map<String, dynamic>?> registerCustomer(
      String firstName,
      String lastName,
      String email,
      String password,
      ) async {
    try {
      final url = Uri.parse(
        'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/customers.json',
      );

      print('🔹 Admin API Request: POST $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': adminAccessToken_const,
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'customer': {
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'password': password,
            'password_confirmation': password,
            'send_email_welcome': true,
          },
        }),
      );

      print('🔹 Admin API Response Status: ${response.statusCode}');
      print('🔹 Admin API Response Headers: ${response.headers}');
      print('🔹 Admin API Response Body: ${response.body}');

      // ✅ Handle redirect manually if Shopify returns 301
      if (response.statusCode == 301 || response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          print('➡️ Redirecting to: $redirectUrl');
          final redirectedResponse = await http.post(
            Uri.parse(redirectUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Shopify-Access-Token': adminAccessToken_const,
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'customer': {
                'first_name': firstName,
                'last_name': lastName,
                'email': email,
                'password': password,
                'password_confirmation': password,
                'send_email_welcome': true,
              },
            }),
          );

          if (redirectedResponse.statusCode == 201) {
            return jsonDecode(redirectedResponse.body)['customer'];
          } else {
            print('⚠️ Redirected response failed: ${redirectedResponse.body}');
            return null;
          }
        }
      }

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['customer'];
      }

      // Handle unexpected responses
      if (response.body.isEmpty) {
        throw Exception('Empty response from Shopify (status ${response.statusCode})');
      }

      final errorBody = jsonDecode(response.body);
      print('❌ Admin Register error: ${errorBody['errors'] ?? response.body}');
      throw Exception('Failed to register customer: ${errorBody['errors'] ?? response.body}');
    } catch (e) {
      print('🔥 Admin Register exception: $e');
      rethrow;
    }
  }


  /// ⚠️ **UPDATE CUSTOMER (Admin API)**
  /// Updates existing customer data via Admin API.
  /// (Secure backend implementation recommended).
  static Future<bool> updateCustomerAdmin(
      String customerId, Map<String, dynamic> customerData) async {
    try {
      final endpoint = 'customers/$customerId.json';
      final body = {
        'customer': {
          'id': customerId,
          // Admin API expects 'first_name', 'last_name', 'email', 'phone'
          'first_name': customerData['first_name'],
          'last_name': customerData['last_name'],
          'email': customerData['email'],
          'phone': customerData['phone'],
          // For addresses, use customer_address API endpoints
        }
      };

      final response = await _makeShopifyAdminRequest(
        endpoint,
        method: 'PUT',
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Admin Update customer error: $e');
      rethrow;
    }
  }

  /// ⚠️ **GET CUSTOMER (Admin API)**
  /// Retrieves customer details via Admin API.
  /// (Secure backend implementation recommended).
  static Future<Map<String, dynamic>?> getCustomerAdmin(
      String customerId) async {
    try {
      final response = await _makeShopifyAdminRequest(
        'customers/$customerId.json',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['customer'];
      }
      return null;
    } catch (e) {
      print('Admin Get customer error: $e');
      rethrow;
    }
  }

  /// ⚠️ **GET CUSTOMER ORDERS (Admin API)**
  /// Retrieves customer's orders via Admin API.
  /// (Secure backend implementation recommended).
  static Future<List<Map<String, dynamic>>> getCustomerOrdersAdmin(
      String email) async {
    try {
      final searchResponse = await _makeShopifyAdminRequest(
        'customers/search.json?query=email:$email',
      );

      if (searchResponse.statusCode != 200) {
        final errorBody = json.decode(searchResponse.body);
        throw Exception(
            'Admin search customer error: ${errorBody['errors'] ?? searchResponse.body}');
      }

      final customers = json.decode(searchResponse.body)['customers'] as List;
      if (customers.isEmpty) return [];

      final customerId = customers.first['id'];

      final ordersResponse = await _makeShopifyAdminRequest(
        'orders.json?customer_id=$customerId',
      );

      if (ordersResponse.statusCode == 200) {
        final orders = json.decode(ordersResponse.body)['orders'] as List;
        return orders.map((order) => order as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      print('Admin Get orders error: $e');
      rethrow;
    }
  }

  /// **LOGOUT CUSTOMER**
  /// Clears customer data from SharedPreferences.
  static Future<void> logoutCustomer() async {
    final prefs = await SharedPreferences.getInstance();

    // Clear all stored preferences
    await prefs.clear();

    if (kDebugMode) {
      print('All SharedPreferences data cleared on logout.');
    }
  }
}
