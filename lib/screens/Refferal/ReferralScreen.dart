// File: ReferralScreen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🚨 NEW
import '../Consts/CustomFloatingButton.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../../services/DynamicContentCache.dart'; // 🚨 NEW

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? referralCode;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Fetch the Laravel user data
    final laravelUserString = prefs.getString('laravelUser');

    if (laravelUserString != null && laravelUserString.trim().isNotEmpty) {
      try {
        final Map<String, dynamic> laravelUser = jsonDecode(laravelUserString);

        // 2. Access the dynamic referral_code directly from the user data
        final code = laravelUser['referral_code']?.toString();

        if (code != null && code.isNotEmpty) {
          setState(() {
            referralCode = code;
            isLoading = false;
          });
        } else {
          // Fallback if the code is not found for some reason
          setState(() {
            referralCode = "Code not available";
            isLoading = false;
          });
          print("Referral code not found in Laravel user data.");
        }
      } catch (e) {
        print("Error decoding Laravel user data: $e");
        setState(() {
          isLoading = false;
        });
      }
    } else {
      print("Laravel user data not found in SharedPreferences");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _shareReferralCode() {
    if (referralCode != null) {
      // Use dynamic subtitle for sharing message
      final cache = Provider.of<DynamicContentCache>(context, listen: false);
      final shareText = cache.getReferAFriendBodySubtitle() ?? "Share your referral code $referralCode with friends and earn rewards!";

      Share.share(
        shareText.replaceAll('[CODE]', referralCode!).replaceAll('[code]', referralCode!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 Access the dynamic content cache 🚨
    final cache = Provider.of<DynamicContentCache>(context);

    // Dynamic Text Fallbacks
    final title = cache.getReferAFriendTitle() ?? "Refer a Friend";
    final subtitle = cache.getReferAFriendSubtitle() ?? "Invite and earn rewards";
    final bodyTitle = cache.getReferAFriendBodyTitle() ?? "Your Referral Code:";
    final bodySubtitle = cache.getReferAFriendBodySubtitle() ?? "Share your referral code with friends and earn rewards when they make their first purchase!";


    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : referralCode == null
          ? const Center(
        child: Text(
          "Please log in to see your referral code",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          // Header (using dynamic titles)
          Container(
            width: double.infinity,
            height: 80,
            color: Colors.black, // Consider making this color dynamic too
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title, // 🚨 DYNAMIC TITLE
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  Text(
                    subtitle, // 🚨 DYNAMIC SUBTITLE
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Main Content (using dynamic body text)
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    bodySubtitle, // 🚨 DYNAMIC BODY SUBTITLE
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    bodyTitle, // 🚨 DYNAMIC BODY TITLE
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    referralCode!,
                    style: const TextStyle(
                      fontSize: 24,
                      color: CustomColorTheme.CustomPrimaryAppColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _shareReferralCode,
                    icon: const Icon(Icons.share),
                    label: const Text("Share Code"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      CustomColorTheme.CustomPrimaryAppColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}