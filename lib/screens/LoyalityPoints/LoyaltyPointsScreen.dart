import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 🚨 NEW
import '../Consts/CustomFloatingButton.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../../services/DynamicContentCache.dart'; // 🚨 NEW

class LoyaltyPointsScreen extends StatefulWidget {
  const LoyaltyPointsScreen({super.key});

  @override
  State<LoyaltyPointsScreen> createState() => _LoyaltyPointsScreenState();
}

class _LoyaltyPointsScreenState extends State<LoyaltyPointsScreen> {
  int? _loyaltyPoints;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userTier;
  String? _tierExpiryDate; // New state variable for the expiry date

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchLoyaltyPoints(),
        _fetchUserTier(),
      ]);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error fetching data: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserTier() async {
    String? userId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final laravelData = prefs.getString('laravelUser');

      if (laravelData != null) {
        final user = jsonDecode(laravelData);
        userId = user['id']?.toString();
      }

      if (userId == null) {
        print("User ID not found in SharedPreferences.");
        return;
      }

      final response = await http.get(
        Uri.parse("$localurl/api/users/$userId/tier"),
        headers: {
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final tierData = jsonDecode(response.body);

        setState(() {
          _userTier = tierData['tier'];

          final expiryString = tierData['expiry'];
          if (expiryString != null) {
            final dateTime = DateTime.parse(expiryString);

            // Format the date using DateFormat
            _tierExpiryDate = DateFormat('dd/MM/yyyy').format(dateTime);
          } else {
            _tierExpiryDate = "No order yet";
          }
        });
        print("User Tier: $_userTier");
        print("Tier Expiry: $_tierExpiryDate");
      } else {
        print("Failed to fetch user tier. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching user tier: $e");
    }
  }

  Future<void> _fetchLoyaltyPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final laravelToken = prefs.getString('laravelToken');
      final laravelUser = prefs.getString('laravelUser');
      print("Fetching loyalty points with token: $laravelToken");

      if (laravelToken == null || laravelUser == null) {
        return;
      }

      final response = await http.get(
        Uri.parse("$localurl/api/points/summary"),
        headers: {
          "Authorization": "Bearer $laravelToken",
          "Accept": "application/json",
        },
      );
      print('Url for loyalty points: $localurl/api/points/summary');
      print('Statue code: ${response.statusCode}');
      print('Statue body: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final points = body['total_points'];

        setState(() {
          _loyaltyPoints = points;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to fetch points. Status code: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 Access the dynamic content cache 🚨
    final cache = Provider.of<DynamicContentCache>(context);

    // Dynamic Text Fallbacks
    final title = cache.getLoyaltyPointsTitle() ?? "Loyalty Points";
    final subtitle = cache.getLoyaltyPointsSubtitle() ?? "Earn More, Save More";
    final bodyTitle = cache.getLoyaltyPointsBodyTitle() ?? "Your Current Points:";
    final bodySubtitle = cache.getLoyaltyPointsBodySubtitle() ?? "Earn points on every purchase and redeem them for exciting discounts!";


    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
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
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
                  : Column(
                children: [
                  Text(
                    bodyTitle, // 🚨 DYNAMIC BODY TITLE
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loyaltyPoints?.toString() ?? "0",
                    style: const TextStyle(
                      fontSize: 36,
                      color: CustomColorTheme.CustomPrimaryAppColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    bodySubtitle, // 🚨 DYNAMIC BODY SUBTITLE
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Your Current Tier: ${_userTier ?? "regular"}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 5 ),
                  Text(
                    "Your Tier & Points Expiry Date: ${_tierExpiryDate ?? "No order yet"}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
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