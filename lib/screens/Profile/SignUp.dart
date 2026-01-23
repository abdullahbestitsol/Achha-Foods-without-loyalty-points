import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // Import for random password generation
import '../Consts/CustomFloatingButton.dart';
import '../Consts/shopify_auth_service.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({super.key});

  @override
  State<MyAccount> createState() => _MyAccountState();
}

class _MyAccountState extends State<MyAccount> {
  final _formKey = GlobalKey<FormState>();

  // Controllers allow better control over text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _registerCustomer() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String email = _emailController.text.trim();
    String phoneNumber = _phoneController.text.trim();
    String referralCode = _referralController.text.trim();

    try {
      // ---------------------------------------------------------
      // 1️⃣ CHECK REFERRAL CODE (Optional)
      // ---------------------------------------------------------
      if (referralCode.isNotEmpty) {
        final referralCheckUrl = Uri.parse("$localurl/api/check-referral-code");
        try {
          final referralCheckResponse = await http.post(
            referralCheckUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"referral_code": referralCode}),
          );

          final referralCheckData = jsonDecode(referralCheckResponse.body);
          if (referralCheckResponse.statusCode != 200 ||
              referralCheckData["status"] != true) {
            Fluttertoast.showToast(
              msg: "Invalid referral code",
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
            setState(() => isLoading = false);
            return;
          }
        } catch (e) {
          print("Referral check error: $e");
          // Continue or stop based on your logic. Usually stop if check fails.
        }
      }

      // ---------------------------------------------------------
      // 2️⃣ REGISTER IN SHOPIFY (Admin API)
      // ---------------------------------------------------------
      // We generate a complex dummy password because the Admin API requires one,
      // but the user will actually login via OTP/OAuth, so they never need this password.
      String dummyPassword = "Auto${_generateRandomString(8)}!";

      final shopifyCustomer = await ShopifyAuthService.registerCustomer(
        firstName,
        lastName,
        email,
        dummyPassword,
      );

      // Check if email already exists in Shopify
      if (shopifyCustomer == null) {
        Fluttertoast.showToast(
          msg: "Email already registered in Shopify. Please Log In.",
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        setState(() => isLoading = false);
        return;
      }

      // ---------------------------------------------------------
      // 3️⃣ REGISTER IN LARAVEL
      // ---------------------------------------------------------
      final laravelRegisterUrl = Uri.parse("$localurl/api/register");

      Map<String, dynamic> requestBody = {
        "name": "$firstName $lastName",
        "email": email,
        "phone": phoneNumber,
        // We don't send password to Laravel as it is an OTP/OAuth user
      };

      if (referralCode.isNotEmpty) {
        requestBody["referred_by"] = referralCode;
      }

      final laravelResponse = await http.post(
        laravelRegisterUrl,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      final laravelData = jsonDecode(laravelResponse.body);

      if (laravelResponse.statusCode == 201 && laravelData["status"] == true) {
        // ✅ SUCCESS
        Fluttertoast.showToast(
          msg: "Account created! 🎉\nPlease tap 'Log in with Shopify' to continue.",
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );

        // Navigate back to Login Screen so they can click the big Login button
        if (mounted) Navigator.pop(context);

      } else if (laravelResponse.statusCode == 422) {
        // ❌ VALIDATION ERROR (Laravel)
        print('Laravel validation failed: ${laravelResponse.body}');
        String errorMessage = "Registration failed.";

        if (laravelData["errors"] != null && laravelData["errors"] is Map) {
          if (laravelData["errors"]["email"] != null) {
            errorMessage = laravelData["errors"]["email"].first;
          } else if (laravelData["errors"]["phone"] != null) {
            errorMessage = laravelData["errors"]["phone"].first;
          }
        } else if (laravelData["message"] != null) {
          errorMessage = laravelData["message"];
        }

        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } else {
        // ❌ OTHER LARAVEL ERROR
        Fluttertoast.showToast(
          msg: laravelData["message"] ?? "Registration failed in database.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Registration Exception: $e');
      Fluttertoast.showToast(
        msg: "An error occurred. Please check your internet.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _generateRandomString(int length) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      appBar: const CustomAppBar(),
      bottomNavigationBar: const NewNavigationBar(),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: Text(
                  'Create New Account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // First Name
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 15),

              // Last Name
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 15),

              // Email
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (!val.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              // const SizedBox(height: 15),
              //
              // // Referral (Optional)
              // _buildTextField(
              //   controller: _referralController,
              //   label: 'Referral Code (Optional)',
              //   keyboardType: TextInputType.text,
              // ),

              const SizedBox(height: 30),

              // Create Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                onPressed: isLoading ? null : _registerCustomer,
                child: isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Back to Login
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(color: CustomColorTheme.CustomPrimaryAppColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: Icon(
          _getIconForLabel(label),
          color: CustomColorTheme.CustomPrimaryAppColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  IconData _getIconForLabel(String label) {
    if (label.contains('Email')) return Icons.email_outlined;
    if (label.contains('Phone')) return Icons.phone;
    if (label.contains('Referral')) return Icons.card_giftcard;
    return Icons.person_outline;
  }
}