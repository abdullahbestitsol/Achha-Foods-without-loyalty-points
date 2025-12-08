import 'dart:convert';
import 'dart:io';
import 'package:achhafoods/screens/Consts/conts.dart'; // Assumed to contain 'localurl'
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED for token

// Maximum number of times to retry a network request on failure
const int maxRetries = 3;

class LaravelApiService {
  static Future<Map<String, dynamic>> updateProfile({
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    String? oldPassword,
    String? newPassword,
    String? newAddressLabel,
    String? newAddressValue,
  }) async {
    // 1. Fetch the Laravel access token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final laravelToken = prefs.getString('laravelToken');

    if (kDebugMode) {
      print("🔑 Laravel Token: ${laravelToken != null ? 'Present' : 'Missing'}");
    }

    // Assumes 'localurl' is available via the 'conts.dart' import
    final url = Uri.parse('$localurl/api/user/update-profile');
    if (kDebugMode) {
      print('Updating profile with URL: $url');
    }

    final Map<String, dynamic> body = {
      'email': email,
    };

    // Personal Info
    if (firstName != null && lastName != null) {
      body['name'] = '$firstName $lastName';
    }
    if (phone != null) body['phone'] = phone;

    // Password Update
    if (newPassword != null && newPassword.isNotEmpty) {
      body['old_password'] = oldPassword;
      body['password'] = newPassword;
      body['password_confirmation'] = newPassword; // For Laravel's 'confirmed' rule
    }

    // Address Update (Adding one new address)
    if (newAddressLabel != null && newAddressValue != null) {
      body['address_label'] = newAddressLabel; // CHANGED from 'new_address_label'
      body['address'] = newAddressValue;       // CHANGED from 'new_address_value'
    }

    // 2. Setup Headers including Authorization
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (laravelToken != null) {
      headers['Authorization'] = 'Bearer $laravelToken';
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      final responseBody = json.decode(response.body);

      if (kDebugMode) {
        print('Laravel API Response Status: ${response.statusCode}');
        print('Laravel API Response Body: $responseBody');
      }

      if (response.statusCode == 200 && responseBody['status'] == true) {
        final data = Map<String, dynamic>.from(responseBody['data']);

        // ✅ Normalize full_addresses into a List<Map<String,String>>
        if (data['full_addresses'] is Map) {
          data['full_addresses'] = (data['full_addresses'] as Map<String, dynamic>)
              .entries
              .map((e) => {
            'label': e.key.toString(),
            'address': e.value.toString(),
          })
              .toList();
        } else if (data['full_addresses'] is List) {
          data['full_addresses'] =
              (data['full_addresses'] as List).map((e) => Map<String, String>.from(e)).toList();
        } else {
          data['full_addresses'] = [];
        }

        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized (401). Token is invalid or expired. Please log in again.');
      } else {
        final message = responseBody['message'] ??
            'An unknown error occurred with status ${response.statusCode}.';
        throw Exception(message);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling Laravel API: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getProfile({
    required String email,
  }) async {
    final url = Uri.parse('$localurl/api/user-by-email')
        .replace(queryParameters: {'email': email});
    final Map<String, String> headers = {'Accept': 'application/json'};

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http.get(url, headers: headers);

        final responseBody = json.decode(response.body);

        if (kDebugMode) {
          print('Laravel API Response Status: ${response.statusCode} (Attempt $attempt)');
          print('Laravel API Response Body: $responseBody');
        }

        if (response.statusCode == 200 && responseBody['status'] == true) {
          final data = Map<String, dynamic>.from(responseBody['data']);

          // ✅ Normalize full_addresses into a List<Map<String,String>>
          if (data['full_addresses'] is Map) {
            data['full_addresses'] = (data['full_addresses'] as Map<String, dynamic>)
                .entries
                .map((e) => {
              'label': e.key.toString(),
              'address': e.value.toString(),
            })
                .toList();
          } else if (data['full_addresses'] is List) {
            data['full_addresses'] =
                (data['full_addresses'] as List).map((e) => Map<String, String>.from(e)).toList();
          } else {
            data['full_addresses'] = [];
          }

          return data;
        } else {
          final message = responseBody['message'] ??
              'An unknown server error occurred with status ${response.statusCode}.';
          throw Exception(message);
        }
      } on SocketException catch (e) {
        if (kDebugMode) {
          print('Network Error on Attempt $attempt: $e');
        }
        if (attempt == maxRetries) {
          rethrow;
        }
        final delaySeconds = 1 << (attempt - 1);
        await Future.delayed(Duration(seconds: delaySeconds));
      } catch (e) {
        if (kDebugMode) {
          print('Non-retryable Error: $e');
        }
        rethrow;
      }
    }

    throw Exception("Failed to fetch profile data after $maxRetries attempts.");
  }
}



//
//
// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
// import 'package:achhafoods/screens/Consts/appBar.dart';
// import 'package:achhafoods/screens/Consts/conts.dart'; // Make sure this provides `apiVersion` and `localurl`
// import 'package:achhafoods/screens/Drawer/Drawer.dart';
// import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:achhafoods/screens/CartScreen/ThankYouScreen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../services/CartServices.dart';
//
//
// class CheckoutScreen extends StatefulWidget {
//   final List cartItems;
//   final double originalAmount;
//   final double finalAmount;
//   final String? discountCode;
//
//   const CheckoutScreen({
//     Key? key,
//     required this.cartItems,
//     required this.finalAmount,
//     required this.originalAmount,
//     this.discountCode,
//   }) : super(key: key);
//
//   @override
//   State<CheckoutScreen> createState() => _CheckoutScreenState();
// }
//
// class _CheckoutScreenState extends State<CheckoutScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _discountCodeController = TextEditingController();
//
//   Map<String, dynamic>? customer;
//   Map<String, dynamic>? laravelUser;
//   bool _isCodSelected = true;
//   bool _isLoading = false;
//   bool _useLoyaltyPoints = false;
//   int _loyaltyPoints = 0;
//   bool _isLoggedIn = false;
//
//   late double _finalAmount;
//   bool _hasAppliedDiscount = false;
//   bool _discountApplied = false;
//
//   // STATE VARIABLES FOR ADDRESSES
//   List<Map<String, String>> _savedAddresses = [];
//   String? _selectedAddressKey;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _checkLoginStatusAndLoadInfo();
//     _finalAmount = widget.finalAmount;
//
//     if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
//       _discountCodeController.text = widget.discountCode!;
//       _discountApplied = true;
//       _hasAppliedDiscount = true;
//     }
//   }
//
//   // --- Core API and Data Loading Logic ---
//
//   Future<void> _checkLoginStatusAndLoadInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     final laravelUserJson = prefs.getString('laravelUser');
//     if (laravelUserJson != null) {
//       setState(() {
//         _isLoggedIn = true;
//       });
//       await _loadCustomerInfo();
//     } else {
//       setState(() {
//         _isLoggedIn = false;
//         _selectedAddressKey = 'new_address_option';
//       });
//     }
//   }
//
//   Future<Map<String, dynamic>?> _fetchUserDataWithGetAndBody(String email, String? token) async {
//     final uri = Uri.parse('$localurl/api/user-by-email');
//     final body = json.encode({"email": email});
//
//     final request = http.Request('GET', uri)
//       ..headers.addAll({
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         if (token != null) 'Authorization': 'Bearer $token',
//       })
//       ..body = body;
//
//     try {
//       final streamedResponse = await http.Client().send(request);
//       final response = await http.Response.fromStream(streamedResponse);
//
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> responseData = json.decode(response.body);
//         if (kDebugMode) print("API User Data (GET with Body): $responseData");
//         return responseData;
//       } else {
//         if (kDebugMode) {
//           print("Failed to fetch user data (GET with Body): ${response.statusCode} - ${response.body}");
//         }
//         return null;
//       }
//     } catch (e) {
//       if (kDebugMode) print("Error fetching user data (GET with Body): $e");
//       return null;
//     }
//   }
//
//   void _populateAddressControllers(String fullAddress) {
//     // Only set the main address controller
//     _addressController.text = fullAddress;
//   }
//
//   Future<void> _loadCustomerInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     final customerData = prefs.getString('customer');
//     final laravelUserData = prefs.getString('laravelUser');
//     final String? laravelToken = prefs.getString('laravelToken');
//
//     if (customerData != null && laravelUserData != null) {
//       setState(() {
//         customer = json.decode(customerData);
//         laravelUser = json.decode(laravelUserData);
//         final customerDetails = customer?['customer'] as Map<String, dynamic>?;
//         if (customerDetails != null) {
//           _emailController.text = customerDetails['email'] ?? '';
//           _nameController.text = '${customerDetails['firstName'] ?? ''} ${customerDetails['lastName'] ?? ''}'.trim();
//           _phoneController.text = laravelUser!['phone'] ?? '';
//         }
//       });
//
//       if (_emailController.text.isNotEmpty) {
//         final responseData = await _fetchUserDataWithGetAndBody(_emailController.text, laravelToken);
//
//         final userData = responseData?['data'] as Map<String, dynamic>?;
//
//         if (responseData?['status'] == true && userData != null) {
//           final Map<String, dynamic>? addressesMap = userData['full_addresses'];
//           final int loyaltyPoints = userData['loyalty_points'] ?? 0;
//
//           setState(() {
//             _loyaltyPoints = loyaltyPoints;
//             _savedAddresses.clear();
//
//             if (addressesMap != null) {
//               addressesMap.forEach((label, fullAddress) {
//                 _savedAddresses.add({
//                   'label': label,
//                   'address': fullAddress.toString(),
//                 });
//               });
//             }
//
//             if (_savedAddresses.isNotEmpty) {
//               _selectedAddressKey = _savedAddresses.first['label'];
//               _populateAddressControllers(_savedAddresses.first['address']!);
//             } else {
//               _selectedAddressKey = 'new_address_option';
//               _addressController.clear();
//             }
//
//             _isLoggedIn = true;
//             _recalculateFinalAmount();
//           });
//         }
//       }
//     } else {
//       setState(() {
//         _isLoggedIn = false;
//         _selectedAddressKey = 'new_address_option';
//         _addressController.clear();
//       });
//     }
//   }
//
//   void _recalculateFinalAmount() {
//     if (_useLoyaltyPoints) {
//       double loyaltyDiscount = _loyaltyPoints.toDouble();
//       _finalAmount = (widget.originalAmount - loyaltyDiscount).clamp(0.0, widget.originalAmount);
//       _discountApplied = true;
//       _hasAppliedDiscount = true;
//       _discountCodeController.text = "Loyalty Points";
//     } else {
//       _finalAmount = widget.finalAmount;
//       _discountApplied = (widget.discountCode != null && widget.discountCode!.isNotEmpty);
//       _hasAppliedDiscount = (widget.discountCode != null && widget.discountCode!.isNotEmpty);
//       _discountCodeController.text = widget.discountCode ?? '';
//     }
//   }
//
//   // --- Build Method and UI Components ---
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Scaffold(
//           appBar: const CustomAppBar(),
//           drawer: const CustomDrawer(),
//           bottomNavigationBar: const NewNavigationBar(),
//           body: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: double.infinity,
//                 color: CustomColorTheme.CustomBlueColor,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 alignment: Alignment.center,
//                 child: const Text(
//                   "Checkout",
//                   style: TextStyle(
//                     fontSize: 20,
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const SizedBox(height: 12),
//                         const Text(
//                           "Order Summary:",
//                           style: TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold),
//                         ),
//                         const SizedBox(height: 8),
//                         ...widget.cartItems.map((product) => Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Flexible(
//                               child: Text(
//                                   "${product.title} (x${product.quantity})"),
//                             ),
//                             Text(
//                               "Rs. ${(product.price * product.quantity).toStringAsFixed(2)}",
//                             ),
//                           ],
//                         )),
//                         if (_discountApplied && _finalAmount < widget.originalAmount)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 8.0),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   "Discount (${_discountCodeController.text}):",
//                                   style: TextStyle(
//                                     color: Colors.green.shade600,
//                                   ),
//                                 ),
//                                 Text(
//                                   "- Rs. ${(widget.originalAmount - _finalAmount).toStringAsFixed(2)}",
//                                   style: TextStyle(
//                                     color: Colors.green.shade600,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         const Divider(),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               "Grand Total:",
//                               style: TextStyle(
//                                   fontSize: 18, fontWeight: FontWeight.bold),
//                             ),
//                             Text(
//                               "Rs. ${_finalAmount.toStringAsFixed(2)}",
//                               style: const TextStyle(
//                                   fontSize: 18, fontWeight: FontWeight.bold),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//
//                         // --- Billing/Contact Info Fields ---
//                         TextFormField(
//                           controller: _nameController,
//                           decoration:
//                           const InputDecoration(labelText: "Full Name"),
//                           validator: (value) =>
//                           value!.isEmpty ? "Name is required" : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _emailController,
//                           decoration:
//                           const InputDecoration(labelText: "Email Address"),
//                           keyboardType: TextInputType.emailAddress,
//                           validator: (value) {
//                             if (value!.isEmpty) return "Email is required";
//                             if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
//                                 .hasMatch(value)) {
//                               return "Enter valid email";
//                             }
//                             return null;
//                           },
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _phoneController,
//                           decoration:
//                           const InputDecoration(labelText: "Phone Number"),
//                           keyboardType: TextInputType.phone,
//                           validator: (value) =>
//                           value!.isEmpty ? "Phone is required" : null,
//                         ),
//                         const SizedBox(height: 12),
//
//                         // --- ADDRESS DROPDOWN ---
//
//                         if (_isLoggedIn && _savedAddresses.isNotEmpty)
//                           Padding(
//                             padding: const EdgeInsets.only(bottom: 12.0),
//                             child: DropdownButtonFormField<String>(
//                               decoration: const InputDecoration(
//                                 labelText: 'Select Shipping Address',
//                                 border: OutlineInputBorder(
//                                   borderSide: BorderSide(color: Colors.black), // Black border
//                                 ),
//                               ),
//                               value: _selectedAddressKey,
//                               items: [
//                                 ..._savedAddresses.map((addr) => DropdownMenuItem(
//                                   value: addr['label'],
//                                   child: Text('${addr['label']!}: ${addr['address']!}', overflow: TextOverflow.ellipsis),
//                                 )),
//                                 const DropdownMenuItem(
//                                   value: 'new_address_option',
//                                   child: Text('➕ Write a New Address'),
//                                 ),
//                               ],
//                               onChanged: (String? newValue) {
//                                 setState(() {
//                                   _selectedAddressKey = newValue;
//                                   if (newValue == 'new_address_option') {
//                                     _addressController.clear();
//                                   } else {
//                                     final selected = _savedAddresses.firstWhere((addr) => addr['label'] == newValue);
//                                     _populateAddressControllers(selected['address']!);
//                                   }
//                                 });
//                               },
//                               validator: (value) =>
//                               value == null ? "Please select an address" : null,
//                             ),
//                           ),
//
//                         // Address Field
//                         TextFormField(
//                           controller: _addressController,
//                           decoration: InputDecoration(
//                               labelText: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty
//                                   ? "Full Shipping Address (Required)"
//                                   : "Selected Address"
//                           ),
//                           maxLines: 3,
//                           validator: (value) =>
//                           value!.isEmpty ? "Address is required" : null,
//                           enabled: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty,
//                         ),
//                         const SizedBox(height: 20),
//
//                         // --- Toggle Buttons (Black and White) ---
//
//                         SwitchListTile(
//                           title: const Text("Cash on Delivery (COD)"),
//                           value: _isCodSelected,
//                           onChanged: (val) =>
//                               setState(() => _isCodSelected = val),
//                           activeColor: Colors.black, // Black active color
//                           inactiveThumbColor: Colors.grey.shade300,
//                           inactiveTrackColor: Colors.grey.shade100,
//                         ),
//                         if (_isLoggedIn)
//                           SwitchListTile(
//                             title: const Text("Use Loyalty Points"),
//                             subtitle: Text("Available: $_loyaltyPoints points"),
//                             value: _useLoyaltyPoints,
//                             onChanged: (val) {
//                               if (val == true && _loyaltyPoints <= 0) {
//                                 Fluttertoast.showToast(
//                                   msg: "You have no loyalty points to use.",
//                                   backgroundColor: Colors.red,
//                                   toastLength: Toast.LENGTH_LONG,
//                                 );
//                                 return;
//                               }
//
//                               setState(() {
//                                 _useLoyaltyPoints = val;
//                                 _recalculateFinalAmount();
//                               });
//                             },
//                             activeColor: Colors.black, // Black active color
//                             inactiveThumbColor: Colors.grey.shade300,
//                             inactiveTrackColor: Colors.grey.shade100,
//                           ),
//
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: _isLoading
//                                 ? null
//                                 : () {
//                               FocusScope.of(context).unfocus();
//                               if (_formKey.currentState!.validate()) {
//                                 _placeOrderDirectly();
//                               }
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red,
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                             ),
//                             child: const Text(
//                               "Place Order",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         if (_isLoading)
//           Container(
//             color: Colors.black.withOpacity(0.5),
//             child: const Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   CircularProgressIndicator(color: Colors.white),
//                   SizedBox(height: 12),
//                 ],
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   // --- Order Processing Logic ---
//
//   Future<void> _placeOrderDirectly() async {
//     setState(() => _isLoading = true);
//
//     String? redeemedCode;
//     int? redeemedPoints;
//     double? redeemedValue;
//
//     final prefs = await SharedPreferences.getInstance();
//     final laravelUserJson = prefs.getString('laravelUser');
//     final bool isLoggedIn = laravelUserJson != null;
//
//     if (isLoggedIn) {
//       if (_useLoyaltyPoints && _loyaltyPoints > 0) {
//         final redeemUri = Uri.parse('$localurl/api/points/redeem');
//         final token = prefs.getString('laravelToken');
//         if (token == null) {
//           Fluttertoast.showToast(msg: "Please log in first");
//           setState(() => _isLoading = false);
//           return;
//         }
//
//         final pointsToRedeem = (_loyaltyPoints < widget.finalAmount)
//             ? _loyaltyPoints
//             : widget.finalAmount.toInt();
//
//         try {
//           final redeemResponse = await http.post(
//             redeemUri,
//             headers: {
//               'Authorization': 'Bearer $token',
//               'Content-Type': 'application/json',
//             },
//             body: json.encode({"points_to_redeem": pointsToRedeem}),
//           );
//
//           if (redeemResponse.statusCode == 200) {
//             final redeemData = json.decode(redeemResponse.body);
//             redeemedValue = (redeemData['data']['discount_value'] as num).toDouble();
//             redeemedCode = redeemData['data']['redemption_code'];
//             redeemedPoints = pointsToRedeem;
//           } else {
//             if (kDebugMode) {
//               print("Failed to redeem points: ${redeemResponse.body}");
//             }
//             Fluttertoast.showToast(msg: "Failed to redeem points");
//             setState(() => _isLoading = false);
//             return;
//           }
//         } catch (e) {
//           if (kDebugMode) {
//             print("Error during point redemption: $e");
//           }
//           Fluttertoast.showToast(msg: "Error during point redemption");
//           setState(() => _isLoading = false);
//           return;
//         }
//       }
//     }
//
//     try {
//       String? userId;
//       if (isLoggedIn) {
//         final laravelUser = json.decode(laravelUserJson!);
//         userId = laravelUser['id'].toString();
//       }
//
//       final draftOrderId = await _createDraftOrder(redeemedCode, redeemedValue);
//       if (draftOrderId != null) {
//         final responseBody = await _completeDraftOrder(draftOrderId, _isCodSelected);
//         final responseData = json.decode(responseBody);
//
//         final shopifyOrderId = responseData['draft_order']?['order_id']?.toString() ??
//             responseData['order']?['id']?.toString() ??
//             draftOrderId;
//
//         if (isLoggedIn) {
//           await _processOrderInLaravel(
//             shopifyOrderId,
//             widget.originalAmount,
//             userId!,
//             redeemedPoints,
//             redeemedValue,
//             redeemedCode,
//           );
//         }
//
//         CartService.clearCart();
//         Fluttertoast.showToast(
//           msg: "Order placed successfully!",
//           backgroundColor: Colors.green,
//         );
//
//         if (mounted) {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(
//               builder: (_) => ThankYouScreen(orderNumber: shopifyOrderId),
//             ),
//                 (_) => false,
//           );
//         }
//       }
//     } catch (e) {
//       Fluttertoast.showToast(msg: "Error: ${e.toString()}", backgroundColor: Colors.red);
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _processOrderInLaravel(
//       String shopifyOrderId,
//       double originalAmount,
//       String userId,
//       int? redeemedPoints,
//       double? discountApplied,
//       String? discountCode,
//       ) async {
//     final prefs = await SharedPreferences.getInstance();
//     final String? token = prefs.getString('laravelToken');
//
//     if (token == null) {
//       if (kDebugMode) {
//         print("Laravel token not found in SharedPreferences");
//       }
//       return;
//     }
//
//     final payload = {
//       'user_id': userId,
//       'shopify_order_id': shopifyOrderId,
//       'total_amount': originalAmount.toStringAsFixed(2),
//       'status': 'paid',
//       'points_redeemed': redeemedPoints ?? 0,
//       'discount_applied': discountApplied ?? 0,
//       'discount_code': discountCode ?? widget.discountCode,
//     };
//
//     final uri = Uri.parse('$localurl/api/orders/process');
//
//     try {
//       final response = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode(payload),
//       );
//
//       if (kDebugMode && response.statusCode != 201) {
//         print("Laravel API Error: ${response.statusCode} - ${response.body}");
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print("Error processing Laravel order: $e");
//       }
//     }
//   }
//
//   Future<String?> _createDraftOrder(String? redeemedCode, double? redeemedValue) async {
//     final lineItems = widget.cartItems.map((product) {
//       return {
//         "variant_id": _extractVariantId(product.variantId),
//         "quantity": product.quantity,
//         "price": product.price,
//         "title": product.title,
//       };
//     }).toList();
//
//     List<String> orderTagsList = ["mobile-app-order"];
//     if (_isCodSelected) {
//       orderTagsList.add("COD");
//     }
//     final String orderTags = orderTagsList.join(', ');
//
//     // Define hardcoded defaults for Shopify's required address fields
//     // This uses the address string in the 'address1' field
//     const String defaultCity = "Lahore";
//     const String defaultCountry = "Pakistan";
//     const String defaultZip = "54000";
//
//     Map<String, dynamic> payload = {
//       "draft_order": {
//         "line_items": lineItems,
//         "email": _emailController.text,
//         "shipping_address": {
//           "first_name": _nameController.text.split(' ').first,
//           "last_name": _nameController.text.split(' ').length > 1
//               ? _nameController.text.split(' ').last
//               : '',
//           "address1": _addressController.text,
//           "city": defaultCity,
//           "country": defaultCountry,
//           "zip": defaultZip,
//           "phone": _phoneController.text
//         },
//         "billing_address": {
//           "first_name": _nameController.text.split(' ').first,
//           "last_name": _nameController.text.split(' ').length > 1
//               ? _nameController.text.split(' ').last
//               : '',
//           "address1": _addressController.text,
//           "city": defaultCity,
//           "country": defaultCountry,
//           "zip": defaultZip,
//           "phone": _phoneController.text
//         },
//         "note": "Order placed via achhafoods Store App",
//         "tags": orderTags,
//       }
//     };
//
//     if (redeemedCode != null && redeemedValue != null) {
//       payload["draft_order"]["applied_discount"] = {
//         "description": "Loyalty Points Redemption",
//         "value": redeemedValue.toStringAsFixed(2),
//         "value_type": "fixed_amount",
//         "amount": redeemedValue.toStringAsFixed(2),
//         "title": redeemedCode,
//       };
//     } else if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
//       payload["draft_order"]["applied_discount"] = {
//         "title": widget.discountCode,
//       };
//     }
//
//     final uri = Uri.parse(
//         'https://$shopifyStoreUrl/admin/api/$apiVersion/draft_orders.json');
//
//     final response = await http.post(
//       uri,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       },
//       body: json.encode(payload),
//     );
//
//     if (response.statusCode == 201) {
//       final jsonResponse = json.decode(response.body);
//       return jsonResponse['draft_order']['id'].toString();
//     } else {
//       throw Exception(
//           'Failed to create draft order: ${response.statusCode} - ${response.body}');
//     }
//   }
//
//   Future<String> _completeDraftOrder(String draftOrderId, bool isCod) async {
//     final Map<String, dynamic> body = {
//       "draft_order": {
//         "id": draftOrderId,
//         "payment_pending": isCod,
//       }
//     };
//
//     final uri = Uri.parse(
//         'https://$shopifyStoreUrl/admin/api/$apiVersion/draft_orders/$draftOrderId/complete.json');
//
//     final response = await http.put(
//       uri,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken,
//       },
//       body: json.encode(body),
//     );
//
//     if (response.statusCode == 200) {
//       return response.body;
//     } else {
//       throw Exception(
//           'Failed to complete draft order: ${response.statusCode} - ${response.body}');
//     }
//   }
//
//   String _extractVariantId(String variantGid) {
//     final parts = variantGid.split('/');
//     return parts.last;
//   }
// }