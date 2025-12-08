import 'dart:convert';
import '../Consts/CustomFloatingButton.dart';
import 'package:flutter/material.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Consts/shopify_auth_service.dart';
import 'OrderDetailsScreen.dart';
import 'package:shimmer/shimmer.dart'; // 🚨 NEW IMPORT FOR SHIMMER

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print("Fetching orders...");
      final prefs = await SharedPreferences.getInstance();

      // Get full customerData JSON string
      final customerDataRaw = prefs.getString('customerData');

      String? accessToken;

      if (customerDataRaw != null) {
        final customerData = jsonDecode(customerDataRaw);
        accessToken = customerData['accessToken'];
        print("Access Token: $accessToken");
      } else {
        print("No customer data found in SharedPreferences.");
      }

      if (accessToken == null || accessToken.isEmpty) {
        setState(() {
          _errorMessage = "Please log in to view your orders.";
          _isLoading = false;
        });
        return;
      }

      final fetchedOrders =
      await ShopifyAuthService.getCustomerOrdersStorefront(accessToken);

      setState(() {
        _orders = fetchedOrders;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching orders: $e");
      setState(() {
        _errorMessage = "Failed to load orders: $e";
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return isoDate; // Return original if parsing fails
    }
  }

  // 🚨 SHIMMER LOADER IMPLEMENTATION
  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 5, // Show 5 placeholder items
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Number Placeholder
                  Container(
                    width: 150,
                    height: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  // Date Placeholder
                  Container(
                    width: 100,
                    height: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  // Total Price Placeholder
                  Container(
                    width: 120,
                    height: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 16,
                      height: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      appBar: const CustomAppBar(),
      bottomNavigationBar: const NewNavigationBar(),
      drawer: const CustomDrawer(),
      body: _isLoading // 🚨 USE SHIMMER LOADER HERE
          ? _buildShimmerLoader()
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style:
                const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      )
          : _orders.isEmpty
          ? Center(
        child: Text(
          'You have no orders yet.',
          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final orderNumber = order['orderNumber'] ?? 'N/A';
          final processedAt = order['processedAt'] ?? '';
          final totalPrice =
              order['totalPrice']?['amount'] ?? '0.00';
          final currencyCode =
              order['totalPrice']?['currencyCode'] ?? '';
          // final fulfillmentStatus =
          //     order['fulfillmentStatus'] ?? 'UNKNOWN'; // unused

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OrderDetailsScreen(order: order),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CustomColorTheme.CustomPrimaryAppColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Date: ${_formatDate(processedAt)}',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Total: $totalPrice $currencyCode',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}