import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:achhafoods/screens/CartScreen/ThankYouScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/CartServices.dart';
import '../Consts/shopify_auth_service.dart';

class CheckoutScreen extends StatefulWidget {
  final List cartItems;
  final double originalAmount;
  final double finalAmount;
  final String? discountCode;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.finalAmount,
    required this.originalAmount,
    this.discountCode,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _discountCodeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // --- COUPON STATE ---
  final TextEditingController _couponCodeController = TextEditingController();
  String? _customDiscountCode;
  double _couponDiscountValue = 0.0;
  String _couponValueType = 'fixed_amount';
  // --------------------

  Map<String, dynamic>? customer;
  Map<String, dynamic>? laravelUser;
  final bool _isCodSelected = true;
  bool _isLoading = false;
  bool _useLoyaltyPoints = false;
  int _loyaltyPoints = 0;
  // NEW: Monetary value of available loyalty points (assuming 1 point = 1 unit of currency)
  double _loyaltyDiscountValue = 0.0;
  bool _isLoggedIn = false;

  late double _finalAmount;
  bool _hasAppliedDiscount = false;
  bool _discountApplied = false;

  final List<Map<String, String>> _savedAddresses = [];
  String? _selectedAddressKey;

  @override
  void initState() {
    super.initState();
    _checkLoginStatusAndLoadInfo();
    _finalAmount = widget.finalAmount;

    if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
      _discountCodeController.text = widget.discountCode!;
      _discountApplied = true;
      _hasAppliedDiscount = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _discountCodeController.dispose();
    _noteController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  // --- Core API and Data Loading Logic ---

  Future<void> _checkLoginStatusAndLoadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final laravelUserJson = prefs.getString('laravelUser');
    if (laravelUserJson != null) {
      setState(() {
        _isLoggedIn = true;
      });
      await _loadCustomerInfo();
    } else {
      setState(() {
        _isLoggedIn = false;
        _selectedAddressKey = 'new_address_option';
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDataWithGetAndBody(String email ) async {
    final uri = Uri.parse('$localurl/api/user-by-email');
    final body = json.encode({"email": email});

    final request = http.Request('GET', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // if (token != null) 'Authorization': 'Bearer $token',
      })
      ..body = body;

    try {
      final streamedResponse = await http.Client().send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (kDebugMode) print("API User Data (GET with Body): $responseData");
        return responseData;
      } else {
        if (kDebugMode) {
          print("Failed to fetch user data (GET with Body): ${response.statusCode} - ${response.body}");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching user data (GET with Body): $e");
      return null;
    }
  }

  void _populateAddressControllers(String fullAddress) {
    _addressController.text = fullAddress;
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final customerData = prefs.getString('customer');
    final laravelUserData = prefs.getString('laravelUser');
    // final String? laravelToken = prefs.getString('laravelToken');

    if (customerData != null && laravelUserData != null) {
      setState(() {
        customer = json.decode(customerData);
        laravelUser = json.decode(laravelUserData);
        final customerDetails = customer?['customer'] as Map<String, dynamic>?;
        if (customerDetails != null) {
          _emailController.text = customerDetails['email'] ?? '';
          _nameController.text = '${customerDetails['firstName'] ?? ''} ${customerDetails['lastName'] ?? ''}'.trim();
          _phoneController.text = laravelUser!['phone'] ?? '';
        }
      });

      if (_emailController.text.isNotEmpty) {
        final responseData = await _fetchUserDataWithGetAndBody(_emailController.text);

        final userData = responseData?['data'] as Map<String, dynamic>?;

        if (responseData?['status'] == true && userData != null) {
          final Map<String, dynamic>? addressesMap = userData['full_addresses'];
          final int loyaltyPoints = userData['loyalty_points'] ?? 0;

          setState(() {
            _loyaltyPoints = loyaltyPoints;
            // Assuming 1 point = 1 currency unit
            _loyaltyDiscountValue = loyaltyPoints.toDouble();
            _savedAddresses.clear();

            if (addressesMap != null) {
              addressesMap.forEach((label, fullAddress) {
                _savedAddresses.add({
                  'label': label,
                  'address': fullAddress.toString(),
                });
              });
            }

            if (_savedAddresses.isNotEmpty) {
              _selectedAddressKey = _savedAddresses.first['label'];
              _populateAddressControllers(_savedAddresses.first['address']!);
            } else {
              _selectedAddressKey = 'new_address_option';
              _addressController.clear();
            }

            _isLoggedIn = true;
            _recalculateFinalAmount();
          });
        }
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _selectedAddressKey = 'new_address_option';
        _addressController.clear();
      });
    }
  }

  // --- UPDATED: Coupon Validity Check (removed loyalty override) ---
  Future<void> _checkCouponValidity() async {
    final couponCode = _couponCodeController.text.trim();
    if (couponCode.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a coupon code.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final validationResult = await ShopifyAuthService.validateShopifyDiscountCode(couponCode);

      if (validationResult['valid'] == true) {
        final double value = validationResult['value'] as double;
        final String type = validationResult['value_type'] as String;

        // Calculate the actual discount amount
        double discountAmount;
        if (type == 'percentage') {
          discountAmount = widget.originalAmount * (value / 100);
        } else {
          // fixed_amount
          discountAmount = value;
        }

        // Ensure discount doesn't exceed order total
        discountAmount = discountAmount.clamp(0.0, widget.originalAmount);

        setState(() {
          _couponDiscountValue = discountAmount;
          _couponValueType = type;
          _customDiscountCode = couponCode;
          // IMPORTANT: Loyalty is no longer set to false here, allowing both to stack.
          _recalculateFinalAmount();
        });

        Fluttertoast.showToast(
          msg: "Coupon applied successfully! Discount: Rs. ${discountAmount.toStringAsFixed(2)}",
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        setState(() {
          _couponDiscountValue = 0.0;
          _customDiscountCode = null;
          _recalculateFinalAmount();
        });
        Fluttertoast.showToast(
            msg: validationResult['message'] ?? "Invalid coupon code",
            backgroundColor: Colors.red
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error checking coupon: $e");
      Fluttertoast.showToast(msg: "Error during coupon validation.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- Remove Coupon ---
  void _removeCoupon() {
    setState(() {
      _couponCodeController.clear();
      _couponDiscountValue = 0.0;
      _customDiscountCode = null;
      _recalculateFinalAmount();
    });
    Fluttertoast.showToast(msg: "Coupon removed");
  }


  // --- UPDATED: Recalculate function to handle both discounts combined ---
  void _recalculateFinalAmount() {
    double couponDiscount = _customDiscountCode != null ? _couponDiscountValue : 0.0;
    double loyaltyDiscount = 0.0;
    String appliedCodeDescription = "";

    // 1. Calculate Loyalty Discount (if toggle is on)
    if (_isLoggedIn && _useLoyaltyPoints && _loyaltyPoints > 0) {
      // Loyalty discount is the value of points, capped at the remaining amount
      // Since we combine them for Shopify, we can cap them at the original amount for display
      loyaltyDiscount = _loyaltyDiscountValue.clamp(0.0, widget.originalAmount);
      appliedCodeDescription = "Loyalty Points";
    }

    // 2. Calculate Coupon Discount and combine code description
    if (couponDiscount > 0) {
      if (appliedCodeDescription.isNotEmpty) {
        appliedCodeDescription = "COUPON (${_customDiscountCode!}) + $appliedCodeDescription";
      } else {
        appliedCodeDescription = _customDiscountCode!;
      }
    }

    double totalDiscount = couponDiscount + loyaltyDiscount;

    // The total discount must be capped at the original price
    totalDiscount = totalDiscount.clamp(0.0, widget.originalAmount);

    _finalAmount = (widget.originalAmount - totalDiscount);

    setState(() {
      _discountApplied = totalDiscount > 0;
      _hasAppliedDiscount = totalDiscount > 0;

      if (appliedCodeDescription.isNotEmpty) {
        _discountCodeController.text = appliedCodeDescription;
      } else if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
        // Fallback to original discount if no custom one is applied
        _discountCodeController.text = widget.discountCode!;
        _finalAmount = widget.finalAmount;
      } else {
        _discountCodeController.clear();
        _finalAmount = widget.originalAmount;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the total discount value for the display
    double totalAppliedDiscountValue = widget.originalAmount - _finalAmount;

    return Stack(
      children: [
        Scaffold(
          appBar: const CustomAppBar(),
          drawer: const CustomDrawer(),
          bottomNavigationBar: const NewNavigationBar(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: CustomColorTheme.CustomPrimaryAppColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  "Checkout",
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Order Summary ---
                        const SizedBox(height: 12),
                        const Text(
                          "Order Summary:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...widget.cartItems.map((product) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                  "${product.title} (x${product.quantity})"),
                            ),
                            Text(
                              "Rs. ${(product.price * product.quantity).toStringAsFixed(2)}",
                            ),
                          ],
                        )),

                        // Discount Display
                        if (_discountApplied && _finalAmount < widget.originalAmount)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Show the combined discount description
                                Flexible(
                                  child: Text(
                                    "Discount (${_discountCodeController.text}):",
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "- Rs. ${totalAppliedDiscountValue.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_customDiscountCode != null)
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: _removeCoupon,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Grand Total:",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Rs. ${_finalAmount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- COUPON CODE SECTION ---
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Apply Coupon",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _couponCodeController,
                                      decoration: InputDecoration(
                                        labelText: "Enter coupon code",
                                        hintText: "e.g., check100",
                                        border: const OutlineInputBorder(),
                                        enabled: !_isLoading && _customDiscountCode == null,
                                        suffixIcon: _customDiscountCode != null
                                            ? IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: null,
                                        )
                                            : null,
                                      ),
                                      onChanged: (value) {
                                        if (_customDiscountCode != null && value.trim() != _customDiscountCode) {
                                          setState(() {
                                            _couponDiscountValue = 0.0;
                                            _customDiscountCode = null;
                                            _recalculateFinalAmount();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 60,
                                    child: _customDiscountCode != null
                                        ? ElevatedButton(
                                      onPressed: _removeCoupon,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    )
                                        : ElevatedButton(
                                      onPressed: _isLoading ? null : _checkCouponValidity,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        _isLoading ? '...' : 'Apply',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_customDiscountCode != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Coupon applied: ${_couponValueType == 'percentage' ? '${_couponDiscountValue.toStringAsFixed(2)}%' : 'Rs. ${_couponDiscountValue.toStringAsFixed(2)}'} off",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Billing/Contact Info Fields ---
                        TextFormField(
                          controller: _nameController,
                          decoration:
                          const InputDecoration(labelText: "Full Name"),
                          validator: (value) =>
                          value!.isEmpty ? "Name is required" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration:
                          const InputDecoration(labelText: "Email Address"),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value!.isEmpty) return "Email is required";
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return "Enter valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration:
                          const InputDecoration(labelText: "Phone Number"),
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                          value!.isEmpty ? "Phone is required" : null,
                        ),
                        const SizedBox(height: 12),
                        if (_isLoggedIn && _savedAddresses.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Shipping Address',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black),
                                ),
                              ),
                              initialValue: _selectedAddressKey,
                              items: [
                                ..._savedAddresses.map((addr) => DropdownMenuItem(
                                  value: addr['label'],
                                  // --- START FIX ---
                                  child: SizedBox(
                                    // Constrain the width of the Text widget within the dropdown item
                                    // The constraint should be the width of the screen minus padding.
                                    // Using a FractionallySizedBox set to 0.8 or 0.9 of the available width is safer.
                                    // Using MediaQuery.of(context).size.width * 0.75 as a safe constraint.
                                    width: MediaQuery.of(context).size.width * 0.75,
                                    child: Text(
                                        '${addr['label']!}: ${addr['address']!}',
                                        overflow: TextOverflow.ellipsis // Ellipsis will now correctly apply
                                    ),
                                  ),
                                  // --- END FIX ---
                                )),
                                const DropdownMenuItem(
                                  value: 'new_address_option',
                                  child: Text('➕ Write a New Address'),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedAddressKey = newValue;
                                  if (newValue == 'new_address_option') {
                                    _addressController.clear();
                                  } else {
                                    final selected = _savedAddresses.firstWhere((addr) => addr['label'] == newValue);
                                    _populateAddressControllers(selected['address']!);
                                  }
                                });
                              },
                              validator: (value) =>
                              value == null ? "Please select an address" : null,
                            ),
                          ),

// The TextFormField below this is now correct and should not cause overflow.
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                              labelText: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty
                                  ? "Full Shipping Address (Required)"
                                  : "Selected Address"
                          ),
                          maxLines: 3,
                          validator: (value) =>
                          value!.isEmpty ? "Address is required" : null,
                          enabled: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty,
                          keyboardType: TextInputType.streetAddress,
                        ),
                        const SizedBox(height: 20),
                        // --- Order Note field ---
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: "Order Note (Optional)",
                            hintText: "Note...",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 1,
                        ),
                        // const SizedBox(height: 20),
                        //
                        // // --- Loyalty Points Toggle (Always enabled if points available) ---
                        // if (_isLoggedIn)
                        //   Container(
                        //     padding: const EdgeInsets.all(12),
                        //     decoration: BoxDecoration(
                        //       border: Border.all(color: Colors.grey.shade300),
                        //       borderRadius: BorderRadius.circular(8),
                        //     ),
                        //     child: SwitchListTile(
                        //       title: const Text(
                        //         "Use Loyalty Points",
                        //         style: TextStyle(fontWeight: FontWeight.bold),
                        //       ),
                        //       subtitle: Text(
                        //         // Show monetary value for clarity
                        //         "Available: $_loyaltyPoints points (Rs. ${_loyaltyDiscountValue.toStringAsFixed(2)})",
                        //         style: TextStyle(
                        //           color: _loyaltyPoints >= 100 ? Colors.green : Colors.grey,
                        //         ),
                        //       ),
                        //       value: _useLoyaltyPoints,
                        //       onChanged: (_loyaltyPoints < 100)
                        //           ? (val) {
                        //         Fluttertoast.showToast(
                        //           msg: "You need at least 100 loyalty points to use them.",
                        //           backgroundColor: Colors.red,
                        //           toastLength: Toast.LENGTH_LONG,
                        //         );
                        //       }
                        //           : (val) {
                        //         setState(() {
                        //           _useLoyaltyPoints = val;
                        //           _recalculateFinalAmount();
                        //         });
                        //       },
                        //       activeThumbColor: Colors.black,
                        //       inactiveThumbColor: Colors.grey.shade300,
                        //       inactiveTrackColor: Colors.grey.shade100,
                        //       // No longer disabled if coupon is present
                        //       tileColor: null,
                        //     ),
                        //   ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              FocusScope.of(context).unfocus();
                              if (_formKey.currentState!.validate()) {
                                _placeOrderDirectly();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Place Order",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    "Processing...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- UPDATED: Order Processing Logic for Combined Discount ---

  Future<void> _placeOrderDirectly() async {
    setState(() => _isLoading = true);

    String? redeemedCode;
    int? redeemedPoints = 0;
    double loyaltyDiscountRedeemed = 0.0;

    // Start with coupon discount and code
    double finalDiscountValue = _couponDiscountValue;
    String finalDiscountCode = _customDiscountCode ?? "";

    final prefs = await SharedPreferences.getInstance();
    final laravelUserJson = prefs.getString('laravelUser');
    final bool isLoggedIn = laravelUserJson != null;

    // --- STEP 1: Redeem Loyalty Points (if toggled) ---
    if (isLoggedIn && _useLoyaltyPoints && _loyaltyPoints > 0) {

      // Calculate how much discount is attributed to loyalty points based on the final price calculation
      double totalDiscountApplied = widget.originalAmount - _finalAmount;

      // Discount provided by coupon:
      double couponValue = _customDiscountCode != null ? _couponDiscountValue : 0.0;

      // Loyalty's actual contribution to the final discount
      double loyaltyContribution = totalDiscountApplied - couponValue;

      // If loyalty contributed something (it might be less than _loyaltyDiscountValue if clipped by order total)
      if (loyaltyContribution > 0) {
        final redeemUri = Uri.parse('$localurl/api/points/redeem');
        // final token = prefs.getString('laravelToken');
        // if (token == null) {
        //   Fluttertoast.showToast(msg: "Please log in first");
        //   setState(() => _isLoading = false);
        //   return;
        // }

        // We redeem points corresponding to the monetary value contributed
        final pointsToRedeem = (_loyaltyPoints < widget.finalAmount)
            ? _loyaltyPoints
            : widget.finalAmount.toInt();
        print('Points to redeem: $pointsToRedeem');


        if (pointsToRedeem > 0) {
          try {
            final redeemResponse = await http.post(
              redeemUri,
              headers: {
                // 'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: json.encode({"points_to_redeem": pointsToRedeem}),
            );

            if (redeemResponse.statusCode == 200) {
              final redeemData = json.decode(redeemResponse.body);
              loyaltyDiscountRedeemed = (redeemData['data']['discount_value'] as num).toDouble();
              redeemedCode = redeemData['data']['redemption_code'];
              redeemedPoints = pointsToRedeem;

              // Only update if redemption was successful
              finalDiscountValue += loyaltyDiscountRedeemed;
              finalDiscountCode = (finalDiscountCode.isEmpty) ? "LOYALTY" : "COUPON+LOYALTY";

            } else {
              if (kDebugMode) {
                print("Failed to redeem points: ${redeemResponse.body}");
              }
              Fluttertoast.showToast(msg: "Failed to redeem points");
              // Continue processing without loyalty discount if redemption failed
            }
          } catch (e) {
            if (kDebugMode) {
              print("Error during point redemption: $e");
            }
            Fluttertoast.showToast(msg: "Error during point redemption");
            // Continue processing without loyalty discount if API call failed
          }
        }
      }
    }

    // --- STEP 2: Handle Original Widget Discount (Fallback if no custom discount applied) ---
    if (finalDiscountCode.isEmpty && widget.discountCode != null && widget.discountCode!.isNotEmpty) {
      finalDiscountCode = widget.discountCode!;
      finalDiscountValue = widget.originalAmount - widget.finalAmount;
    }


    try {
      String? userId;
      if (isLoggedIn) {
        final laravelUser = json.decode(laravelUserJson);
        userId = laravelUser['id'].toString();
      }

      // Create Draft Order with combined discount (Shopify only accepts one discount object)
      final draftOrderId = await _createDraftOrder(
        finalDiscountCode,
        finalDiscountValue,
      );

      if (draftOrderId != null) {
        final responseBody = await _completeDraftOrder(draftOrderId, _isCodSelected);
        final responseData = json.decode(responseBody);

        final shopifyOrderId = responseData['draft_order']?['order_id']?.toString() ??
            responseData['order']?['id']?.toString() ??
            draftOrderId;

        if (isLoggedIn) {
          // Process in Laravel (send the final combined discount for tracking)
          await _processOrderInLaravel(
            shopifyOrderId,
            widget.originalAmount,
            userId!,
            redeemedPoints, // Points redeemed from loyalty (0 if none)
            finalDiscountValue, // Total combined monetary discount applied
            finalDiscountCode, // Combined code string
          );
        }

        CartService.clearCart();
        Fluttertoast.showToast(
          msg: "Order placed successfully!",
          backgroundColor: Colors.green,
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ThankYouScreen(orderNumber: shopifyOrderId),
            ),
                (_) => false,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}", backgroundColor: Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processOrderInLaravel(
      String shopifyOrderId,
      double originalAmount,
      String userId,
      int? redeemedPoints,
      double? discountApplied,
      String? discountCode,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('laravelToken');

    if (token == null) {
      if (kDebugMode) {
        print("Laravel token not found in SharedPreferences");
      }
      return;
    }

    final payload = {
      'user_id': userId,
      'shopify_order_id': shopifyOrderId,
      'total_amount': originalAmount.toStringAsFixed(2),
      'status': 'paid',
      'points_redeemed': redeemedPoints ?? 0,
      'discount_applied': discountApplied ?? 0,
      'discount_code': discountCode ?? widget.discountCode,
    };

    final uri = Uri.parse('$localurl/api/orders/process');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      if (kDebugMode && response.statusCode != 201) {
        print("Laravel API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing Laravel order: $e");
      }
    }
  }

  // UPDATED: Use combined discountValue and discountCode
  Future<String?> _createDraftOrder(String? discountCode, double? discountValue) async {
    final lineItems = widget.cartItems.map((product) {
      return {
        "variant_id": _extractVariantId(product.variantId),
        "quantity": product.quantity,
        "price": product.price,
        "title": product.title,
      };
    }).toList();

    List<String> orderTagsList = ["mobile-app"];
    if (_isCodSelected) {
      orderTagsList.add("COD");
    }
    final String orderTags = orderTagsList.join(', ');

    const String defaultCity = "Lahore";
    const String defaultCountry = "Pakistan";
    const String defaultZip = "54000";

    final String userNote = _noteController.text.trim();
    final String finalNote = userNote;

    Map<String, dynamic> payload = {
      "draft_order": {
        "line_items": lineItems,
        "email": _emailController.text,
        "shipping_address": {
          "first_name": _nameController.text.split(' ').first,
          "last_name": _nameController.text.split(' ').length > 1
              ? _nameController.text.split(' ').last
              : '',
          "address1": _addressController.text,
          "city": defaultCity,
          "country": defaultCountry,
          "zip": defaultZip,
          "phone": _phoneController.text
        },
        "billing_address": {
          "first_name": _nameController.text.split(' ').first,
          "last_name": _nameController.text.split(' ').length > 1
              ? _nameController.text.split(' ').last
              : '',
          "address1": _addressController.text,
          "city": defaultCity,
          "country": defaultCountry,
          "zip": defaultZip,
          "phone": _phoneController.text
        },
        "note": finalNote,
        "tags": orderTags,
      }
    };

    // Apply the combined discount as a single fixed amount discount
    if (discountCode != null && discountValue != null && discountValue > 0) {
      payload["draft_order"]["applied_discount"] = {
        "description": "Combined Discount",
        "value": discountValue.toStringAsFixed(2),
        "value_type": "fixed_amount",
        "amount": discountValue.toStringAsFixed(2),
        "title": discountCode, // This holds the combined description (COUPON+LOYALTY)
      };
    }
    else if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
      payload["draft_order"]["applied_discount"] = {
        "title": widget.discountCode,
      };
    }

    final uri = Uri.parse(
        'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken_const,
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 201) {
      final jsonResponse = json.decode(response.body);
      return jsonResponse['draft_order']['id'].toString();
    } else {
      throw Exception(
          'Failed to create draft order: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _completeDraftOrder(String draftOrderId, bool isCod) async {
    final Map<String, dynamic> body = {
      "draft_order": {
        "id": draftOrderId,
        // "payment_pending": isCod,
      }
    };

    // final uri = Uri.parse(
    //     'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$draftOrderId/complete.json');
    final uri = Uri.parse(
        'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$draftOrderId/complete.json?payment_pending=true');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken_const,
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception(
          'Failed to complete draft order: ${response.statusCode} - ${response.body}');
    }
  }

  String _extractVariantId(String variantGid) {
    final parts = variantGid.split('/');
    return parts.last;
  }
}























//
//
//
//
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
//   // --- ADDED ---: Controller for the optional order note.
//   final TextEditingController _noteController = TextEditingController();
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
//   // --- ADDED ---: Dispose method to clean up controllers.
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _addressController.dispose();
//     _phoneController.dispose();
//     _nameController.dispose();
//     _discountCodeController.dispose();
//     _noteController.dispose(); // Dispose the new controller
//     super.dispose();
//   }
//
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
//                         // --- ADDED ---: Optional note field.
//                         TextFormField(
//                           controller: _noteController,
//                           decoration: const InputDecoration(
//                             labelText: "Order Note (Optional)",
//                             hintText: "Note...",
//                             border: OutlineInputBorder(),
//                           ),
//                           maxLines: 1, // Allows for a slightly larger text area
//                         ),
//                         const SizedBox(height: 20),
//
//                         // --- Toggle Buttons (Black and White) ---
//                         SwitchListTile(
//                           title: const Text("Cash on Delivery (COD)"),
//                           value: _isCodSelected,
//
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
//                             onChanged: (_loyaltyPoints >= 100)
//                                 ? (val) {
//                               setState(() {
//                                 _useLoyaltyPoints = val;
//                                 _recalculateFinalAmount();
//                               });
//                             }
//                                 : (val) {
//                               Fluttertoast.showToast(
//                                 msg: "You need at least 100 loyalty points to use them.",
//                                 backgroundColor: Colors.red,
//                                 toastLength: Toast.LENGTH_LONG,
//                               );
//                             },
//                             activeColor: Colors.black,
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
//     List<String> orderTagsList = ["mobile-app"];
//     if (_isCodSelected) {
//       orderTagsList.add("COD");
//     }
//     final String orderTags = orderTagsList.join(', ');
//
//     // This uses the address string in the 'address1' field
//     const String defaultCity = "Lahore";
//     const String defaultCountry = "Pakistan";
//     const String defaultZip = "54000";
//
//     // --- MODIFIED ---: Dynamic note logic.
//     // final String baseNote = "Order placed via AchaMart Store Mobile App";
//     final String userNote = _noteController.text.trim();
//
//     // Combine the notes if the user added one.
//     final String finalNote = userNote;
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
//         "note": finalNote, // Use the dynamically created note
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
//         'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json');
//
//     final response = await http.post(
//       uri,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken_const,
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
//         'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$draftOrderId/complete.json');
//
//     final response = await http.put(
//       uri,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken_const,
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