import 'dart:convert';
import 'package:achhafoods/screens/Profile/profile_laravel_update.dart';
import 'package:achhafoods/services/DynamicContentCache.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';
import '../Consts/shopify_auth_service.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const ProfileDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  // Personal Info Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  // Shopify Address Controllers
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;

  // Password Controllers
  late TextEditingController _currentPasswordController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool isUpdating = false;
  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  Map<String, dynamic>? _liveLaravelData;
  List<dynamic> _fullAddresses = [];
  int idofcustomer = 0;
  bool _isDataFetched = false;

  // Initialize Dynamic Cache
  final DynamicContentCache _dynamicContentCache = DynamicContentCache.instance;

  @override
  void initState() {
    super.initState();

    // Ensure dynamic data is loaded (it should be cached, but safe to call)
    _dynamicContentCache.loadDynamicData();

    final customerData = widget.customer['customer'] as Map<String, dynamic>?;
    final String customerGid = customerData?['id'] ?? '';
    if (customerGid.isNotEmpty) {
      idofcustomer = int.parse(extractCustomerId(customerGid));
    }

    final laravelData = widget.customer['laravel_data'] as Map<String, dynamic>?;

    // Initialize ALL Controllers FIRST
    _emailController = TextEditingController(text: customerData?['email'] ?? '');

    _firstNameController = TextEditingController(
        text: _extractFirstName(
            laravelData?['name'] ?? customerData?['firstName']));
    _lastNameController = TextEditingController(
        text: _extractLastName(
            laravelData?['name'] ?? customerData?['lastName']));
    _phoneController = TextEditingController(
        text: laravelData?['phone'] ?? customerData?['phone'] ?? '');

    final defaultAddress =
    customerData?['defaultAddress'] as Map<String, dynamic>?;
    _address1Controller =
        TextEditingController(text: defaultAddress?['address1'] ?? '');
    _address2Controller =
        TextEditingController(text: defaultAddress?['address2'] ?? '');

    _currentPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _fullAddresses = (laravelData?['full_addresses'] is List)
        ? laravelData!['full_addresses'] as List<dynamic>
        : [];

    // Call the API for latest data
    _fetchLatestProfileData();
  }

  // Helper to safely extract first name
  String _extractFirstName(dynamic name) {
    if (name == null || name is! String || name.isEmpty) return '';
    final nameString = name.trim();
    return nameString.split(' ').isNotEmpty ? nameString.split(' ').first : '';
  }

  // Helper to safely extract last name
  String _extractLastName(dynamic name) {
    if (name == null || name is! String || name.isEmpty) return '';
    final nameParts = name.trim().split(' ');
    return nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
  }

  // --- NEW METHOD: Refresh Dynamic Content Cache ---
  Future<void> _refreshDynamicContentCache() async {
    try {
      await _dynamicContentCache.loadDynamicData();
      if (kDebugMode) {
        print("✅ Dynamic content cache refreshed after profile update");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error refreshing dynamic content cache: $e");
      }
    }
  }

  // --- Method to Fetch and Update Latest Data ---
  Future<void> _fetchLatestProfileData() async {
    final String email = _emailController.text;

    if (email.isEmpty) return;

    try {
      final latestData = await LaravelApiService.getProfile(email: email);

      if (!mounted) return;

      setState(() {
        _liveLaravelData = latestData;
        _isDataFetched = true;

        String? laravelFullName = latestData['name'] as String?;

        _firstNameController.text = _extractFirstName(laravelFullName);
        _lastNameController.text = _extractLastName(laravelFullName);
        _phoneController.text = latestData['phone'] ?? '';

        if (latestData['full_addresses'] is Map<String, dynamic>) {
          _fullAddresses = (latestData['full_addresses'] as Map<String, dynamic>)
              .entries
              .map((e) => {'label': e.key, 'address': e.value})
              .toList();
        } else if (latestData['full_addresses'] is List) {
          _fullAddresses = latestData['full_addresses'] as List<dynamic>;
        } else {
          _fullAddresses = [];
        }

        _updateSharedPreferencesWithLatestData(latestData);
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest profile data: $e');
      }
      Fluttertoast.showToast(
          msg: 'Could not load latest profile details.',
          backgroundColor: Colors.red);
      if (mounted) {
        setState(() {
          _isDataFetched = true;
        });
      }
    }
  }

  // --- Helper Method to update Shared Preferences ---
  Future<void> _updateSharedPreferencesWithLatestData(
      Map<String, dynamic> latestData) async {
    final prefs = await SharedPreferences.getInstance();
    final storedCustomerJson = prefs.getString('customer');
    final storedData = storedCustomerJson != null ? json.decode(storedCustomerJson) : {};

    final Map<String, dynamic> newCustomerData = {
      ...storedData,
      'laravel_data': latestData,
    };

    await prefs.setString('customer', json.encode(newCustomerData));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

    _address1Controller.dispose();
    _address2Controller.dispose();

    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper to show modal for adding a new address
  void _showAddAddressModal() {
    final TextEditingController labelController = TextEditingController();
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildTextField(
                controller: labelController,
                label: 'Address Label (e.g., Home, Work)',
                icon: Icons.label_important_outline,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                controller: addressController,
                label: 'Full Address',
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                final label = labelController.text.trim();
                final address = addressController.text.trim();

                if (label.isEmpty || address.isEmpty) {
                  Fluttertoast.showToast(msg: 'All fields are required.');
                  return;
                }

                Navigator.of(context).pop();
                await _updateAddressViaApi(label, address);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAddressViaApi(String label, String address) async {
    setState(() => isUpdating = true);

    try {
      final laravelUpdateResult = await LaravelApiService.updateProfile(
        email: _emailController.text,
        newAddressLabel: label,
        newAddressValue: address,
      );

      if (mounted) {
        setState(() {
          if (laravelUpdateResult['full_addresses'] is Map<String, dynamic>) {
            _fullAddresses = (laravelUpdateResult['full_addresses']
            as Map<String, dynamic>)
                .entries
                .map((e) => {'label': e.key, 'address': e.value})
                .toList();
          } else if (laravelUpdateResult['full_addresses'] is List) {
            _fullAddresses =
            laravelUpdateResult['full_addresses'] as List<dynamic>;
          } else {
            _fullAddresses = [];
          }
        });
      }
      Fluttertoast.showToast(
          msg: 'Address added successfully!', backgroundColor: Colors.green);
      await _updateSharedPreferencesWithLatestData(laravelUpdateResult);

      // 🔄 REFRESH CACHE AFTER SUCCESSFUL UPDATE
      await _refreshDynamicContentCache();
        } catch (e) {
      Fluttertoast.showToast(
          msg: 'Error adding address: ${e.toString()}',
          backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    FocusScope.of(context).unfocus();

    final String? currentAccessToken = widget.customer['accessToken'];
    final String email = _emailController.text;

    if (currentAccessToken == null || email.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Authentication token or email missing. Please log in again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final bool changingPassword = _passwordController.text.isNotEmpty;
    if (changingPassword) {
      if (_passwordController.text != _confirmPasswordController.text) {
        Fluttertoast.showToast(
          msg: 'New passwords do not match',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      if (_currentPasswordController.text.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Please enter current password to change password',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    setState(() => isUpdating = true);

    try {
      if (idofcustomer.toString().isEmpty) {
        throw Exception('Customer ID not found');
      }

      final String customerId = extractCustomerId(idofcustomer.toString());

      bool shopifySuccess = false;
      bool laravelSuccess = false;

      // 1️⃣ Attempt Shopify password update first (if requested)
      if (changingPassword) {
        final newPassword = _passwordController.text;

        final shopifyPasswordResult =
        await ShopifyAuthService.updateCustomerPassword(
          customerId: customerId,
          newPassword: newPassword,
        );

        if (shopifyPasswordResult != null) {
          shopifySuccess = true;
          if (kDebugMode) print("✅ Shopify password updated successfully.");
        } else {
          Fluttertoast.showToast(
            msg: 'Failed to update password on Shopify. Aborting update.',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          setState(() => isUpdating = false);
          return;
        }
      }

      // 2️⃣ Attempt Laravel update
      final laravelResult = await LaravelApiService.updateProfile(
        email: email,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        oldPassword: changingPassword ? _currentPasswordController.text : null,
        newPassword: changingPassword ? _passwordController.text : null,
      );

      laravelSuccess = true;
      if (mounted) {
        setState(() {
          _fullAddresses = laravelResult['full_addresses'] ?? [];
        });
      }
    
      if (changingPassword && (!shopifySuccess || !laravelSuccess)) {
        Fluttertoast.showToast(
          msg:
          '❌ Password not synced. Either Shopify or Laravel update failed. Rolling back...',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => isUpdating = false);
        return;
      }

      if (!changingPassword || (shopifySuccess && laravelSuccess)) {
        final updatedCustomerResult = await ShopifyAuthService.updateCustomerInfo(
          customerId: customerId,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          email: email,
          phone: _phoneController.text,
        );

        if (updatedCustomerResult != null) {
          final prefs = await SharedPreferences.getInstance();
          final storedData = json.decode(prefs.getString('customer') ?? '{}');

          final Map<String, dynamic> updatedCustomer = {
            ...storedData['customer'] ?? {},
            'firstName': _firstNameController.text,
            'lastName': _lastNameController.text,
            'email': email,
            'phone': _phoneController.text,
          };

          final Map<String, dynamic> newCustomerData = {
            ...storedData,
            'customer': updatedCustomer,
          };

          await prefs.setString('customer', json.encode(newCustomerData));

          Fluttertoast.showToast(
            msg:
            '✅ Profile updated successfully! ${changingPassword ? 'Password synced across both systems.' : ''}',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );

          // 🔄 REFRESH CACHE AFTER SUCCESSFUL PROFILE UPDATE
          await _refreshDynamicContentCache();

          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(
            msg: '⚠️ Shopify info update failed.',
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error updating profile: $e");
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
          _currentPasswordController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      }
    }
  }

  String extractCustomerId(String customerGid) {
    final parts = customerGid.split('/');
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    // Determine the loading state
    final bool isContentLoading =
        _dynamicContentCache.isLoading || !_isDataFetched;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchLatestProfileData();
        await _refreshDynamicContentCache(); // Also refresh cache on pull-to-refresh
      },
      child: Scaffold(
        appBar: const CustomAppBar(),
        bottomNavigationBar: const NewNavigationBar(),
        drawer: const CustomDrawer(),
        body: ListenableBuilder(
          listenable: _dynamicContentCache,
          builder: (context, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: isContentLoading
                  ? _buildShimmerLoading()
                  : _buildProfileContent(),
            );
          },
        ),
      ),
    );
  }

  // Helper function to build the actual profile content
  Widget _buildProfileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: Center(
            child: Text(
              _dynamicContentCache.getAccountDetailsText() ?? 'Account Details',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Personal Info Section
        Text(
          _dynamicContentCache.getAccountPersonalInformation() ??
              'Personal Information',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 15),

        _buildTextField(
          controller: _firstNameController,
          label: _dynamicContentCache.getAccountFirstName() ?? 'First Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _lastNameController,
          label: _dynamicContentCache.getAccountLastName() ?? 'Last Name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _emailController,
          label: _dynamicContentCache.getAccountEmail() ?? 'Email',
          icon: Icons.email_outlined,
          enabled: false,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          controller: _phoneController,
          label: _dynamicContentCache.getAccountPhoneNumber() ?? 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 30),

        // --- Saved Addresses Section ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _dynamicContentCache.getAccountSavedShippingAddresses() ??
                  'Saved Shipping Addresses',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle,
                  color: CustomColorTheme.CustomPrimaryAppColor, size: 30),
              onPressed: _showAddAddressModal,
            ),
          ],
        ),
        const SizedBox(height: 15),

        if (_fullAddresses.isEmpty)
          const Text('No saved addresses. Tap the + to add one.',
              style: TextStyle(fontStyle: FontStyle.italic)),

        ..._fullAddresses.map((address) => _buildAddressCard(address)),

        const SizedBox(height: 30),

        // Password Section
        Text(
          _dynamicContentCache.getAccountChangePasswordTitle() ??
              'Change Password',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 15),
        _buildPasswordField(
          controller: _currentPasswordController,
          label:
          _dynamicContentCache.getAccountCurrentPassword() ?? 'Current Password',
          isVisible: _isCurrentPasswordVisible,
          onToggleVisibility: () =>
              setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
        ),
        const SizedBox(height: 15),
        _buildPasswordField(
          controller: _passwordController,
          label: _dynamicContentCache.getAccountNewPassword() ?? 'New Password',
          isVisible: _isNewPasswordVisible,
          onToggleVisibility: () =>
              setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
        ),
        const SizedBox(height: 15),
        _buildPasswordField(
          controller: _confirmPasswordController,
          label: _dynamicContentCache.getAccountConfirmNewPassword() ??
              'Confirm New Password',
          isVisible: _isConfirmPasswordVisible,
          onToggleVisibility: () => setState(
                  () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
        const SizedBox(height: 30),

        // Update Button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
          ),
          onPressed: isUpdating ? null : _updateProfile,
          child: isUpdating
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            _dynamicContentCache.getAccountUpdateButtonText() ??
                'UPDATE PROFILE',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Helper function to build Shimmer placeholders
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Shimmer
          _shimmerPlaceholder(height: 25, width: 200, isCentered: true),
          const SizedBox(height: 30),

          // Personal Info Title Shimmer
          _shimmerPlaceholder(height: 18, width: 150),
          const SizedBox(height: 15),

          // Text Field Shimmer (4 fields for personal info)
          for (int i = 0; i < 4; i++) ...[
            _shimmerPlaceholder(height: 50, width: double.infinity),
            const SizedBox(height: 15),
          ],
          const SizedBox(height: 30),

          // Addresses Title Shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmerPlaceholder(height: 18, width: 200),
              _shimmerPlaceholder(height: 30, width: 30),
            ],
          ),
          const SizedBox(height: 15),

          // Address Card Shimmer (2 placeholders)
          _shimmerAddressCardPlaceholder(),
          _shimmerAddressCardPlaceholder(),
          const SizedBox(height: 30),

          // Password Title Shimmer
          _shimmerPlaceholder(height: 18, width: 150),
          const SizedBox(height: 15),

          // Password Field Shimmer (3 fields)
          for (int i = 0; i < 3; i++) ...[
            _shimmerPlaceholder(height: 50, width: double.infinity),
            const SizedBox(height: 15),
          ],
          const SizedBox(height: 30),

          // Button Shimmer
          _shimmerPlaceholder(height: 50, width: double.infinity),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Reusable Shimmer Placeholder Block
  Widget _shimmerPlaceholder({
    required double height,
    required double width,
    bool isCentered = false,
  }) {
    return Container(
      alignment: isCentered ? Alignment.center : Alignment.centerLeft,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Reusable Shimmer Placeholder for Address Card
  Widget _shimmerAddressCardPlaceholder() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            _shimmerPlaceholder(height: 30, width: 30), // Icon
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerPlaceholder(height: 14, width: 120), // Label
                  const SizedBox(height: 5),
                  _shimmerPlaceholder(height: 12, width: double.infinity), // Subtitle line 1
                  const SizedBox(height: 3),
                  _shimmerPlaceholder(height: 12, width: 180), // Subtitle line 2
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Existing Helper Widgets (Unchanged)
  Widget _buildAddressCard(Map<String, dynamic> address) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
            (address['label'] ?? '').toLowerCase().contains('home')
                ? Icons.home
                : Icons.work,
            color: CustomColorTheme.CustomPrimaryAppColor),
        title: Text(
          address['label'] ?? 'General Address',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: CustomColorTheme.CustomPrimaryAppColor,
          ),
        ),
        subtitle: Text(
          address['address'] ?? 'Address details not available.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: CustomColorTheme.CustomPrimaryAppColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor),
        ),
        filled: !enabled,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline,
            color: CustomColorTheme.CustomPrimaryAppColor),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey[600],
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor),
        ),
      ),
    );
  }
}