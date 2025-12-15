import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'dart:convert';
import '../Consts/CustomFloatingButton.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achhafoods/screens/CartScreen/CheckoutScreen.dart';
import '../../services/AllProductsModel.dart';
import '../../services/CartServices.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();

  double totalAmount = 0.0;
  double originalTotalAmount = 0.0;
  double finalAmount = 0.0;
  double pointsDiscount = 0.0;
  final bool _isLoading = false;
  int _loyaltyPoints = 0;
  bool _useLoyaltyPoints = false;
  Map<String,dynamic>? laravelUser;
  final bool _isGeneratingCoupon = false;

  final String shopifyStoreUrl = shopifyStoreUrl_const;
  final String adminAccessToken = adminAccessToken_const;
  Map<String, dynamic>? customer;

  @override
  void initState() {
    super.initState();
    CartService.cartItemsNotifier.addListener(_calculateTotalAmount);
    _loadCustomerInfo();
    _loadLaravelUser();
    CartService.loadCart().then((_) {
      _calculateTotalAmount();
      _loadCustomerInfo();
    });
  }

  @override
  void dispose() {
    CartService.cartItemsNotifier.removeListener(_calculateTotalAmount);
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  // Location: CartScreenState
  Future<void> _loadLaravelUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataJson = prefs.getString('laravelUser');

    if (userDataJson == null) {
      if (kDebugMode) print("Laravel user data missing. Skipping loyalty load.");
      return;
    }

    // --- START: Simple ID Retrieval ---
    int? userId;
    try {
      // Decode the JSON string into a Map
      final Map<String, dynamic> userData = json.decode(userDataJson);
      // Extract the ID as an integer
      userId = userData['id'] as int?;
    } catch (e) {
      if (kDebugMode) print("Error decoding laravelUser JSON or ID missing/invalid: $e");
      // Return early if we can't get the ID
      return;
    }

    if (userId == null) {
      if (kDebugMode) print("User ID is null after decoding. Cannot fetch points.");
      return;
    }
    // --- END: Simple ID Retrieval ---

    // 1. Construct the URL with the ID as a query parameter
    final url = Uri.parse('$localurl/api/points/summary')
        .replace(queryParameters: {'id': userId.toString()});

    // Start with the default points value
    int fetchedPoints = 0;

    try {
      final response = await http.get(
        url, // Use the URL with query parameter
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // 2. Handle HTTP Status
      if (response.statusCode == 200) {
        // Safely decode the JSON response
        final responseData = json.decode(response.body);
        if (kDebugMode) print("Loyalty points response: $responseData");

        // Extract points based on your API structure (data -> points_summary -> total_points)
        if (responseData is Map<String, dynamic> && responseData['status'] == 'success') {
          fetchedPoints = responseData['data']?['points_summary']?['total_points'] ?? 0;
          if (kDebugMode) print("Loyalty points loaded: $fetchedPoints");
        }
      } else {
        if (kDebugMode) print("Error fetching loyalty points: HTTP Status Code ${response.statusCode}.");
        // Handle the case where the server returns a non-200 status (which often leads to the HTML error)
        Fluttertoast.showToast(msg: "Server Error: Failed to fetch points (HTTP ${response.statusCode}).", backgroundColor: Colors.red);
      }

      // 3. Update state
      setState(() {
        _loyaltyPoints = fetchedPoints;
      });

    } catch (e) {
      // Catch network errors or FormatException from json.decode if response.statusCode was 200
      if (kDebugMode) print("Error fetching loyalty points (Network/Decoding): $e");
      Fluttertoast.showToast(msg: "Error reading loyalty data.", backgroundColor: Colors.red);
    }
  }

  Future<void> _toggleLoyaltyPoints(bool newValue) async {
    if (newValue && _loyaltyPoints <= 0) {
      Fluttertoast.showToast(
        msg: "No loyalty points available.",
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    setState(() {
      _useLoyaltyPoints = newValue;
      if (_useLoyaltyPoints) {
        pointsDiscount = _loyaltyPoints.toDouble();
        finalAmount = totalAmount - pointsDiscount;
        if (finalAmount < 0) {
          finalAmount = 0;
        }
        Fluttertoast.showToast(
          msg: "$_loyaltyPoints points applied.",
          backgroundColor: Colors.green,
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        finalAmount = totalAmount;
        pointsDiscount = 0.0;
        Fluttertoast.showToast(
          msg: "Loyalty points removed.",
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    });
  }

  void _calculateTotalAmount() {
    totalAmount = CartService.cartItemsNotifier.value.fold(
      0.0,
          (sum, product) => sum + (product.price * product.quantity),
    );
    originalTotalAmount = totalAmount;

    if (_useLoyaltyPoints) {
      finalAmount = totalAmount - _loyaltyPoints;
      if (finalAmount < 0) {
        finalAmount = 0;
      }
    } else {
      finalAmount = totalAmount;
    }
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final customerData = prefs.getString('customer');
    if (customerData != null) {
      setState(() {
        customer = json.decode(customerData);
      });
    }

    final customerDetails = customer?['customer'] as Map<String, dynamic>?;

    print("customerDetails: $customerDetails");

    // Load basic customer info with default fallbacks
    final String firstName = customerDetails?['firstName'] ?? 'User';
    final String lastName = customerDetails?['lastName'] ?? '';
    final String email = customerDetails?['email'] ?? '';
    final String phone = customerDetails?['phone'] ?? '';

    // --- Start of Address Handling Changes ---
    String combinedAddress = '';
    final Map<String, dynamic>? defaultAddress =
    customerDetails?['defaultAddress'];

    if (defaultAddress != null) {
      final String address1 = defaultAddress['address1'] ?? '';
      final String address2 = defaultAddress['address2'] ?? '';
      final String city = defaultAddress['city'] ?? '';
      final String province = defaultAddress['province'] ?? '';
      final String zip = defaultAddress['zip'] ?? '';
      final String country = defaultAddress['country'] ?? '';
      final String addressPhone =
          defaultAddress['phone'] ?? ''; // Renamed to avoid conflict

      // Combine all address parts into a single string
      List<String> addressParts = [
        address1,
        address2,
        city,
        province,
        zip,
        country
      ].where((part) => part.isNotEmpty).toList(); // Filter out empty parts

      combinedAddress = addressParts.join(', '); // Join with comma and space

      await prefs.setString('customer_full_address', combinedAddress);
      await prefs.setString('customer_city', city);
      await prefs.setString('customer_zip',
          zip); // Only if you still want to manage these separately
    } else {
      combinedAddress = prefs.getString('customer_full_address') ?? '';
    }
    final String city = prefs.getString('customer_city') ??
        'Lahore'; // Still needed if separate city field exists
    final String zip = prefs.getString('customer_zip') ??
        '54000'; // Still needed if separate zip field exists
    setState(() {
      // Combine name like 'User Lastname'
      _nameController.text = '$firstName $lastName'.trim();
      _emailController.text = email;
      _phoneController.text = phone;
      _addressController.text =
          combinedAddress; // Set the combined address here
      _cityController.text = city;
      _zipController.text = zip;
    });
  }



  // Helper method for consistent TextFormField styling
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon,
            color: CustomColorTheme.CustomPrimaryAppColor.withOpacity(
                0.8)), // Slightly muted icon color
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: CustomColorTheme.CustomPrimaryAppColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        floatingLabelBehavior: FloatingLabelBehavior.auto, // Labels move up
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
          fontSize: 15, color: Colors.grey.shade800), // Text input style
    );
  }

  Widget _buildProductImage(AllProductsModel product) {
    final Uri? uri = Uri.tryParse(product.image);
    if (product.image.isEmpty || uri == null || !uri.isAbsolute) {
      return Container(
        width: 55, // Medium size
        height: 75, // Medium size
        decoration: BoxDecoration(
          color: Colors.grey[100], // Lighter grey
          borderRadius: BorderRadius.circular(6.0), // Slightly less rounded
        ),
        child: Icon(Icons.image_not_supported,
            size: 28, color: Colors.grey.shade400), // Medium, muted icon
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.0), // Match container
      child: CachedNetworkImage(
        imageUrl: product.image,
        width: 55, // Medium size
        height: 75, // Medium size
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[100],
          child: Center(
              child: CircularProgressIndicator(
                  color: CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.7),
                  strokeWidth: 1.5)), // Thinner, themed loading
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[100],
          child: Icon(Icons.broken_image,
              color: Colors.grey.shade400), // Muted error icon
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(AllProductsModel product) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)), // Medium rounded
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 24), // Medium size, darker orange
            const SizedBox(width: 8.0),
            const Text(
              "Confirm Removal",
              style: TextStyle(
                  color: CustomColorTheme.CustomPrimaryAppColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18), // Medium font
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to remove '${product.title}' from your cart?", // Added single quotes for clarity
          style: const TextStyle(fontSize: 15), // Medium font
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel",
                style: TextStyle(
                    color: CustomColorTheme.CustomPrimaryAppColor,
                    fontSize: 15)), // Medium font
          ),
          ElevatedButton(
            onPressed: () {
              CartService.toggleCartItem(product);
              _calculateTotalAmount();
              Navigator.of(context).pop();
              Fluttertoast.showToast(
                msg: "${product.title} removed from cart",
                backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                toastLength: Toast.LENGTH_SHORT,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500, // Medium red
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)) // Medium rounded
            ),
            child: const Text("Remove",
                style: TextStyle(
                    color: Colors.white, fontSize: 15)), // Medium font
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      body: ValueListenableBuilder<List<AllProductsModel>>(
        valueListenable: CartService.cartItemsNotifier,
        builder: (context, cartItems, _) {
          _calculateTotalAmount();
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                color: CustomColorTheme.CustomPrimaryAppColor,
                child: const Center(
                  child: Text(
                    "Your Shopping Cart",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              cartItems.isEmpty
                  ? Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 70, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        "Your cart is empty!",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Start adding some amazing products.",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
                  : Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: cartItems.length,
                        itemBuilder: (context, index) {
                          final product = cartItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10.0),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6.0, horizontal: 6.0),
                              child: Row(
                                children: [
                                  _buildProductImage(product),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.title,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs. ${product.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                              fontWeight:
                                              FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        if (!product.stockCheck)
                                          const Text(
                                            "Out of Stock",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: CustomColorTheme
                                              .CustomPrimaryAppColor
                                              .withOpacity(0.08),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.remove,
                                                  size: 18,
                                                  color: CustomColorTheme
                                                      .CustomPrimaryAppColor),
                                              onPressed: () {
                                                if (product.quantity >
                                                    1) {
                                                  CartService
                                                      .updateQuantity(
                                                      product,
                                                      product.quantity -
                                                          1);
                                                  _calculateTotalAmount();
                                                }
                                              },
                                              constraints:
                                              const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                              VisualDensity.compact,
                                            ),
                                            Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 5.0),
                                              child: Text(
                                                '${product.quantity}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                    FontWeight.bold),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add,
                                                  size: 18,
                                                  color: CustomColorTheme
                                                      .CustomPrimaryAppColor),
                                              onPressed: () {
                                                CartService
                                                    .updateQuantity(
                                                    product,
                                                    product.quantity +
                                                        1);
                                                _calculateTotalAmount();
                                              },
                                              constraints:
                                              const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                              VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      IconButton(
                                        onPressed: () =>
                                            _showDeleteConfirmationDialog(
                                                product),
                                        icon: Icon(Icons.delete,
                                            color: Colors.red.shade400,
                                            size: 20),
                                        visualDensity:
                                        VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Discount and Loyalty Section
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    //   decoration: BoxDecoration(
                    //     color: Colors.grey.shade100,
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(color: Colors.grey.shade300),
                    //   ),
                    //   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       const Text(
                    //         "Discounts & Rewards",
                    //         style: TextStyle(
                    //           fontSize: 16,
                    //           fontWeight: FontWeight.bold,
                    //         ),
                    //       ),
                    //       const SizedBox(height: 10),
                    //       Row(
                    //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //         children: [
                    //           Text(
                    //             "Use Loyalty Points (${_loyaltyPoints} available)",
                    //             style: TextStyle(
                    //               color: Colors.grey.shade800,
                    //               fontSize: 16,
                    //             ),
                    //           ),
                    //           Switch(
                    //             value: _useLoyaltyPoints,
                    //             onChanged: (bool newValue) {
                    //               _toggleLoyaltyPoints(newValue);
                    //             },
                    //             activeColor: CustomColorTheme.CustomBlueColor,
                    //             trackColor: _loyaltyPoints <= 0
                    //                 ? MaterialStateProperty.all(Colors.grey.shade400)
                    //                 : null,
                    //             splashRadius: _loyaltyPoints <= 0 ? 0 : null,
                    //           ),
                    //         ],
                    //       ),
                    //     ],
                    //   ),
                    // )
                  ],
                ),
              ),

              // Checkout Summary and Button
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_useLoyaltyPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Subtotal:",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              "Rs. ${originalTotalAmount.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_useLoyaltyPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Loyalty Points Discount:",
                              style: TextStyle(
                                color: Colors.green.shade600,
                              ),
                            ),
                            Text(
                              "- Rs. $_loyaltyPoints",
                              style: TextStyle(
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          "Rs. ${finalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CustomColorTheme.CustomPrimaryAppColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _isGeneratingCoupon
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        // CHANGE 1: If cart is empty OR loading, disable button (null)
                        onPressed: (_isLoading || cartItems.isEmpty)
                            ? null
                            : () async {
                          // Your existing logic starts here
                          final outOfStockItems = CartService
                              .cartItemsNotifier.value
                              .where((product) =>
                          !product.stockCheck)
                              .toList();

                          if (outOfStockItems.isNotEmpty) {
                            Fluttertoast.showToast(
                              msg:
                              "Some items in your cart are out of stock",
                              backgroundColor: Colors.red,
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                cartItems: CartService
                                    .cartItemsNotifier.value,
                                originalAmount: originalTotalAmount,
                                finalAmount: finalAmount,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          // CHANGE 2: Change color to Grey if empty, else use Primary Color
                          backgroundColor: cartItems.isEmpty
                              ? Colors.grey
                              : CustomColorTheme.CustomPrimaryAppColor,
                          // Use disabledBackgroundColor to ensure it stays grey when disabled
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: cartItems.isEmpty ? 0 : 4,
                        ),
                        child: Text(
                          // CHANGE 3: Change Text based on cart state
                          cartItems.isEmpty
                              ? "Nothing in Cart"
                              : "Proceed to Checkout",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}