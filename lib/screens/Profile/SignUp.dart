import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:achhafoods/screens/Profile/MainScreenProfile.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../Consts/CustomFloatingButton.dart';
import '../Consts/shopify_auth_service.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({super.key});

  @override
  State<MyAccount> createState() => _MyAccountState();
}

// https://achafoods.bestitsol.com/api/register

class _MyAccountState extends State<MyAccount> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String phoneNumber = '';
  String referralCode = ''; // Optional
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _registerCustomer() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (password != confirmPassword) {
      Fluttertoast.showToast(
        msg: "Passwords don't match",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ Check if referral code is valid (if provided)
      if (referralCode.trim().isNotEmpty) {
        final referralCheckUrl = Uri.parse("$localurl/api/check-referral-code");
        final referralCheckResponse = await http.post(
          referralCheckUrl,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"referral_code": referralCode.trim()}),
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
      }

      // 2️⃣ FIRST: Try Shopify registration (to check if email exists)
      final shopifyCustomer = await ShopifyAuthService.registerCustomer(
        firstName,
        lastName,
        email,
        password,
      );

      // CHECK SHOPIFY RESPONSE - If not successful, stop here
      if (shopifyCustomer == null) {
        // Shopify failed - email already exists in Shopify
        Fluttertoast.showToast(
          msg: "Email already registered in Shopify. Please use a different email or login.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => isLoading = false);
        return; // Don't proceed to Laravel
      }

      // 3️⃣ Only proceed to Laravel if Shopify registration was successful
      final laravelRegisterUrl = Uri.parse("$localurl/api/register");
      Map<String, dynamic> requestBody = {
        "name": "$firstName $lastName",
        "email": email,
        // "password": password,
        "phone": phoneNumber,
      };

      if (referralCode.trim().isNotEmpty) {
        requestBody["referred_by"] = referralCode.trim();
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
        // Both Shopify and Laravel successful
        Fluttertoast.showToast(
          msg: "Account created successfully 🎉",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else if (laravelResponse.statusCode == 422) {
        print('Laravel validation failed (422): ${laravelResponse.body}');

        String errorMessage = "Registration failed. Please check your details.";

        // Check if the detailed errors map exists
        if (laravelData["errors"] != null && laravelData["errors"] is Map) {
          if (laravelData["errors"]["email"] != null &&
              laravelData["errors"]["email"] is List &&
              laravelData["errors"]["email"].isNotEmpty) {
            errorMessage = laravelData["errors"]["email"].first;
          } else if (laravelData["errors"]["phone"] != null &&
              laravelData["errors"]["phone"] is List &&
              laravelData["errors"]["phone"].isNotEmpty) {
            errorMessage = laravelData["errors"]["phone"].first;
          } else {
            for (var key in laravelData["errors"].keys) {
              if (laravelData["errors"][key] is List &&
                  laravelData["errors"][key].isNotEmpty) {
                errorMessage = laravelData["errors"][key].first;
                break;
              }
            }
          }
        } else if (laravelData["message"] != null) {
          errorMessage = laravelData["message"];
        }

        // IMPORTANT: If Laravel fails but Shopify succeeded, we need to delete Shopify customer
        // Add a rollback API call to delete the Shopify user
        if (shopifyCustomer != null) {
          // Call your Shopify delete function here
          // await ShopifyAuthService.deleteCustomer(shopifyCustomerId);
          print("WARNING: Shopify user created but Laravel failed. Need rollback.");
        }

        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      } else {
        print('Laravel registration failed: ${laravelResponse.body}');

        // IMPORTANT: If Laravel fails but Shopify succeeded, we need to delete Shopify customer
        if (shopifyCustomer != null) {
          // Call your Shopify delete function here
          // await ShopifyAuthService.deleteCustomer(shopifyCustomerId);
          print("WARNING: Shopify user created but Laravel failed. Need rollback.");
        }

        Fluttertoast.showToast(
          msg: laravelData["message"] ?? "Laravel registration failed",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error during registration: $e');
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
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
                    bottom: BorderSide(color: Colors.grey[800]!, width: 1),
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
              _buildTextField(
                label: 'First Name',
                onChanged: (val) => firstName = val,
                validator: (val) =>
                (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Last Name',
                onChanged: (val) => lastName = val,
                validator: (val) =>
                (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                onChanged: (val) => email = val,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (!val.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildTextField(
                label: 'Phone Number',
                onChanged: (val) => phoneNumber = val,
                validator: (val) =>
                (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                label: 'Password',
                obscureText: _obscurePassword,
                onChanged: (val) => password = val,
                toggleVisibility: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 15),
              _buildPasswordField(
                label: 'Confirm Password',
                obscureText: _obscureConfirmPassword,
                onChanged: (val) => confirmPassword = val,
                toggleVisibility: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              // const SizedBox(height: 15),
              // _buildTextField(
              //   label: 'Referral Code (Optional)',
              //   onChanged: (val) => referralCode = val,
              // ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Already have an account? Sign in',
                  style:
                  TextStyle(color: CustomColorTheme.CustomPrimaryAppColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required Function(String) onChanged,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[800]), // Color changed here
        prefixIcon: const Icon(Icons.person_outline,
            color: CustomColorTheme.CustomPrimaryAppColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildPasswordField({
    required String label,
    required bool obscureText,
    required Function(String) onChanged,
    required VoidCallback toggleVisibility,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[800]), // Color changed here
        prefixIcon: const Icon(Icons.lock_outline,
            color: CustomColorTheme.CustomPrimaryAppColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[800],
          ),
          onPressed: toggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: CustomColorTheme.CustomPrimaryAppColor),
        ),
      ),
      obscureText: obscureText,
      validator: (value) => value == null || value.isEmpty
          ? 'Required'
          : value.length < 8
          ? 'Minimum 8 characters'
          : null,
      onChanged: onChanged,
    );
  }
}