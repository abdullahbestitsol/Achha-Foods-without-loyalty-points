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
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/CartServices.dart';
import '../../services/DynamicContentCache.dart';
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
  final TextEditingController _couponCodeController = TextEditingController();
  String? _customDiscountCode;
  double _couponDiscountValue = 0.0;
  double _deliveryCharges = 0.0;

  Map<String, dynamic>? customer;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  late double _finalAmount;
  bool _discountApplied = false;

  final List<Map<String, String>> _savedAddresses = [];
  String? _selectedAddressKey;

  @override
  void initState() {
    super.initState();
    _checkLoginStatusAndLoadInfo();

    if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
      _discountCodeController.text = widget.discountCode!;
      _customDiscountCode = widget.discountCode;
      if (widget.originalAmount > widget.finalAmount) {
        _couponDiscountValue = widget.originalAmount - widget.finalAmount;
      }
    }

    _recalculateFinalAmount();
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

  Future<void> _checkLoginStatusAndLoadInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final customerJson = prefs.getString('shopifyCustomer') ?? prefs.getString('customer');

    if (customerJson != null) {
      setState(() => _isLoggedIn = true);
      _loadCustomerInfoFromLocal(customerJson);
    } else {
      setState(() {
        _isLoggedIn = false;
        _selectedAddressKey = 'new_address_option';
      });
    }
  }

  void _loadCustomerInfoFromLocal(String jsonString) {
    try {
      final data = json.decode(jsonString);
      final cust = data['customer'];

      if (cust != null) {
        _emailController.text = cust['email'] ?? '';
        _nameController.text = '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim();
        _phoneController.text = cust['phone'] ?? '';

        List<dynamic> addresses = [];
        if (cust['addresses'] != null) {
          addresses = (cust['addresses'] is List) ? cust['addresses'] : (cust['addresses']['nodes'] ?? []);
        }

        _savedAddresses.clear();
        for (var addr in addresses) {
          List<String> parts = [];
          if (addr['address1'] != null) parts.add(addr['address1']);
          if (addr['city'] != null) parts.add(addr['city']);
          if (addr['zip'] != null) parts.add(addr['zip']);
          if (addr['country'] != null) parts.add(addr['country']);

          String fullStr = parts.join(', ');
          if (fullStr.isNotEmpty) {
            _savedAddresses.add({'label': addr['id']?.toString() ?? addr['address1'], 'address': fullStr});
          }
        }

        setState(() {
          if (_savedAddresses.isNotEmpty) {
            _selectedAddressKey = _savedAddresses.first['label'];
            _addressController.text = _savedAddresses.first['address']!;
          } else {
            _selectedAddressKey = 'new_address_option';
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error parsing customer data: $e");
    }
  }

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
        final double value = (validationResult['value'] as num).toDouble();
        final String type = validationResult['value_type'] as String;

        double calculatedDiscount;
        if (type == 'percentage') {
          calculatedDiscount = widget.originalAmount * (value / 100);
        } else {
          calculatedDiscount = value;
        }

        setState(() {
          _customDiscountCode = couponCode;
          _couponDiscountValue = calculatedDiscount;
          _discountCodeController.text = couponCode;
          _recalculateFinalAmount();
        });

        Fluttertoast.showToast(msg: "Coupon Applied!", backgroundColor: Colors.green);
      } else {
        Fluttertoast.showToast(msg: validationResult['message'] ?? "Invalid code", backgroundColor: Colors.red);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error validating coupon");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _recalculateFinalAmount() {
    // Access provider inside the method
    final dynamicCache = Provider.of<DynamicContentCache>(context, listen: false);

    setState(() {
      double discountToApply = _couponDiscountValue.clamp(0.0, widget.originalAmount);
      double subTotal = widget.originalAmount - discountToApply;

      // 1. Get the dynamic threshold from cache (e.g., "850")
      // If cache is empty or invalid, it defaults to 850.0
      double freeDeliveryThreshold = double.tryParse(dynamicCache.getDeliveryPrize() ?? '') ?? 850.0;

      // 2. Use the dynamic threshold to decide if we apply the static 200 charge
      if (subTotal < freeDeliveryThreshold) {
        _deliveryCharges = 200.0; // Static charge
      } else {
        _deliveryCharges = 0.0;
      }

      _finalAmount = subTotal + _deliveryCharges;
      _discountApplied = discountToApply > 0;
    });
  }

  void _removeCoupon() {
    setState(() {
      _couponCodeController.clear();
      _customDiscountCode = null;
      _couponDiscountValue = 0.0;
      _discountCodeController.clear();
      _recalculateFinalAmount();
    });
    Fluttertoast.showToast(msg: "Coupon removed");
  }

  Future<String?> _createDraftOrder(String? code, double discount) async {
    final lineItems = widget.cartItems.map((p) => {
      "variant_id": p.variantId.split('/').last,
      "quantity": p.quantity,
    }).toList();

    Map<String, dynamic> payload = {
      "draft_order": {
        "line_items": lineItems,
        "email": _emailController.text,
        "note": _noteController.text,
        "shipping_address": {
          "first_name": _nameController.text,
          "address1": _addressController.text,
          "city": "Lahore",
          "country": "Pakistan",
          "phone": _phoneController.text
        },
        "use_customer_default_address": false,
        "tags": "mobile-app, COD",
        "shipping_line": {
          "title": _deliveryCharges > 0 ? "Standard Delivery" : "Free Delivery",
          "price": _deliveryCharges.toStringAsFixed(2),
          "code": _deliveryCharges > 0 ? "STD" : "FREE"
        }
      }
    };

    if (code != null && discount > 0) {
      payload["draft_order"]["applied_discount"] = {
        "description": "Coupon: $code",
        "value": discount.toStringAsFixed(2),
        "value_type": "fixed_amount",
        "title": code
      };
    }

    final response = await http.post(
      Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json'),
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': adminAccessToken_const
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body)['draft_order']['id'].toString();
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    double displayDiscountValue = _discountApplied ? _couponDiscountValue : 0.0;

    return Stack(
      children: [
        Scaffold(
          appBar: const CustomAppBar(),
          drawer: const CustomDrawer(),
          bottomNavigationBar: const NewNavigationBar(),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: CustomColorTheme.CustomPrimaryAppColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text("Checkout", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Order Summary:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...widget.cartItems.map((product) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: Text("${product.title} (x${product.quantity})")),
                              Text("Rs. ${(product.price * product.quantity).toStringAsFixed(2)}"),
                            ],
                          ),
                        )),

                        if (_discountApplied)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Discount (${_discountCodeController.text}):", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                Text("- Rs. ${displayDiscountValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Delivery Charges:", style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                _deliveryCharges > 0
                                    ? "Rs. ${_deliveryCharges.toStringAsFixed(2)}"
                                    : "Free",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _deliveryCharges > 0 ? Colors.black : Colors.green
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Grand Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("Rs. ${_finalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Apply Coupon", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _couponCodeController,
                                      decoration: const InputDecoration(hintText: "Enter code", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                      enabled: _customDiscountCode == null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : (_customDiscountCode != null ? _removeCoupon : _checkCouponValidity),
                                    style: ElevatedButton.styleFrom(backgroundColor: _customDiscountCode != null ? Colors.red : Colors.black),
                                    child: Text(_customDiscountCode != null ? "Remove" : "Apply", style: const TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- REQUIRED FIELD: NAME ---
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: "Full Name*", border: OutlineInputBorder()),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Full Name is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // --- REQUIRED FIELD: EMAIL ---
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: "Email Address*", border: OutlineInputBorder()),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Email is required";
                            if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(v)) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // --- REQUIRED FIELD: PHONE ---
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: "Phone Number*", border: OutlineInputBorder()),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Phone number is required";
                            if (v.trim().length < 7) return "Please enter a valid phone number";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        if (_isLoggedIn && _savedAddresses.isNotEmpty)
                          DropdownButtonFormField<String>(
                            value: _selectedAddressKey,
                            decoration: const InputDecoration(labelText: "Select Saved Address", border: OutlineInputBorder()),
                            items: [
                              ..._savedAddresses.map((addr) => DropdownMenuItem(value: addr['label'], child: Text(addr['address']!, overflow: TextOverflow.ellipsis))),
                              const DropdownMenuItem(value: 'new_address_option', child: Text("Enter a new address")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedAddressKey = val;
                                if (val != 'new_address_option') {
                                  _addressController.text = _savedAddresses.firstWhere((e) => e['label'] == val)['address']!;
                                } else {
                                  _addressController.clear();
                                }
                              });
                            },
                          ),
                        const SizedBox(height: 12),

                        // --- REQUIRED FIELD: ADDRESS ---
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: "Shipping Address Details*", border: OutlineInputBorder()),
                          maxLines: 2,
                          enabled: _selectedAddressKey == 'new_address_option' || !_isLoggedIn,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Shipping address is required";
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: "Order Notes (Optional)",
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              // Validates all fields using the Form key
                              if (_formKey.currentState!.validate()) {
                                _placeOrderDirectly();
                              } else {
                                Fluttertoast.showToast(msg: "Please fill all required fields correctly");
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text("Place Order", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Future<void> _placeOrderDirectly() async {
    setState(() => _isLoading = true);
    try {
      final draftId = await _createDraftOrder(_customDiscountCode, _couponDiscountValue);
      if (draftId != null) {
        final response = await _completeDraftOrder(draftId);
        final data = json.decode(response);
        final orderId = data['draft_order']?['order_id']?.toString() ?? draftId;

        CartService.clearCart();
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ThankYouScreen(orderNumber: orderId)), (r) => false);
      } else {
        Fluttertoast.showToast(msg: "Failed to create order. Please try again.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Checkout Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _completeDraftOrder(String id) async {
    final response = await http.put(
      Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$id/complete.json?payment_pending=true'),
      headers: {'Content-Type': 'application/json', 'X-Shopify-Access-Token': adminAccessToken_const},
    );
    if (response.statusCode == 200) return response.body;
    throw Exception("Completion failed");
  }
}

// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
// import 'package:achhafoods/screens/Consts/appBar.dart';
// import 'package:achhafoods/screens/Consts/conts.dart';
// import 'package:achhafoods/screens/Drawer/Drawer.dart';
// import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:achhafoods/screens/CartScreen/ThankYouScreen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../services/CartServices.dart';
// import '../Consts/shopify_auth_service.dart';
//
// class CheckoutScreen extends StatefulWidget {
//   final List cartItems;
//   final double originalAmount;
//   final double finalAmount;
//   final String? discountCode;
//
//   const CheckoutScreen({
//     super.key,
//     required this.cartItems,
//     required this.finalAmount,
//     required this.originalAmount,
//     this.discountCode,
//   });
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
//   final TextEditingController _noteController = TextEditingController();
//
//   final TextEditingController _couponCodeController = TextEditingController();
//   String? _customDiscountCode;
//   double _couponDiscountValue = 0.0;
//
//   Map<String, dynamic>? customer;
//   bool _isLoading = false;
//   bool _isLoggedIn = false;
//
//   late double _finalAmount;
//   bool _discountApplied = false;
//
//   final List<Map<String, String>> _savedAddresses = [];
//   String? _selectedAddressKey;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkLoginStatusAndLoadInfo();
//
//     // Initialize amounts
//     _finalAmount = widget.finalAmount;
//     if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
//       _discountCodeController.text = widget.discountCode!;
//       _discountApplied = true;
//       // Calculate initial discount value from passed props
//       _couponDiscountValue = widget.originalAmount - widget.finalAmount;
//       _customDiscountCode = widget.discountCode;
//     }
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _addressController.dispose();
//     _phoneController.dispose();
//     _nameController.dispose();
//     _discountCodeController.dispose();
//     _noteController.dispose();
//     _couponCodeController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _checkLoginStatusAndLoadInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     final customerJson = prefs.getString('shopifyCustomer') ?? prefs.getString('customer');
//
//     if (customerJson != null) {
//       setState(() => _isLoggedIn = true);
//       _loadCustomerInfoFromLocal(customerJson);
//     } else {
//       setState(() {
//         _isLoggedIn = false;
//         _selectedAddressKey = 'new_address_option';
//       });
//     }
//   }
//
//   void _loadCustomerInfoFromLocal(String jsonString) {
//     try {
//       final data = json.decode(jsonString);
//       final cust = data['customer'];
//
//       if (cust != null) {
//         _emailController.text = cust['email'] ?? '';
//         _nameController.text = '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim();
//         _phoneController.text = cust['phone'] ?? '';
//
//         List<dynamic> addresses = [];
//         if (cust['addresses'] != null) {
//           addresses = (cust['addresses'] is List) ? cust['addresses'] : (cust['addresses']['nodes'] ?? []);
//         }
//
//         _savedAddresses.clear();
//         for (var addr in addresses) {
//           List<String> parts = [];
//           if (addr['address1'] != null) parts.add(addr['address1']);
//           if (addr['city'] != null) parts.add(addr['city']);
//           if (addr['zip'] != null) parts.add(addr['zip']);
//           if (addr['country'] != null) parts.add(addr['country']);
//
//           String fullStr = parts.join(', ');
//           if (fullStr.isNotEmpty) {
//             _savedAddresses.add({'label': addr['id']?.toString() ?? addr['address1'], 'address': fullStr});
//           }
//         }
//
//         setState(() {
//           if (_savedAddresses.isNotEmpty) {
//             _selectedAddressKey = _savedAddresses.first['label'];
//             _addressController.text = _savedAddresses.first['address']!;
//           } else {
//             _selectedAddressKey = 'new_address_option';
//           }
//         });
//       }
//     } catch (e) {
//       if (kDebugMode) print("Error parsing customer data: $e");
//     }
//   }
//
//   Future<void> _checkCouponValidity() async {
//     final couponCode = _couponCodeController.text.trim();
//     if (couponCode.isEmpty) {
//       Fluttertoast.showToast(msg: "Please enter a coupon code.");
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       if (kDebugMode) print('🔍 Validating Coupon: $couponCode');
//
//       final validationResult = await ShopifyAuthService.validateShopifyDiscountCode(couponCode);
//
//       if (kDebugMode) print('📦 Validation Result: $validationResult');
//
//       if (validationResult['valid'] == true) {
//         // Ensure we handle the value safely as a double
//         final double value = (validationResult['value'] as num).toDouble();
//         final String type = validationResult['value_type'] as String;
//
//         double calculatedDiscount;
//         if (type == 'percentage') {
//           calculatedDiscount = widget.originalAmount * (value / 100);
//           if (kDebugMode) print('🔢 Perc Discount: $value% of ${widget.originalAmount} = $calculatedDiscount');
//         } else {
//           calculatedDiscount = value;
//           if (kDebugMode) print('🔢 Fixed Discount: $calculatedDiscount');
//         }
//
//         setState(() {
//           _customDiscountCode = couponCode;
//           _couponDiscountValue = calculatedDiscount;
//           _discountCodeController.text = couponCode;
//           _recalculateFinalAmount(); // This updates _finalAmount and _discountApplied
//         });
//
//         Fluttertoast.showToast(msg: "Coupon Applied!", backgroundColor: Colors.green);
//       } else {
//         if (kDebugMode) print('❌ Coupon Invalid: ${validationResult['message']}');
//         Fluttertoast.showToast(msg: validationResult['message'] ?? "Invalid code", backgroundColor: Colors.red);
//       }
//     } catch (e) {
//       if (kDebugMode) print('🔥 Coupon Exception: $e');
//       Fluttertoast.showToast(msg: "Error validating coupon");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _recalculateFinalAmount() {
//     setState(() {
//       // 1. Calculate how much to take off
//       double discountToApply = _couponDiscountValue.clamp(0.0, widget.originalAmount);
//
//       // 2. Update the final amount state
//       _finalAmount = widget.originalAmount - discountToApply;
//
//       // 3. Mark as applied if discount is greater than 0
//       _discountApplied = discountToApply > 0;
//
//       if (kDebugMode) {
//         print('♻️ Recalculated: Original: ${widget.originalAmount}, Discount: $discountToApply, Final: $_finalAmount');
//       }
//     });
//   }
//
//   Future<String?> _createDraftOrder(String? code, double discount) async {
//     if (kDebugMode) print('📝 Creating Draft Order with Code: $code, Discount: $discount');
//
//     final lineItems = widget.cartItems.map((p) => {
//       "variant_id": p.variantId.split('/').last,
//       "quantity": p.quantity,
//     }).toList();
//
//     Map<String, dynamic> payload = {
//       "draft_order": {
//         "line_items": lineItems,
//         "email": _emailController.text,
//         "shipping_address": {
//           "first_name": _nameController.text,
//           "address1": _addressController.text,
//           "city": "Lahore",
//           "country": "Pakistan",
//           "phone": _phoneController.text
//         },
//         "use_customer_default_address": false,
//         "tags": "mobile-app, COD",
//       }
//     };
//
//     // CRITICAL: This sends the discount to Shopify Admin
//     if (code != null && discount > 0) {
//       payload["draft_order"]["applied_discount"] = {
//         "description": "Coupon: $code",
//         "value": discount.toStringAsFixed(2),
//         "value_type": "fixed_amount",
//         "title": code
//       };
//     }
//
//     final response = await http.post(
//       Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json'),
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken_const
//       },
//       body: json.encode(payload),
//     );
//
//     if (kDebugMode) print('📥 Draft Order Response Status: ${response.statusCode}');
//
//     if (response.statusCode == 201) {
//       return json.decode(response.body)['draft_order']['id'].toString();
//     } else {
//       if (kDebugMode) print('📥 Draft Order Error: ${response.body}');
//       return null;
//     }
//   }
//
//   void _removeCoupon() {
//     setState(() {
//       _couponCodeController.clear();
//       _customDiscountCode = null;
//       _couponDiscountValue = 0.0;
//       _discountCodeController.clear();
//       _recalculateFinalAmount();
//     });
//     Fluttertoast.showToast(msg: "Coupon removed");
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double displayDiscountValue = widget.originalAmount - _finalAmount;
//
//     return Stack(
//       children: [
//         Scaffold(
//           appBar: const CustomAppBar(),
//           drawer: const CustomDrawer(),
//           bottomNavigationBar: const NewNavigationBar(),
//           body: Column(
//             children: [
//               Container(
//                 width: double.infinity,
//                 color: CustomColorTheme.CustomPrimaryAppColor,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 alignment: Alignment.center,
//                 child: const Text("Checkout", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
//               ),
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text("Order Summary:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                         const SizedBox(height: 8),
//                         ...widget.cartItems.map((product) => Padding(
//                           padding: const EdgeInsets.symmetric(vertical: 2),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Flexible(child: Text("${product.title} (x${product.quantity})")),
//                               Text("Rs. ${(product.price * product.quantity).toStringAsFixed(2)}"),
//                             ],
//                           ),
//                         )),
//                         if (_discountApplied)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 8.0),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text("Discount (${_discountCodeController.text}):", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
//                                 Text("- Rs. ${displayDiscountValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
//                               ],
//                             ),
//                           ),
//                         const Divider(),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text("Grand Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                             Text("Rs. ${_finalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//
//                         // COUPON SECTION
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text("Apply Coupon", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
//                               const SizedBox(height: 8),
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: TextFormField(
//                                       controller: _couponCodeController,
//                                       decoration: const InputDecoration(hintText: "Enter code", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
//                                       enabled: _customDiscountCode == null,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 8),
//                                   ElevatedButton(
//                                     onPressed: _isLoading ? null : (_customDiscountCode != null ? _removeCoupon : _checkCouponValidity),
//                                     style: ElevatedButton.styleFrom(backgroundColor: _customDiscountCode != null ? Colors.red : Colors.black),
//                                     child: Text(_customDiscountCode != null ? "Remove" : "Apply", style: const TextStyle(color: Colors.white)),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//
//                         TextFormField(
//                           controller: _nameController,
//                           decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
//                           validator: (v) => v!.isEmpty ? "Required" : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _emailController,
//                           decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
//                           validator: (v) => (v == null || !v.contains('@')) ? "Invalid email" : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _phoneController,
//                           decoration: const InputDecoration(labelText: "Phone", border: OutlineInputBorder()),
//                           validator: (v) => v!.isEmpty ? "Required" : null,
//                         ),
//                         const SizedBox(height: 12),
//
//                         if (_isLoggedIn && _savedAddresses.isNotEmpty)
//                           DropdownButtonFormField<String>(
//                             value: _selectedAddressKey,
//                             decoration: const InputDecoration(labelText: "Shipping Address", border: OutlineInputBorder()),
//                             items: [
//                               ..._savedAddresses.map((addr) => DropdownMenuItem(value: addr['label'], child: Text(addr['address']!, overflow: TextOverflow.ellipsis))),
//                               const DropdownMenuItem(value: 'new_address_option', child: Text("Add New Address")),
//                             ],
//                             onChanged: (val) {
//                               setState(() {
//                                 _selectedAddressKey = val;
//                                 if (val != 'new_address_option') {
//                                   _addressController.text = _savedAddresses.firstWhere((e) => e['label'] == val)['address']!;
//                                 } else {
//                                   _addressController.clear();
//                                 }
//                               });
//                             },
//                           ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _addressController,
//                           decoration: const InputDecoration(labelText: "Full Address Details", border: OutlineInputBorder()),
//                           maxLines: 2,
//                           enabled: _selectedAddressKey == 'new_address_option' || !_isLoggedIn,
//                           validator: (v) => v!.isEmpty ? "Required" : null,
//                         ),
//                         const SizedBox(height: 20),
//
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: _isLoading ? null : () {
//                               if (_formKey.currentState!.validate()) _placeOrderDirectly();
//                             },
//                             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
//                             child: const Text("Place Order", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
//         if (_isLoading) const Center(child: CircularProgressIndicator()),
//       ],
//     );
//   }
//
//   Future<void> _placeOrderDirectly() async {
//     setState(() => _isLoading = true);
//     try {
//       final draftId = await _createDraftOrder(_customDiscountCode, _couponDiscountValue);
//       if (draftId != null) {
//         final response = await _completeDraftOrder(draftId);
//         final data = json.decode(response);
//         final orderId = data['draft_order']?['order_id']?.toString() ?? draftId;
//
//         CartService.clearCart();
//         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ThankYouScreen(orderNumber: orderId)), (r) => false);
//       }
//     } catch (e) {
//       Fluttertoast.showToast(msg: "Checkout Error: $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<String> _completeDraftOrder(String id) async {
//     final response = await http.put(
//       Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$id/complete.json?payment_pending=true'),
//       headers: {'Content-Type': 'application/json', 'X-Shopify-Access-Token': adminAccessToken_const},
//     );
//     if (response.statusCode == 200) return response.body;
//     throw Exception("Completion failed");
//   }
// }
//



// --- IMPROVED COUPON LOGIC ---
// Future<void> _checkCouponValidity() async {
//   final couponCode = _couponCodeController.text.trim();
//   if (couponCode.isEmpty) {
//     Fluttertoast.showToast(msg: "Please enter a coupon code.");
//     return;
//   }
//
//   setState(() => _isLoading = true);
//
//   try {
//     final validationResult = await ShopifyAuthService.validateShopifyDiscountCode(couponCode);
//
//     if (validationResult['valid'] == true) {
//       final double value = (validationResult['value'] as num).toDouble();
//       final String type = validationResult['value_type'] as String;
//
//       double calculatedDiscount;
//       if (type == 'percentage') {
//         calculatedDiscount = widget.originalAmount * (value / 100);
//       } else {
//         calculatedDiscount = value;
//       }
//
//       setState(() {
//         _customDiscountCode = couponCode;
//         _couponDiscountValue = calculatedDiscount;
//         _discountCodeController.text = couponCode;
//         _recalculateFinalAmount();
//       });
//
//       Fluttertoast.showToast(msg: "Coupon Applied!", backgroundColor: Colors.green);
//     } else {
//       Fluttertoast.showToast(msg: validationResult['message'] ?? "Invalid code", backgroundColor: Colors.red);
//     }
//   } catch (e) {
//     Fluttertoast.showToast(msg: "Error validating coupon");
//   } finally {
//     setState(() => _isLoading = false);
//   }
// }

// --- Core Coupon Logic inside CheckoutScreen ---

// --- IMPROVED COUPON LOGIC WITH PRINTS ---
// --- Draft Order Creation Logic ---
//
//   Future<String?> _createDraftOrder(String? code, double discount) async {
//     final lineItems = widget.cartItems.map((p) => {
//       "variant_id": p.variantId.split('/').last, // Extract numeric ID from GID
//       "quantity": p.quantity,
//     }).toList();
//
//     Map<String, dynamic> payload = {
//       "draft_order": {
//         "line_items": lineItems,
//         "email": _emailController.text,
//         "shipping_address": {
//           "first_name": _nameController.text,
//           "address1": _addressController.text,
//           "city": "Lahore",
//           "country": "Pakistan",
//           "phone": _phoneController.text
//         },
//         "use_customer_default_address": false,
//         "tags": "mobile-app, COD",
//       }
//     };
//
//     // This is the CRITICAL part for Shopify to show the discount on the order
//     if (code != null && discount > 0) {
//       payload["draft_order"]["applied_discount"] = {
//         "description": "Coupon: $code",
//         "value": discount.toStringAsFixed(2),
//         "value_type": "fixed_amount", // We send the calculated PKR value
//         "title": code
//       };
//     }
//
//     final response = await http.post(
//       Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json'),
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken_const
//       },
//       body: json.encode(payload),
//     );
//
//     if (response.statusCode == 201) {
//       return json.decode(response.body)['draft_order']['id'].toString();
//     }
//     return null;
//   }


// void _recalculateFinalAmount() {
//   setState(() {
//     double discountToApply = _couponDiscountValue.clamp(0.0, widget.originalAmount);
//     _finalAmount = widget.originalAmount - discountToApply;
//     _discountApplied = discountToApply > 0;
//   });
// }

  // Future<String?> _createDraftOrder(String? code, double discount) async {
  //   final lineItems = widget.cartItems.map((p) => {
  //     "variant_id": p.variantId.split('/').last,
  //     "quantity": p.quantity,
  //   }).toList();
  //
  //   Map<String, dynamic> payload = {
  //     "draft_order": {
  //       "line_items": lineItems,
  //       "email": _emailController.text,
  //       "shipping_address": {
  //         "first_name": _nameController.text,
  //         "address1": _addressController.text,
  //         "city": "Lahore",
  //         "country": "Pakistan",
  //         "phone": _phoneController.text
  //       },
  //       "use_customer_default_address": false,
  //       "tags": "mobile-app, COD",
  //     }
  //   };
  //
  //   // Apply discount to the draft order correctly
  //   if (code != null && discount > 0) {
  //     payload["draft_order"]["applied_discount"] = {
  //       "description": "Coupon: $code",
  //       "value": discount.toStringAsFixed(2),
  //       "value_type": "fixed_amount",
  //       "title": code
  //     };
  //   }
  //
  //   final response = await http.post(
  //     Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json'),
  //     headers: {'Content-Type': 'application/json', 'X-Shopify-Access-Token': adminAccessToken_const},
  //     body: json.encode(payload),
  //   );
  //
  //   if (response.statusCode == 201) return json.decode(response.body)['draft_order']['id'].toString();
  //   return null;
  // }


// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
// import 'package:achhafoods/screens/Consts/appBar.dart';
// import 'package:achhafoods/screens/Consts/conts.dart';
// import 'package:achhafoods/screens/Drawer/Drawer.dart';
// import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:achhafoods/screens/CartScreen/ThankYouScreen.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../services/CartServices.dart';
// import '../Consts/shopify_auth_service.dart';
//
// class CheckoutScreen extends StatefulWidget {
//   final List cartItems;
//   final double originalAmount;
//   final double finalAmount;
//   final String? discountCode;
//
//   const CheckoutScreen({
//     super.key,
//     required this.cartItems,
//     required this.finalAmount,
//     required this.originalAmount,
//     this.discountCode,
//   });
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
//   final TextEditingController _noteController = TextEditingController();
//
//   // --- COUPON STATE ---
//   final TextEditingController _couponCodeController = TextEditingController();
//   String? _customDiscountCode;
//   double _couponDiscountValue = 0.0;
//
//   Map<String, dynamic>? customer;
//   final bool _isCodSelected = true;
//   bool _isLoading = false;
//   bool _useLoyaltyPoints = false; // Kept for UI, logic needs Laravel token which might not exist in pure Shopify mode
//   int _loyaltyPoints = 0;
//   bool _isLoggedIn = false;
//
//   late double _finalAmount;
//   bool _discountApplied = false;
//
//   // Stores addresses in a simple format for the dropdown
//   final List<Map<String, String>> _savedAddresses = [];
//   String? _selectedAddressKey;
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
//     }
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _addressController.dispose();
//     _phoneController.dispose();
//     _nameController.dispose();
//     _discountCodeController.dispose();
//     _noteController.dispose();
//     _couponCodeController.dispose();
//     super.dispose();
//   }
//
//   // --- Core API and Data Loading Logic ---
//
//   Future<void> _checkLoginStatusAndLoadInfo() async {
//     final prefs = await SharedPreferences.getInstance();
//     final customerJson = prefs.getString('shopifyCustomer') ?? prefs.getString('customer');
//
//     if (customerJson != null) {
//       setState(() {
//         _isLoggedIn = true;
//       });
//       _loadCustomerInfoFromLocal(customerJson);
//     } else {
//       setState(() {
//         _isLoggedIn = false;
//         _selectedAddressKey = 'new_address_option';
//       });
//     }
//   }
//
//   void _populateAddressControllers(String fullAddress) {
//     _addressController.text = fullAddress;
//   }
//
//   // 🟢 LOAD INFO DIRECTLY FROM LOCAL SHOPIFY DATA (No Laravel Address Call)
//   void _loadCustomerInfoFromLocal(String jsonString) {
//     try {
//       final data = json.decode(jsonString);
//       final cust = data['customer'];
//
//       if (cust != null) {
//         _emailController.text = cust['email'] ?? '';
//         _nameController.text = '${cust['firstName'] ?? ''} ${cust['lastName'] ?? ''}'.trim();
//         _phoneController.text = cust['phone'] ?? '';
//
//         // 🟢 EXTRACT ADDRESSES FROM SHOPIFY OBJECT
//         List<dynamic> addresses = [];
//         if (cust['addresses'] != null) {
//           if (cust['addresses'] is List) {
//             addresses = cust['addresses'];
//           } else if (cust['addresses']['nodes'] != null) {
//             addresses = cust['addresses']['nodes'];
//           }
//         }
//
//         _savedAddresses.clear();
//         for (var addr in addresses) {
//           // Construct a readable address string
//           List<String> parts = [];
//           if (addr['address1'] != null) parts.add(addr['address1']);
//           if (addr['city'] != null) parts.add(addr['city']);
//           if (addr['zip'] != null) parts.add(addr['zip']);
//           if (addr['country'] != null) parts.add(addr['country']);
//
//           String fullStr = parts.join(', ');
//
//           if (fullStr.isNotEmpty) {
//             _savedAddresses.add({
//               'label': addr['address1'] ?? 'Saved Address', // Use address1 as label key
//               'address': fullStr,
//             });
//           }
//         }
//
//         setState(() {
//           if (_savedAddresses.isNotEmpty) {
//             // Default to first address
//             _selectedAddressKey = _savedAddresses.first['label'];
//             _populateAddressControllers(_savedAddresses.first['address']!);
//           } else {
//             _selectedAddressKey = 'new_address_option';
//             _addressController.clear();
//           }
//         });
//       }
//     } catch (e) {
//       if (kDebugMode) print("Error parsing local customer data: $e");
//     }
//   }
//
//   Future<void> _checkCouponValidity() async {
//     final couponCode = _couponCodeController.text.trim();
//     if (couponCode.isEmpty) {
//       Fluttertoast.showToast(msg: "Please enter a coupon code.");
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       final validationResult = await ShopifyAuthService.validateShopifyDiscountCode(couponCode);
//
//       if (validationResult['valid'] == true) {
//         final double value = validationResult['value'] as double;
//         final String type = validationResult['value_type'] as String;
//
//         double discountAmount;
//         if (type == 'percentage') {
//           discountAmount = widget.originalAmount * (value / 100);
//         } else {
//           discountAmount = value;
//         }
//
//         discountAmount = discountAmount.clamp(0.0, widget.originalAmount);
//
//         setState(() {
//           _couponDiscountValue = discountAmount;
//           _customDiscountCode = couponCode;
//           _recalculateFinalAmount();
//         });
//
//         Fluttertoast.showToast(
//           msg: "Coupon applied! Discount: Rs. ${discountAmount.toStringAsFixed(2)}",
//           backgroundColor: Colors.green,
//         );
//       } else {
//         setState(() {
//           _couponDiscountValue = 0.0;
//           _customDiscountCode = null;
//           _recalculateFinalAmount();
//         });
//         Fluttertoast.showToast(msg: validationResult['message'] ?? "Invalid code", backgroundColor: Colors.red);
//       }
//     } catch (e) {
//       Fluttertoast.showToast(msg: "Error validation.");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _removeCoupon() {
//     setState(() {
//       _couponCodeController.clear();
//       _couponDiscountValue = 0.0;
//       _customDiscountCode = null;
//       _recalculateFinalAmount();
//     });
//     Fluttertoast.showToast(msg: "Coupon removed");
//   }
//
//   void _recalculateFinalAmount() {
//     double couponDiscount = _customDiscountCode != null ? _couponDiscountValue : 0.0;
//
//     // Loyalty logic skipped for now as we removed Laravel fetch,
//     // but structure is here if you re-enable it via Shopify Metafields later.
//     double totalDiscount = couponDiscount;
//     totalDiscount = totalDiscount.clamp(0.0, widget.originalAmount);
//
//     _finalAmount = (widget.originalAmount - totalDiscount);
//
//     setState(() {
//       _discountApplied = totalDiscount > 0;
//       if (_customDiscountCode != null) {
//         _discountCodeController.text = _customDiscountCode!;
//       } else if (widget.discountCode != null && widget.discountCode!.isNotEmpty) {
//         _discountCodeController.text = widget.discountCode!;
//         _finalAmount = widget.finalAmount; // Revert to passed-in discount
//       } else {
//         _discountCodeController.clear();
//         _finalAmount = widget.originalAmount;
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double totalAppliedDiscountValue = widget.originalAmount - _finalAmount;
//
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
//                 color: CustomColorTheme.CustomPrimaryAppColor,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 alignment: Alignment.center,
//                 child: const Text("Checkout", style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
//               ),
//               Expanded(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.all(16),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Summary
//                         const SizedBox(height: 12),
//                         const Text("Order Summary:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                         const SizedBox(height: 8),
//                         ...widget.cartItems.map((product) => Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Flexible(child: Text("${product.title} (x${product.quantity})")),
//                             Text("Rs. ${(product.price * product.quantity).toStringAsFixed(2)}"),
//                           ],
//                         )),
//
//                         // Discount Row
//                         if (_discountApplied && _finalAmount < widget.originalAmount)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 8.0),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Flexible(child: Text("Discount (${_discountCodeController.text}):", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold))),
//                                 Row(
//                                   children: [
//                                     Text("- Rs. ${totalAppliedDiscountValue.toStringAsFixed(2)}", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold)),
//                                     if (_customDiscountCode != null)
//                                       IconButton(icon: const Icon(Icons.close, size: 16), onPressed: _removeCoupon, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           ),
//                         const Divider(),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text("Grand Total:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                             Text("Rs. ${_finalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                           ],
//                         ),
//                         const SizedBox(height: 20),
//
//                         // Coupon
//                         Container(
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text("Apply Coupon", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                               const SizedBox(height: 8),
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: TextFormField(
//                                       controller: _couponCodeController,
//                                       decoration: InputDecoration(
//                                         labelText: "Enter coupon code",
//                                         border: const OutlineInputBorder(),
//                                         enabled: !_isLoading && _customDiscountCode == null,
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 8),
//                                   SizedBox(
//                                     height: 60,
//                                     child: ElevatedButton(
//                                       onPressed: _customDiscountCode != null ? _removeCoupon : (_isLoading ? null : _checkCouponValidity),
//                                       style: ElevatedButton.styleFrom(
//                                         backgroundColor: _customDiscountCode != null ? Colors.red : Colors.black,
//                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                                       ),
//                                       child: Text(_customDiscountCode != null ? 'Remove' : 'Apply', style: const TextStyle(color: Colors.white)),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//
//                         // Info Fields
//                         TextFormField(
//                           controller: _nameController,
//                           decoration: const InputDecoration(labelText: "Full Name"),
//                           validator: (value) => value!.isEmpty ? "Name is required" : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _emailController,
//                           decoration: const InputDecoration(labelText: "Email Address"),
//                           keyboardType: TextInputType.emailAddress,
//                           validator: (value) => value!.isEmpty || !value.contains('@') ? "Enter valid email" : null,
//                         ),
//                         const SizedBox(height: 12),
//                         TextFormField(
//                           controller: _phoneController,
//                           decoration: const InputDecoration(labelText: "Phone Number"),
//                           keyboardType: TextInputType.phone,
//                           validator: (value) => value!.isEmpty ? "Phone is required" : null,
//                         ),
//                         const SizedBox(height: 12),
//
//                         // 🟢 ADDRESS DROPDOWN (From Shopify Data)
//                         if (_isLoggedIn && _savedAddresses.isNotEmpty)
//                           Padding(
//                             padding: const EdgeInsets.only(bottom: 12.0),
//                             child: DropdownButtonFormField<String>(
//                               decoration: const InputDecoration(
//                                 labelText: 'Select Shipping Address',
//                                 border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
//                               ),
//                               value: _selectedAddressKey,
//                               items: [
//                                 ..._savedAddresses.map((addr) => DropdownMenuItem(
//                                   value: addr['label'],
//                                   child: SizedBox(
//                                     width: MediaQuery.of(context).size.width * 0.75,
//                                     child: Text(addr['address']!, overflow: TextOverflow.ellipsis),
//                                   ),
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
//                             ),
//                           ),
//
//                         TextFormField(
//                           controller: _addressController,
//                           decoration: InputDecoration(
//                               labelText: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty
//                                   ? "Full Shipping Address (Required)"
//                                   : "Selected Address"
//                           ),
//                           maxLines: 3,
//                           validator: (value) => value!.isEmpty ? "Address is required" : null,
//                           enabled: _selectedAddressKey == 'new_address_option' || !_isLoggedIn || _savedAddresses.isEmpty,
//                           keyboardType: TextInputType.streetAddress,
//                         ),
//                         const SizedBox(height: 20),
//
//                         TextFormField(
//                           controller: _noteController,
//                           decoration: const InputDecoration(labelText: "Order Note (Optional)", hintText: "Note...", border: OutlineInputBorder()),
//                           maxLines: 1,
//                         ),
//                         const SizedBox(height: 20),
//
//                         // Place Order Button
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton(
//                             onPressed: _isLoading ? null : () {
//                               FocusScope.of(context).unfocus();
//                               if (_formKey.currentState!.validate()) {
//                                 _placeOrderDirectly();
//                               }
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red,
//                               padding: const EdgeInsets.symmetric(vertical: 16),
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                             ),
//                             child: const Text("Place Order", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
//             child: const Center(child: CircularProgressIndicator(color: Colors.white)),
//           ),
//       ],
//     );
//   }
//
//   Future<void> _placeOrderDirectly() async {
//     setState(() => _isLoading = true);
//
//     String finalDiscountCode = _customDiscountCode ?? "";
//     double finalDiscountValue = _couponDiscountValue;
//
//     if (finalDiscountCode.isEmpty && widget.discountCode != null && widget.discountCode!.isNotEmpty) {
//       finalDiscountCode = widget.discountCode!;
//       finalDiscountValue = widget.originalAmount - widget.finalAmount;
//     }
//
//     try {
//       final draftOrderId = await _createDraftOrder(finalDiscountCode, finalDiscountValue);
//
//       if (draftOrderId != null) {
//         final responseBody = await _completeDraftOrder(draftOrderId);
//         final responseData = json.decode(responseBody);
//
//         final shopifyOrderId = responseData['draft_order']?['order_id']?.toString() ??
//             responseData['order']?['id']?.toString() ??
//             draftOrderId;
//
//         CartService.clearCart();
//
//         Fluttertoast.showToast(msg: "Order placed successfully!", backgroundColor: Colors.green);
//
//         if (mounted) {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (_) => ThankYouScreen(orderNumber: shopifyOrderId)),
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
//   Future<String?> _createDraftOrder(String? discountCode, double? discountValue) async {
//     final lineItems = widget.cartItems.map((product) {
//       return {
//         "variant_id": _extractVariantId(product.variantId),
//         "quantity": product.quantity,
//         "price": product.price,
//         "title": product.title,
//       };
//     }).toList();
//
//     List<String> orderTagsList = ["mobile-app", "COD"];
//     final String orderTags = orderTagsList.join(', ');
//
//     Map<String, dynamic> payload = {
//       "draft_order": {
//         "line_items": lineItems,
//         "email": _emailController.text,
//         "shipping_address": {
//           "first_name": _nameController.text.split(' ').first,
//           "last_name": _nameController.text.split(' ').length > 1 ? _nameController.text.split(' ').last : '',
//           "address1": _addressController.text,
//           "city": "Lahore", // Defaults
//           "country": "Pakistan",
//           "phone": _phoneController.text
//         },
//         "note": _noteController.text,
//         "tags": orderTags,
//       }
//     };
//
//     if (discountCode != null && discountCode.isNotEmpty && discountValue != null && discountValue > 0) {
//       payload["draft_order"]["applied_discount"] = {
//         "description": discountCode,
//         "value": discountValue.toStringAsFixed(2),
//         "value_type": "fixed_amount",
//         "amount": discountValue.toStringAsFixed(2),
//         "title": discountCode,
//       };
//     }
//
//     final uri = Uri.parse('https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders.json');
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
//       return json.decode(response.body)['draft_order']['id'].toString();
//     } else {
//       throw Exception('Failed to create draft order');
//     }
//   }
//
//   Future<String> _completeDraftOrder(String draftOrderId) async {
//     final uri = Uri.parse(
//         'https://$shopifyStoreUrl_const/admin/api/$adminApiVersion_const/draft_orders/$draftOrderId/complete.json?payment_pending=true');
//     final response = await http.put(
//       uri,
//       headers: {
//         'Content-Type': 'application/json',
//         'X-Shopify-Access-Token': adminAccessToken_const,
//       },
//     );
//
//     if (response.statusCode == 200) return response.body;
//     throw Exception('Failed to complete draft order');
//   }
//
//   String _extractVariantId(String variantGid) {
//     final parts = variantGid.split('/');
//     return parts.last;
//   }
// }