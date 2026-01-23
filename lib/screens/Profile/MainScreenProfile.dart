import 'dart:convert';
import 'package:achhafoods/services/DynamicContentCache.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:achhafoods/screens/Profile/OrderDetails.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../Consts/CustomFloatingButton.dart';
import '../Consts/conts.dart';
import '../Consts/shopify_auth_service.dart' hide localurl;
import 'ProfileScreen.dart';
import 'SignUp.dart';
import '../Home Screens/homepage.dart';
import 'package:shimmer/shimmer.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  bool isLoading = false;

  // Data Holders
  Map<String, dynamic>? customer;
  final DynamicContentCache _dynamicContentCache = DynamicContentCache.instance;
  Future<void>? _dynamicContentFuture;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();

    // 1. Initialize Shopify Token on Screen Load (Self-Healing)
    _initShopifyToken();

    // 2. Load Customer Data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomerAndData();
    });
  }

  // ✅ Wrapper to initialize token safely
  Future<void> _initShopifyToken() async {
    await ShopifyService.initToken();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------------
  // 🟢 LOGIN (OAuth)
  // ------------------------------------------------------------------------
  Future<void> _loginWithShopifyOAuth() async {
    setState(() => isLoading = true);

    try {
      print('🔵 Starting OAuth login...');

      // The AuthService now handles token refreshing internally if needed
      final loggedInCustomer = await ShopifyAuthService.loginWithShopify();

      if (loggedInCustomer != null) {
        print('🟢 OAuth successful!');

        // 1. Get customer email
        final customerData = loggedInCustomer['customer'] as Map<String, dynamic>?;
        final String userEmail = customerData?['email'] ?? '';

        // 2. Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("shopifyCustomer", jsonEncode(loggedInCustomer));
        await prefs.setString('customer', jsonEncode(loggedInCustomer));
        await prefs.setString('customer_email', userEmail);

        // 3. Update UI state immediately
        if (mounted) {
          setState(() {
            customer = loggedInCustomer;
            _isInitialLoad = true; // Trigger reload of profile view to refresh cache
          });
          // Populate text controllers for the UI from local data
          _populateProfileFromLocalData();
        }

        // 4. Sync with Laravel (Background - Optional)
        _syncWithLaravel(userEmail, customerData?['id']);

        Fluttertoast.showToast(
          msg: "Logged in successfully! 🎉",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        // 5. Navigate to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );

      } else {
        // Graceful failure
        Fluttertoast.showToast(
          msg: "Login cancelled",
          backgroundColor: Colors.grey,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Login error: $e');
      Fluttertoast.showToast(
        msg: "Unable to log in. Please check your connection.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _syncWithLaravel(String email, String? shopifyId) async {
    try {
      final laravelUrl = Uri.parse("$localurl/api/shopify-login");
      await http.post(
        laravelUrl,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "shopify_customer_id": shopifyId,
        }),
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ Laravel sync silently failed: $e');
    }
  }

  // ------------------------------------------------------------------------
  // 🟢 LOAD DATA (Profile)
  // ------------------------------------------------------------------------
  Future<void> _loadCustomerAndData() async {
    _dynamicContentCache.setBuildPhase(true);
    setState(() => _isInitialLoad = true);

    _dynamicContentFuture = _dynamicContentCache.loadDynamicData();

    // Load Customer from Local Storage
    final prefs = await SharedPreferences.getInstance();
    final shopifyCustomerJson = prefs.getString('shopifyCustomer');

    if (shopifyCustomerJson != null) {
      try {
        setState(() {
          customer = jsonDecode(shopifyCustomerJson);
        });
        // ✅ Populate directly from Shopify data
        _populateProfileFromLocalData();
      } catch (e) {
        if (kDebugMode) print("Error parsing cached customer data: $e");
      }
    }

    _dynamicContentCache.setBuildPhase(false);

    if (mounted) {
      setState(() {
        _isInitialLoad = false;
      });
    }
  }

  // ✅ Extract data from the local Shopify object to Controllers
  void _populateProfileFromLocalData() {
    if (customer == null || customer!['customer'] == null) return;

    final custData = customer!['customer'];

    setState(() {
      _firstNameController.text = custData['firstName'] ?? '';
      _lastNameController.text = custData['lastName'] ?? '';
      _emailController.text = custData['email'] ?? '';
    });
  }

  // ------------------------------------------------------------------------
  // 🔴 LOGOUT
  // ------------------------------------------------------------------------
  // Future<void> _logout(BuildContext context) async {
  //   final shouldLogout = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => Dialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       child: Padding(
  //         padding: const EdgeInsets.all(20.0),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Icon(Icons.logout, color: Colors.redAccent, size: 50),
  //             const SizedBox(height: 16),
  //             const Text("Logout Confirmation", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
  //             const SizedBox(height: 12),
  //             const Text("Are you sure you want to log out?", textAlign: TextAlign.center),
  //             const SizedBox(height: 24),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //               children: [
  //                 ElevatedButton.icon(
  //                   icon: const Icon(Icons.cancel),
  //                   label: const Text("Cancel"),
  //                   onPressed: () => Navigator.of(context).pop(false),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Colors.grey[300],
  //                     foregroundColor: Colors.black87,
  //                   ),
  //                 ),
  //                 ElevatedButton.icon(
  //                   icon: const Icon(Icons.exit_to_app),
  //                   label: const Text("Logout"),
  //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
  //                   onPressed: () => Navigator.of(context).pop(true),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  //
  //   if (shouldLogout != true) return;
  //
  //   // Call Service Logout (Clears Tokens & Browser Session)
  //   await ShopifyAuthService.logout();
  //
  //   if (mounted) {
  //     setState(() {
  //       customer = null;
  //       _isInitialLoad = false;
  //       _firstNameController.clear();
  //       _lastNameController.clear();
  //       _emailController.clear();
  //     });
  //   }
  //
  //   Fluttertoast.showToast(msg: "Logged out successfully");
  // }

  // ------------------------------------------------------------------------
  // 🔴 LOGOUT
  // ------------------------------------------------------------------------
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, color: Colors.redAccent, size: 50),
              const SizedBox(height: 16),
              const Text("Logout Confirmation", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 12),
              const Text("Are you sure you want to log out?", textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel),
                    label: const Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text("Logout"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout != true) return;

    // Show a quick loading indicator while the browser opens
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: CustomColorTheme.CustomPrimaryAppColor)),
      );
    }

    // 1. Call Service Logout
    // This will open the browser, clear cookies, and auto-close the browser
    await ShopifyAuthService.logout();

    // 2. Remove loading indicator
    if (mounted) Navigator.pop(context);

    // 3. Clear Local State
    if (mounted) {
      setState(() {
        customer = null;
        _isInitialLoad = false;
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
      });
    }

    Fluttertoast.showToast(msg: "Logged out successfully");
  }
  // Future<void> _deleteAccount(BuildContext context) async {
  //   // 1. Show Confirmation Dialog
  //   final shouldDelete = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => Dialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       child: Padding(
  //         padding: const EdgeInsets.all(20.0),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
  //             const SizedBox(height: 16),
  //             const Text("Delete Account?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
  //             const SizedBox(height: 12),
  //             const Text(
  //               "This action is permanent.\nIf you have order history, your data will be anonymized instead of erased.",
  //               textAlign: TextAlign.center,
  //               style: TextStyle(fontSize: 14, color: Colors.black87),
  //             ),
  //             const SizedBox(height: 24),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //               children: [
  //                 ElevatedButton(
  //                   onPressed: () => Navigator.of(context).pop(false),
  //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
  //                   child: const Text("Cancel"),
  //                 ),
  //                 ElevatedButton(
  //                   onPressed: () => Navigator.of(context).pop(true),
  //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
  //                   child: const Text("Delete"),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  //
  //   if (shouldDelete != true) return;
  //
  //   // Show Loading
  //   if (mounted) {
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (_) => const Center(child: CircularProgressIndicator(color: CustomColorTheme.CustomPrimaryAppColor)),
  //     );
  //   }
  //
  //   try {
  //     // ---------------------------------------------------------
  //     // 1. ATTEMPT SHOPIFY DELETE
  //     // ---------------------------------------------------------
  //     bool shopifyProcessed = false;
  //
  //     // Get ID safely
  //     String? custId = customer?['customer']?['id'];
  //     if (custId != null) {
  //       // This now returns TRUE for both 200 (Deleted) and 422 (Has Orders)
  //       shopifyProcessed = await ShopifyAuthService.deleteCustomer(custId);
  //     } else {
  //       // If no ID found locally, assume we just need to clean up local/laravel
  //       shopifyProcessed = true;
  //     }
  //
  //     if (!shopifyProcessed) {
  //       if (mounted) Navigator.pop(context); // Close loading
  //       Fluttertoast.showToast(
  //         msg: "Could not verify account deletion. Please contact support.",
  //         backgroundColor: Colors.red,
  //         textColor: Colors.white,
  //       );
  //       return; // Stop here if network failed completely
  //     }
  //
  //     // ---------------------------------------------------------
  //     // 2. LARAVEL DELETE (Sync)
  //     // ---------------------------------------------------------
  //     try {
  //       final laravelUrl = Uri.parse("$localurl/api/delete-account");
  //       await http.post(
  //         laravelUrl,
  //         headers: {"Content-Type": "application/json", "Accept": "application/json"},
  //         body: jsonEncode({"email": _emailController.text}),
  //       );
  //       print("✅ Laravel Account Deleted/Deactivated");
  //     } catch (e) {
  //       print("⚠️ Laravel delete failed (proceeding anyway): $e");
  //     }
  //
  //     // ---------------------------------------------------------
  //     // 3. FINAL CLEANUP (Logout)
  //     // ---------------------------------------------------------
  //     if (mounted) Navigator.pop(context); // Close loading
  //
  //     Fluttertoast.showToast(
  //       msg: "Account deleted successfully.",
  //       backgroundColor: Colors.grey[800],
  //       textColor: Colors.white,
  //     );
  //
  //     // Perform full logout to clear tokens and browser session
  //     await _logout(context);
  //
  //   } catch (e) {
  //     if (mounted) Navigator.pop(context); // Close loading
  //     Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
  //   }
  // }



  // ------------------------------------------------------------------------
  // 🎨 UI BUILDERS
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      bottomNavigationBar: const NewNavigationBar(),
      floatingActionButton: CustomWhatsAppFAB(),
      drawer: const CustomDrawer(),
      body: RefreshIndicator(
        color: CustomColorTheme.CustomPrimaryAppColor,
        onRefresh: () async {
          await _loadCustomerAndData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  (kToolbarHeight + (MediaQuery.of(context).padding.top) + kBottomNavigationBarHeight),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 25),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // If loading or just started
    if (_isInitialLoad && customer == null) {
      return _buildLoginFormShimmer();
    }
    // If logged in
    if (customer != null) {
      return _buildProfileView();
    }
    // If logged out
    return _buildLoginForm();
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 60, bottom: 40),
          child: Column(
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: CustomColorTheme.CustomPrimaryAppColor, width: 2),
                ),
                child: const Icon(Icons.person_outline, size: 50, color: CustomColorTheme.CustomPrimaryAppColor),
              ),
              const SizedBox(height: 20),
              Text('Welcome', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Text('Sign in to access your account', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),

        // LOGIN BUTTON
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 3,
          ),
          onPressed: isLoading ? null : _loginWithShopifyOAuth,
          child: isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.login, color: Colors.white),
              SizedBox(width: 10),
              Text('LOG IN WITH SHOPIFY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // REGISTER BUTTON
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyAccount()));
          },
          child: const Text('CREATE NEW ACCOUNT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CustomColorTheme.CustomPrimaryAppColor)),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // 1. Show Confirmation Dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
              const SizedBox(height: 16),
              const Text("Delete Account?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              const Text(
                "This action is permanent.\nYour data will be removed or anonymized.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text("Delete"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldDelete != true) return;

    // Show Loading Overlay
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: CustomColorTheme.CustomPrimaryAppColor)),
      );
    }

    try {
      // ---------------------------------------------------------
      // 1. SHOPIFY DELETE
      // ---------------------------------------------------------
      bool shopifyProcessed = false;
      String? custId = customer?['customer']?['id'];

      if (custId != null) {
        shopifyProcessed = await ShopifyAuthService.deleteCustomer(custId);
      } else {
        shopifyProcessed = true; // Fallback if no ID is stored locally
      }

      if (!shopifyProcessed) {
        if (mounted) Navigator.pop(context); // Close loading
        Fluttertoast.showToast(
          msg: "Deletion failed. Contact support.",
          backgroundColor: Colors.red,
        );
        return;
      }

      // ---------------------------------------------------------
      // 2. LARAVEL SYNC
      // ---------------------------------------------------------
      try {
        final laravelUrl = Uri.parse("$localurl/api/delete-account");
        await http.post(
          laravelUrl,
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({"email": _emailController.text}),
        );
      } catch (e) {
        if (kDebugMode) print("⚠️ Laravel delete failed: $e");
      }

      // ---------------------------------------------------------
      // 3. LOGOUT & CLEANUP (Critical Step)
      // ---------------------------------------------------------
      if (mounted) Navigator.pop(context); // Close loading indicator

      // Trigger the existing logout service logic
      // This handles SharedPreferences, SecureStorage, and Browser session
      await ShopifyAuthService.logout();

      if (mounted) {
        setState(() {
          customer = null;
          _isInitialLoad = false;
          _firstNameController.clear();
          _lastNameController.clear();
          _emailController.clear();
        });
      }

      Fluttertoast.showToast(
        msg: "Account deleted and logged out successfully.",
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );

    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (kDebugMode) print("❌ Error during delete process: $e");
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    }
  }

  Widget _buildProfileView() {
    // Logic: Use Controllers first (populated from Shopify), fallback to map
    String displayedFirstName = _firstNameController.text;
    String displayedLastName = _lastNameController.text;
    String displayedEmail = _emailController.text;

    // Safety fallback if controllers are empty
    if (displayedFirstName.isEmpty && customer != null) {
      displayedFirstName = customer!['customer']['firstName'] ?? 'User';
    }

    String initials = '';
    if (displayedFirstName.isNotEmpty) initials += displayedFirstName[0];
    if (displayedLastName.isNotEmpty) initials += displayedLastName[0];
    if (initials.isEmpty) initials = 'U';
    initials = initials.toUpperCase();

    return FutureBuilder(
      future: _dynamicContentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildProfileShimmer();
        }

        final logoutText = _dynamicContentCache.getProfileLogoutText() ?? 'Logout';
        final logoutIconName = _dynamicContentCache.getProfileLogoutIcon() ?? 'logout';
        final IconData logoutIcon = _getIconFromString(logoutIconName);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Header
              Container(
                margin: const EdgeInsets.only(top: 30, bottom: 20),
                child: Column(
                  children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: CustomColorTheme.CustomPrimaryAppColor, width: 2),
                      ),
                      child: Center(
                        child: Text(initials, style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: CustomColorTheme.CustomPrimaryAppColor)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('$displayedFirstName $displayedLastName', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(displayedEmail, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Menu Options
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 56,
                        child: _buildProfileOption(
                          icon: Icons.person_outline,
                          title: _dynamicContentCache.getProfileAccountDetails() ?? 'Account Details',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileDetailsScreen(customer: customer!)))
                                .then((val) => _loadCustomerAndData());
                          },
                        ),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      SizedBox(
                        height: 56,
                        child: _buildProfileOption(
                          icon: Icons.shopping_bag_outlined,
                          title: _dynamicContentCache.getProfileMyOrders() ?? 'My Orders',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Logout Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => _logout(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(logoutIcon, size: 20),
                    const SizedBox(width: 10),
                    Text(logoutText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Delete Account Link
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteAccount(context),
                    icon: const Icon(Icons.delete_forever, size: 20, color: Colors.grey),
                    label: const Text("Delete Account", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  // Helper functions
  IconData _getIconFromString(String iconName) {
    if (iconName.contains('exit')) return Icons.exit_to_app;
    return Icons.logout;
  }

  Widget _buildProfileOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: CustomColorTheme.CustomPrimaryAppColor),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[500]),
      onTap: onTap,
    );
  }

  Widget _buildLoginFormShimmer() => const Center(child: CircularProgressIndicator());
  Widget _buildProfileShimmer() => const Center(child: CircularProgressIndicator());
}

// import 'dart:convert';
// import 'package:achhafoods/screens/Profile/profile_laravel_update.dart';
// import 'package:achhafoods/services/DynamicContentCache.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
// import 'package:achhafoods/screens/Consts/appBar.dart';
// import 'package:achhafoods/screens/Drawer/Drawer.dart';
// import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
// import 'package:achhafoods/screens/Profile/OrderDetails.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Consts/CustomFloatingButton.dart';
// import '../Consts/conts.dart';
// import '../Consts/shopify_auth_service.dart' hide localurl;
// import 'ProfileScreen.dart';
// import 'SignUp.dart';
// import '../Home Screens/homepage.dart';
// import 'package:shimmer/shimmer.dart';
//
// class MainScreen extends StatefulWidget {
//   const MainScreen({super.key});
//
//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }
//
// class _MainScreenState extends State<MainScreen> {
//   final _formKey = GlobalKey<FormState>();
//   String email = '';
//   String password = '';
//   bool _isDataFetched = false;
//   late TextEditingController _firstNameController;
//   late TextEditingController _lastNameController;
//   late TextEditingController _emailController;
//   bool isLoading = false;
//   bool _obscurePassword = true;
//   Map<String, dynamic>? _liveLaravelData;
//   Map<String, dynamic>? customer;
//   Map<String, dynamic>? laravelUser;
//   final DynamicContentCache _dynamicContentCache = DynamicContentCache.instance;
//   Future<void>? _dynamicContentFuture;
//   int idofcustomer = 0;
//   bool _isInitialLoad = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _firstNameController = TextEditingController();
//     _lastNameController = TextEditingController();
//     _emailController = TextEditingController();
//
//     // Use post-frame callback to avoid build phase issues
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadCustomerAndData();
//     });
//   }
//
//   Future<void> _loginWithShopifyOAuth() async {
//     setState(() => isLoading = true);
//
//     try {
//       // 1. Call the OAuth Service
//       print('🔵 Starting OAuth login...');
//       final loggedInCustomer = await ShopifyAuthService.loginWithShopify();
//
//       if (loggedInCustomer != null) {
//         print('🟢 OAuth successful!');
//
//         // 2. Get customer email
//         final customerData = loggedInCustomer['customer'] as Map<String, dynamic>?;
//         final String userEmail = customerData?['email'] ?? '';
//
//         if (userEmail.isEmpty) {
//           throw Exception('No email in customer data');
//         }
//
//         // 3. Save to SharedPreferences
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString("shopifyCustomer", jsonEncode(loggedInCustomer));
//         await prefs.setString('customer', json.encode(loggedInCustomer));
//         await prefs.setString('customer_email', userEmail);
//
//         // 4. Update UI state
//         if (mounted) {
//           setState(() {
//             customer = loggedInCustomer;
//             _isInitialLoad = true;
//             _emailController.text = userEmail;
//           });
//         }
//
//         // 5. Sync with Laravel (optional)
//         try {
//           final laravelUrl = Uri.parse("$localurl/api/shopify-login");
//           final laravelResponse = await http.post(
//             laravelUrl,
//             headers: {
//               "Content-Type": "application/json",
//               "Accept": "application/json",
//             },
//             body: jsonEncode({
//               "email": userEmail,
//               "shopify_customer_id": customerData?['id'],
//             }),
//           );
//
//           if (laravelResponse.statusCode == 200) {
//             print('🟢 Laravel sync successful');
//           }
//         } catch (e) {
//           print('⚠️ Laravel sync failed: $e');
//           // Continue anyway - Shopify login is primary
//         }
//
//         Fluttertoast.showToast(
//           msg: "Logged in successfully! 🎉",
//           backgroundColor: Colors.green,
//           textColor: Colors.white,
//         );
//
//         // 6. Navigate to home
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const HomePage()),
//         );
//
//       } else {
//         print('🔴 OAuth returned null');
//         Fluttertoast.showToast(
//           msg: "Login cancelled or failed",
//           backgroundColor: Colors.red,
//           textColor: Colors.white,
//         );
//       }
//     } catch (e) {
//       print('❌ Login error: $e');
//       Fluttertoast.showToast(
//         msg: "Login Error: ${e.toString()}",
//         backgroundColor: Colors.red,
//         textColor: Colors.white,
//       );
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }
//
//   Future<void> _loadCustomerAndData() async {
//     // Mark build phase as active
//     _dynamicContentCache.setBuildPhase(true);
//
//     setState(() => _isInitialLoad = true);
//     _dynamicContentFuture = _dynamicContentCache.loadDynamicData();
//     await _loadCustomer();
//
//     // Mark build phase as ended and load data
//     _dynamicContentCache.setBuildPhase(false);
//
//     if (customer != null) {
//       final customerData = customer!['customer'] as Map<String, dynamic>?;
//       final String customerEmail = customerData?['email'] ?? '';
//
//       if (customerEmail.isNotEmpty) {
//         _emailController.text = customerEmail;
//         await _fetchLatestProfileData();
//
//         final String customerGid = customerData?['id'] ?? '';
//         if (customerGid.isNotEmpty) {
//           idofcustomer = int.parse(extractCustomerId(customerGid));
//         }
//       } else {
//         if (mounted) {
//           setState(() {
//             _isDataFetched = true;
//             _isInitialLoad = false;
//           });
//         }
//       }
//     } else {
//       if (mounted) {
//         setState(() {
//           _isDataFetched = true;
//           _isInitialLoad = false;
//         });
//       }
//     }
//   }
//
//   String extractCustomerId(String customerGid) {
//     final parts = customerGid.split('/');
//     return parts.last;
//   }
//
//   Future<void> _fetchLatestProfileData() async {
//     if (kDebugMode) {
//       print('🔄 _fetchLatestProfileData called.');
//     }
//
//     final String email = _emailController.text;
//
//     if (email.isEmpty) {
//       if (kDebugMode) print('⚠️ Profile fetch aborted because email is empty.');
//       if (mounted) {
//         setState(() {
//           _isDataFetched = true;
//           _isInitialLoad = false;
//         });
//       }
//       return;
//     }
//
//     try {
//       final latestData = await LaravelApiService.getProfile(email: email);
//
//       if (!mounted) return;
//
//       setState(() {
//         _liveLaravelData = latestData;
//         _isDataFetched = true;
//         _isInitialLoad = false;
//
//         String? laravelFullName = latestData['name'] as String?;
//         if (kDebugMode) {
//           print('✅ API Fetch Success. Full Name: $laravelFullName');
//         }
//
//         _firstNameController.text = _extractFirstName(laravelFullName);
//         _lastNameController.text = _extractLastName(laravelFullName);
//       });
//     } catch (e) {
//       if (kDebugMode) {
//         print('❌ Error fetching latest profile data: $e');
//       }
//       Fluttertoast.showToast(
//           msg: 'Could not load latest profile details.',
//           backgroundColor: Colors.red);
//       if (mounted) {
//         setState(() {
//           _isDataFetched = true;
//           _isInitialLoad = false;
//         });
//       }
//     }
//   }
//
//   String _extractFirstName(dynamic name) {
//     if (name == null || name is! String || name.isEmpty) return '';
//     final nameParts = name.trim().split(RegExp(r'\s+'));
//     return nameParts.isNotEmpty ? nameParts.first : '';
//   }
//
//   String _extractLastName(dynamic name) {
//     if (name == null || name is! String || name.isEmpty) return '';
//     final nameParts = name.trim().split(RegExp(r'\s+'));
//     return nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
//   }
//
//   Future<void> _updateSharedPreferencesWithLatestData(
//       Map<String, dynamic> latestData) async {
//     final prefs = await SharedPreferences.getInstance();
//     final storedCustomerJson = prefs.getString('customer');
//     final storedData =
//     storedCustomerJson != null ? json.decode(storedCustomerJson) : {};
//
//     final Map<String, dynamic> newCustomerData = {
//       ...storedData,
//       'laravel_data': latestData,
//     };
//
//     await prefs.setString('customer', json.encode(newCustomerData));
//   }
//
//   Future<void> _showForgotPasswordDialog(BuildContext ctx) async {
//     final emailController = TextEditingController(text: _emailController.text);
//     await showDialog(
//       context: ctx,
//       builder: (ctx2) => AlertDialog(
//         title: const Text(
//           'Reset Password',
//           style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
//         ),
//         content: TextField(
//           controller: emailController,
//           keyboardType: TextInputType.emailAddress,
//           autocorrect: false,
//           textCapitalization: TextCapitalization.none,
//           enableSuggestions: false,
//           onChanged: (value) => email = value,
//           onEditingComplete: () => FocusScope.of(context).unfocus(),
//           autofocus: true,
//           cursorColor: Colors.red,
//           style: const TextStyle(color: Colors.black),
//           decoration: InputDecoration(
//             labelText: 'Enter email',
//             labelStyle: const TextStyle(color: Colors.black),
//             prefixIcon: const Icon(Icons.email, color: Colors.red),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: Colors.red),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(ctx2),
//               child: const Text(
//                 'Cancel',
//                 style: TextStyle(color: Colors.red),
//               )),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//                 backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
//                 disabledBackgroundColor: Colors.blueGrey),
//             onPressed: () async {
//               FocusScope.of(context).unfocus();
//
//               Navigator.pop(ctx2);
//               final success =
//               await ShopifyAuthService.sendResetEmail(emailController.text);
//               ScaffoldMessenger.of(ctx).showSnackBar(
//                 SnackBar(
//                     content: Text(success
//                         ? 'Check your email for reset instructions'
//                         : 'Failed to send reset email')),
//               );
//             },
//             child: const Text(
//               'Send Reset Link',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _loadCustomer() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     final shopifyCustomerData = prefs.getString('shopifyCustomer');
//     if (shopifyCustomerData != null) {
//       setState(() {
//         customer = json.decode(shopifyCustomerData);
//       });
//     }
//
//     final laravelUserData = prefs.getString('laravelUser');
//     if (laravelUserData != null) {
//       setState(() {
//         laravelUser = json.decode(laravelUserData);
//       });
//     }
//   }
//
//   Future<void> _login() async {
//     FocusScope.of(context).unfocus();
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//
//     setState(() => isLoading = true);
//
//     try {
//       final loggedInCustomer =
//       await ShopifyAuthService.loginCustomer(email, password);
//
//       if (loggedInCustomer != null) {
//         final laravelUrl = Uri.parse("$localurl/api/login");
//         final laravelResponse = await http.post(
//           laravelUrl,
//           headers: {
//             "Content-Type": "application/json",
//             "Accept": "application/json",
//           },
//           body: jsonEncode({
//             "email": email,
//             // "password": password,
//           }),
//         );
//
//         final laravelData = jsonDecode(laravelResponse.body);
//         print("All Dataaa: $laravelData");
//
//         if (laravelResponse.statusCode == 200 &&
//             laravelData["status"] == true) {
//           final prefs = await SharedPreferences.getInstance();
//
//           // final token = laravelData["data"]["token"];
//           laravelUser = laravelData["data"];
//           // await prefs.setString("laravelToken", token);
//           await prefs.setString("laravelUser", jsonEncode(laravelUser));
//
//           await prefs.setString(
//               "shopifyCustomer", jsonEncode(loggedInCustomer));
//           await prefs.setString('customer', json.encode(loggedInCustomer));
//
//           if (mounted) {
//             setState(() {
//               customer = loggedInCustomer;
//               laravelUser = laravelData["data"]["user"];
//               _isInitialLoad = true;
//             });
//           }
//
//           Fluttertoast.showToast(
//             msg: "Logged in successfully! 🎉",
//             backgroundColor: Colors.green,
//             textColor: Colors.white,
//           );
//
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => const HomePage()),
//           );
//         } else {
//           Fluttertoast.showToast(
//             msg: laravelData["message"] ??
//                 "Laravel login failed. Please contact support.",
//             backgroundColor: Colors.red,
//             textColor: Colors.white,
//           );
//         }
//       } else {
//         Fluttertoast.showToast(
//           msg: "Invalid email or password",
//           backgroundColor: Colors.red,
//           textColor: Colors.white,
//         );
//       }
//     } catch (e) {
//       if (kDebugMode) print("Login error: $e");
//       Fluttertoast.showToast(
//         msg: "Wrong credentials!",
//         backgroundColor: Colors.red,
//         textColor: Colors.white,
//       );
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }
//
// // --- UPDATED DELETE ACCOUNT FUNCTION ---
//   Future<void> _deleteAccount(BuildContext context) async {
//     final shouldDelete = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.warning_amber_rounded,
//                   color: Colors.red, size: 50),
//               const SizedBox(height: 16),
//               const Text(
//                 "Delete Account?",
//                 style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.red),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 "This action is permanent and cannot be undone. Are you sure?",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.black87),
//               ),
//               const SizedBox(height: 24),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey[300],
//                       foregroundColor: Colors.black87,
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10)),
//                     ),
//                     onPressed: () => Navigator.of(context).pop(false),
//                     child: const Text("Cancel"),
//                   ),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10)),
//                     ),
//                     onPressed: () => Navigator.of(context).pop(true),
//                     child: const Text("Delete"),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//
//     if (shouldDelete != true) return;
//
//     if (mounted) {
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (BuildContext context) =>
//         const Center(child: CircularProgressIndicator(color: CustomColorTheme.CustomPrimaryAppColor,)),
//       );
//     }
//
//     try {
//       // 1. ATTEMPT SHOPIFY DELETE
//       bool shopifyDeleted = false;
//       if (idofcustomer != 0) {
//         shopifyDeleted = await ShopifyAuthService.deleteCustomer(idofcustomer.toString());
//
//         // CHECK SHOPIFY RESPONSE - If not successful, stop here
//         if (!shopifyDeleted) {
//           if (mounted) Navigator.pop(context);
//           Fluttertoast.showToast(
//             msg: "Failed to delete Shopify account. Account cannot be deleted if customer has placed orders.",
//             backgroundColor: Colors.red,
//             textColor: Colors.white,
//           );
//           return; // Don't proceed to Laravel
//         }
//       } else {
//         shopifyDeleted = true; // Assume success if no ID
//       }
//
//       // 2. DEACTIVATE IN LARAVEL (Only reached if Shopify was successful)
//       bool laravelDeactivated = false;
//       String userEmail = _emailController.text;
//       if (userEmail.isEmpty && customer != null) {
//         userEmail = customer!['customer']['email'] ?? '';
//       }
//
//       if (userEmail.isNotEmpty) {
//         try {
//           final laravelUrl = Uri.parse("$localurl/api/delete-account");
//           if (kDebugMode) print("Attempting Laravel Soft Delete for: $userEmail");
//
//           final laravelResponse = await http.post(
//             laravelUrl,
//             headers: {
//               "Content-Type": "application/json",
//               "Accept": "application/json",
//             },
//             body: jsonEncode({"email": userEmail}),
//           );
//
//           if (kDebugMode) {
//             print("Laravel Soft Delete Response: ${laravelResponse.statusCode}");
//             print("Laravel Body: ${laravelResponse.body}");
//           }
//
//           if (laravelResponse.statusCode == 200) {
//             laravelDeactivated = true;
//           }
//         } catch (e) {
//           if (kDebugMode) print("Laravel error: $e");
//         }
//       }
//
//       if (mounted) Navigator.pop(context); // Remove loading
//
//       // 3. FINAL CHECK: Both should be successful
//       if (shopifyDeleted && laravelDeactivated) {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.clear();
//
//         if (mounted) {
//           setState(() {
//             customer = null;
//             laravelUser = null;
//             _isInitialLoad = false;
//             _firstNameController.clear();
//             _lastNameController.clear();
//             _emailController.clear();
//           });
//         }
//
//         Fluttertoast.showToast(
//           msg: "Account deleted successfully",
//           backgroundColor: Colors.grey[700],
//           textColor: Colors.white,
//         );
//       } else {
//         Fluttertoast.showToast(
//           msg: "Failed to delete account. Please try again.",
//           backgroundColor: Colors.red,
//           textColor: Colors.white,
//         );
//       }
//     } catch (e) {
//       if (mounted) Navigator.pop(context);
//       Fluttertoast.showToast(
//           msg: "Error: $e", backgroundColor: Colors.red, textColor: Colors.white);
//     }
//   }
//
//   Future<void> _logout(BuildContext context) async {
//     final shouldLogout = await showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => Dialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.logout, color: Colors.redAccent, size: 50),
//               const SizedBox(height: 16),
//               const Text(
//                 "Logout Confirmation",
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.redAccent,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 "Are you sure you want to log out?",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.black87),
//               ),
//               const SizedBox(height: 24),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.cancel),
//                     label: const Text("Cancel"),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey[300],
//                       foregroundColor: Colors.black87,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     onPressed: () => Navigator.of(context).pop(false),
//                   ),
//                   ElevatedButton.icon(
//                     icon: const Icon(Icons.exit_to_app),
//                     label: const Text("Logout"),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.redAccent,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     onPressed: () => Navigator.of(context).pop(true),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//
//     if (shouldLogout != true) return;
//
//     // 🟢 UPDATED: Call the Service Logout
//     // This clears SecureStorage (tokens) AND SharedPreferences AND Browser Session
//     await ShopifyAuthService.logout();
//
//     if (mounted) {
//       setState(() {
//         customer = null;
//         laravelUser = null;
//         _isInitialLoad = false;
//         _firstNameController.clear();
//         _lastNameController.clear();
//         _emailController.clear();
//       });
//     }
//
//     Fluttertoast.showToast(
//       msg: "Logged out successfully",
//       backgroundColor: Colors.green,
//       textColor: Colors.white,
//     );
//   }
//
//   Widget _shimmerPlaceholder({
//     required double height,
//     required double width,
//     bool isCentered = false,
//   }) {
//     return Container(
//       alignment: isCentered ? Alignment.center : Alignment.centerLeft,
//       child: Container(
//         width: width,
//         height: height,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(
//               4), // Smaller radius for better performance
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProfileShimmer() {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           const SizedBox(height: 30),
//           // Profile image
//           Container(
//             width: 120,
//             height: 120,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(height: 20),
//           // Name
//           Container(
//             width: 200,
//             height: 24,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ),
//           const SizedBox(height: 8),
//           // Email
//           Container(
//             width: 150,
//             height: 16,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(4),
//             ),
//           ),
//           const SizedBox(height: 30),
//           // Card with options
//           Container(
//             width: double.infinity,
//             height: 112,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.2),
//                   blurRadius: 2,
//                   offset: const Offset(0, 1),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 // First option
//                 Container(
//                   height: 55,
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 40,
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[200],
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Container(
//                           height: 16,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[200],
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Container(
//                         width: 16,
//                         height: 16,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[200],
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Divider
//                 Container(
//                   height: 1,
//                   margin: const EdgeInsets.symmetric(horizontal: 20),
//                   color: Colors.grey[300],
//                 ),
//                 // Second option
//                 Container(
//                   height: 56,
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 40,
//                         height: 40,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[200],
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Container(
//                           height: 16,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[200],
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       Container(
//                         width: 16,
//                         height: 16,
//                         decoration: BoxDecoration(
//                           color: Colors.grey[200],
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 20),
//           // Logout button
//           Container(
//             width: double.infinity,
//             height: 50,
//             margin: const EdgeInsets.symmetric(horizontal: 10),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           const SizedBox(height: 30),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLoginFormShimmer() {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           Container(
//             margin: const EdgeInsets.only(top: 40, bottom: 30),
//             child: Column(
//               children: [
//                 // Profile icon
//                 Container(
//                   width: 100,
//                   height: 100,
//                   decoration: const BoxDecoration(
//                     color: Colors.white,
//                     shape: BoxShape.circle,
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 // Welcome text
//                 Container(
//                   width: 200,
//                   height: 24,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 // Sign in text
//                 Container(
//                   width: 150,
//                   height: 16,
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Email field
//           Container(
//             height: 56,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           const SizedBox(height: 20),
//           // Password field
//           Container(
//             height: 56,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           const SizedBox(height: 20),
//           // Login button
//           Container(
//             height: 50,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           const SizedBox(height: 25),
//           // OR divider
//           Row(
//             children: [
//               Expanded(
//                 child: Container(
//                   height: 1,
//                   color: Colors.grey[300],
//                 ),
//               ),
//               Container(
//                 width: 30,
//                 height: 16,
//                 margin: const EdgeInsets.symmetric(horizontal: 15),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//               Expanded(
//                 child: Container(
//                   height: 1,
//                   color: Colors.grey[300],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 25),
//           // Create account button
//           Container(
//             height: 50,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: Colors.grey[300]!),
//             ),
//           ),
//           const SizedBox(height: 30),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: const CustomAppBar(),
//       bottomNavigationBar: const NewNavigationBar(),
//       floatingActionButton: CustomWhatsAppFAB(),
//       drawer: const CustomDrawer(),
//       body: RefreshIndicator(
//         color: CustomColorTheme.CustomPrimaryAppColor,
//         onRefresh: () async {
//           setState(() => _isInitialLoad = true);
//           await _dynamicContentCache.loadDynamicData();
//           if (customer != null) {
//             await _loadCustomerAndData();
//           }
//           setState(() => _isInitialLoad = false);
//         },
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: ConstrainedBox(
//             constraints: BoxConstraints(
//               minHeight: MediaQuery.of(context).size.height -
//                   (kToolbarHeight +
//                       (MediaQuery.of(context).padding.top) +
//                       kBottomNavigationBarHeight),
//             ),
//             child: Container(
//               // ADDED BOTTOM PADDING to prevent 1.00 pixel overflow
//               padding: const EdgeInsets.fromLTRB(
//                   24, 0, 24, 25), // Increased bottom padding to 25
//               child: _buildContent(),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildContent() {
//     if (_isInitialLoad) {
//       return customer == null
//           ? _buildLoginFormShimmer()
//           : _buildProfileShimmer();
//     }
//
//     return customer == null ? _buildLoginForm() : _buildProfileView();
//   }
//
//   Widget _buildLoginForm() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Container(
//           margin: const EdgeInsets.only(top: 60, bottom: 40),
//           child: Column(
//             children: [
//               Container(
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   color: CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.1),
//                   shape: BoxShape.circle,
//                   border: Border.all(
//                     color: CustomColorTheme.CustomPrimaryAppColor,
//                     width: 2,
//                   ),
//                 ),
//                 child: const Icon(
//                   Icons.person_outline,
//                   size: 50,
//                   color: CustomColorTheme.CustomPrimaryAppColor,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 'Welcome',
//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.grey[800],
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Sign in to access your account',
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         // 🟢 MAIN LOGIN BUTTON
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
//             padding: const EdgeInsets.symmetric(vertical: 18),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//             elevation: 3,
//           ),
//           onPressed: isLoading ? null : _loginWithShopifyOAuth,
//           child: isLoading
//               ? const SizedBox(
//             width: 20,
//             height: 20,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               color: Colors.white,
//             ),
//           )
//               : Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: const [
//               Icon(Icons.login, color: Colors.white),
//               SizedBox(width: 10),
//               Text(
//                 'LOG IN WITH SHOPIFY',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         const SizedBox(height: 30),
//
//         // CREATE ACCOUNT BUTTON
//         OutlinedButton(
//           style: OutlinedButton.styleFrom(
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             side: const BorderSide(
//               color: CustomColorTheme.CustomPrimaryAppColor,
//               width: 1.5,
//             ),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           onPressed: () {
//             // Note: Creating an account also happens via the OAuth Web UI usually,
//             // but if you keep your custom signup, leave this here.
//             Navigator.push(
//               context,
//               MaterialPageRoute(builder: (context) => const MyAccount()),
//             );
//           },
//           child: const Text(
//             'CREATE NEW ACCOUNT',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: CustomColorTheme.CustomPrimaryAppColor,
//             ),
//           ),
//         ),
//         const SizedBox(height: 30),
//       ],
//     );
//   }
//   // Widget _buildLoginForm() {
//   //   return Form(
//   //     key: _formKey,
//   //     child: Column(
//   //       crossAxisAlignment: CrossAxisAlignment.stretch,
//   //       children: [
//   //         Container(
//   //           margin: const EdgeInsets.only(top: 40, bottom: 30),
//   //           child: Column(
//   //             children: [
//   //               Container(
//   //                 width: 100,
//   //                 height: 100,
//   //                 decoration: BoxDecoration(
//   //                   color:
//   //                   CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.1),
//   //                   shape: BoxShape.circle,
//   //                   border: Border.all(
//   //                     color: CustomColorTheme.CustomPrimaryAppColor,
//   //                     width: 2,
//   //                   ),
//   //                 ),
//   //                 child: const Icon(
//   //                   Icons.person_outline,
//   //                   size: 50,
//   //                   color: CustomColorTheme.CustomPrimaryAppColor,
//   //                 ),
//   //               ),
//   //               const SizedBox(height: 20),
//   //               Text(
//   //                 'Welcome Back',
//   //                 style: TextStyle(
//   //                   fontSize: 24,
//   //                   fontWeight: FontWeight.bold,
//   //                   color: Colors.grey[800],
//   //                 ),
//   //               ),
//   //               const SizedBox(height: 8),
//   //               Text(
//   //                 'Sign in to continue',
//   //                 style: TextStyle(
//   //                   fontSize: 16,
//   //                   color: Colors.grey[600],
//   //                 ),
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //         TextFormField(
//   //           decoration: InputDecoration(
//   //             labelText: 'Email',
//   //             labelStyle: const TextStyle(color: Colors.black),
//   //             prefixIcon: const Icon(Icons.email,
//   //                 color: CustomColorTheme.CustomPrimaryAppColor),
//   //             border: OutlineInputBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //               borderSide: BorderSide(color: Colors.grey[300]!),
//   //             ),
//   //             focusedBorder: OutlineInputBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //               borderSide: const BorderSide(
//   //                   color: CustomColorTheme.CustomPrimaryAppColor),
//   //             ),
//   //           ),
//   //           keyboardType: TextInputType.emailAddress,
//   //           validator: (value) => value?.isEmpty ?? true
//   //               ? 'Required'
//   //               : !value!.contains('@')
//   //               ? 'Invalid email'
//   //               : null,
//   //           onChanged: (value) => email = value,
//   //         ),
//   //         const SizedBox(height: 20),
//   //         TextFormField(
//   //           decoration: InputDecoration(
//   //             labelText: 'Password',
//   //             labelStyle: const TextStyle(color: Colors.black),
//   //             prefixIcon: const Icon(Icons.lock,
//   //                 color: CustomColorTheme.CustomPrimaryAppColor),
//   //             suffixIcon: IconButton(
//   //               icon: Icon(
//   //                 _obscurePassword ? Icons.visibility_off : Icons.visibility,
//   //                 color: Colors.grey[600],
//   //               ),
//   //               onPressed: () =>
//   //                   setState(() => _obscurePassword = !_obscurePassword),
//   //             ),
//   //             border: OutlineInputBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //               borderSide: BorderSide(color: Colors.grey[300]!),
//   //             ),
//   //             focusedBorder: OutlineInputBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //               borderSide: const BorderSide(
//   //                   color: CustomColorTheme.CustomPrimaryAppColor),
//   //             ),
//   //           ),
//   //           obscureText: _obscurePassword,
//   //           validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
//   //           onChanged: (value) => password = value,
//   //         ),
//   //         const SizedBox(height: 20),
//   //         ElevatedButton(
//   //           style: ElevatedButton.styleFrom(
//   //             backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
//   //             padding: const EdgeInsets.symmetric(vertical: 16),
//   //             shape: RoundedRectangleBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //             ),
//   //             elevation: 3,
//   //           ),
//   //           onPressed: isLoading ? null : _login,
//   //           child: isLoading
//   //               ? const SizedBox(
//   //             width: 20,
//   //             height: 20,
//   //             child: CircularProgressIndicator(
//   //               strokeWidth: 2,
//   //               color: Colors.white,
//   //             ),
//   //           )
//   //               : const Text(
//   //             'LOGIN',
//   //             style: TextStyle(
//   //               fontSize: 16,
//   //               fontWeight: FontWeight.bold,
//   //               color: Colors.white,
//   //             ),
//   //           ),
//   //         ),
//   //         const SizedBox(height: 25),
//   //         Row(
//   //           children: [
//   //             Expanded(
//   //               child: Divider(
//   //                 color: Colors.grey[400],
//   //                 thickness: 1,
//   //               ),
//   //             ),
//   //             Padding(
//   //               padding: const EdgeInsets.symmetric(horizontal: 15),
//   //               child: Text(
//   //                 'OR',
//   //                 style: TextStyle(
//   //                   color: Colors.grey[600],
//   //                   fontWeight: FontWeight.bold,
//   //                 ),
//   //               ),
//   //             ),
//   //             Expanded(
//   //               child: Divider(
//   //                 color: Colors.grey[400],
//   //                 thickness: 1,
//   //               ),
//   //             ),
//   //           ],
//   //         ),
//   //         const SizedBox(height: 25),
//   //         OutlinedButton(
//   //           style: OutlinedButton.styleFrom(
//   //             padding: const EdgeInsets.symmetric(vertical: 16),
//   //             side: const BorderSide(
//   //               color: CustomColorTheme.CustomPrimaryAppColor,
//   //               width: 1.5,
//   //             ),
//   //             shape: RoundedRectangleBorder(
//   //               borderRadius: BorderRadius.circular(10),
//   //             ),
//   //           ),
//   //           onPressed: () {
//   //             Navigator.push(
//   //               context,
//   //               MaterialPageRoute(builder: (context) => const MyAccount()),
//   //             );
//   //           },
//   //           child: const Text(
//   //             'CREATE NEW ACCOUNT',
//   //             style: TextStyle(
//   //               fontSize: 16,
//   //               fontWeight: FontWeight.bold,
//   //               color: CustomColorTheme.CustomPrimaryAppColor,
//   //             ),
//   //           ),
//   //         ),
//   //         const SizedBox(height: 30),
//   //       ],
//   //     ),
//   //   );
//   // }
//
//   Widget _buildProfileView() {
//     String displayedFirstName = _firstNameController.text;
//     String displayedLastName = _lastNameController.text;
//     final customerDetails = customer?['customer'] as Map<String, dynamic>?;
//
//     if (displayedFirstName.isEmpty) {
//       displayedFirstName = customerDetails?['firstName'] ?? 'User';
//       displayedLastName = customerDetails?['lastName'] ?? '';
//     }
//
//     final String displayedEmail = _emailController.text.isNotEmpty
//         ? _emailController.text
//         : customerDetails?['email'] ?? '';
//
//     String initials = '';
//     if (displayedFirstName.isNotEmpty) initials += displayedFirstName[0];
//     if (displayedLastName.isNotEmpty) initials += displayedLastName[0];
//     if (initials.isEmpty) initials = 'U';
//     initials = initials.toUpperCase();
//
//     return FutureBuilder(
//       future: _dynamicContentFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return _buildProfileShimmer();
//         }
//
//         final logoutText =
//             _dynamicContentCache.getProfileLogoutText() ?? 'Logout';
//         final logoutIconName =
//             _dynamicContentCache.getProfileLogoutIcon() ?? 'logout';
//         final IconData logoutIcon = _getIconFromString(logoutIconName);
//
//         return SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Container(
//                 margin: const EdgeInsets.only(top: 30, bottom: 20),
//                 child: Column(
//                   children: [
//                     Container(
//                       width: 120,
//                       height: 120,
//                       decoration: BoxDecoration(
//                         color:
//                         CustomColorTheme.CustomPrimaryAppColor.withOpacity(0.1),
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: CustomColorTheme.CustomPrimaryAppColor,
//                           width: 2,
//                         ),
//                       ),
//                       child: Center(
//                         child: Text(
//                           initials,
//                           style: const TextStyle(
//                             fontSize: 45,
//                             fontWeight: FontWeight.bold,
//                             color: CustomColorTheme.CustomPrimaryAppColor,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     Text(
//                       '$displayedFirstName $displayedLastName',
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       displayedEmail,
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 30),
//               // FIX: Use Container with explicit height for the Card
//               SizedBox(
//                 width: double.infinity,
//                 child: Card(
//                   elevation: 2,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       SizedBox(
//                         height: 56, // Fixed height for consistent layout
//                         child: _buildProfileOption(
//                           icon: Icons.person_outline,
//                           title:
//                           _dynamicContentCache.getProfileAccountDetails() ??
//                               'Account Details',
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) =>
//                                     ProfileDetailsScreen(customer: customer!),
//                               ),
//                             ).then((shouldReload) async {
//                               if (shouldReload == true) {
//                                 await _loadCustomerAndData();
//                                 if (mounted) setState(() {});
//                               }
//                             });
//                           },
//                         ),
//                       ),
//                       const Divider(height: 1, indent: 20, endIndent: 20),
//                       SizedBox(
//                         height: 56, // Fixed height for consistent layout
//                         child: _buildProfileOption(
//                           icon: Icons.shopping_bag_outlined,
//                           title: _dynamicContentCache.getProfileMyOrders() ??
//                               'My Orders',
//                           onTap: () {
//                             Navigator.push(
//                                 context,
//                                 MaterialPageRoute(
//                                     builder: (context) =>
//                                     const MyOrdersScreen()));
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red[50],
//                   foregroundColor: Colors.red,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   elevation: 0,
//                 ),
//                 onPressed: () => _logout(context),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(logoutIcon, size: 20),
//                     const SizedBox(width: 10),
//                     Text(
//                       logoutText,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               // --- ADDED DELETE ACCOUNT BUTTON BELOW LOGOUT (LEFT SIDE) ---
//               const SizedBox(height: 10),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.start, // Aligns to left
//                 children: [
//                   TextButton.icon(
//                     onPressed: () => _deleteAccount(context),
//                     icon: const Icon(Icons.delete_forever,
//                         size: 20, color: Colors.grey),
//                     label: const Text(
//                       "Delete Account",
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey,
//                       ),
//                     ),
//                     style: TextButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 10, vertical: 5),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 30),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   IconData _getIconFromString(String iconName) {
//     switch (iconName.toLowerCase()) {
//       case 'logout':
//         return Icons.logout;
//       case 'exit_to_app':
//         return Icons.exit_to_app;
//       case 'power_settings_new':
//         return Icons.power_settings_new;
//       case 'close':
//         return Icons.close;
//       case 'cancel':
//         return Icons.cancel;
//       case 'arrow_back':
//         return Icons.arrow_back;
//       default:
//         return Icons.logout;
//     }
//   }
//
//   Widget _buildProfileOption({
//     required IconData icon,
//     required String title,
//     required VoidCallback onTap,
//     IconData trailingIcon = Icons.chevron_right,
//   }) {
//     return ListTile(
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
//       minVerticalPadding: 0,
//       dense: false,
//       leading: Icon(icon, color: CustomColorTheme.CustomPrimaryAppColor),
//       title: Text(title, style: const TextStyle(fontSize: 16)),
//       trailing: Icon(trailingIcon, color: Colors.grey[500]),
//       onTap: onTap,
//     );
//   }
// }