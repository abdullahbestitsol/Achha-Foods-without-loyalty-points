import 'package:flutter/material.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../Consts/CustomFloatingButton.dart';

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Safe Extraction of Address Data
    final shippingAddress = order['shippingAddress'] ?? {};
    // Note: Customer Account API line items don't always expose Billing Address directly on the order node
    // depending on the version, so we fallback to shipping if missing or empty.
    final billingAddress = order['billingAddress'] ?? shippingAddress;

    // 2. Updated Line Item Extraction Logic (Handling 'nodes' vs 'edges')
    List<Map<String, dynamic>> lineItems = [];

    if (order['lineItems'] != null) {
      if (order['lineItems']['nodes'] != null) {
        // Customer Account API format
        lineItems = List<Map<String, dynamic>>.from(order['lineItems']['nodes']);
      } else if (order['lineItems']['edges'] != null) {
        // Storefront API format (fallback)
        lineItems = (order['lineItems']['edges'] as List)
            .map((edge) => edge['node'] as Map<String, dynamic>)
            .toList();
      }
    }

    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      appBar: const CustomAppBar(),
      bottomNavigationBar: const NewNavigationBar(),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Text(
              'Order #${order['orderNumber'] ?? order['name'] ?? 'N/A'}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CustomColorTheme.CustomPrimaryAppColor),
            ),
            const SizedBox(height: 20),

            // Basic Order Info
            _buildInfoRow(
                'Order Date:', _formatDate(order['processedAt'] ?? 'N/A')),

            // // Financial Status (Paid/Pending)
            // if (order['financialStatus'] != null)
            //   _buildInfoRow('Payment:', order['financialStatus']),
            //
            // // Fulfillment Status
            // if (order['fulfillmentStatus'] != null)
            //   _buildInfoRow('Status:', order['fulfillmentStatus']),

            _buildInfoRow('Total:',
                '${order['totalPrice']?['amount'] ?? '0.00'} ${order['totalPrice']?['currencyCode'] ?? ''}'),

            const SizedBox(height: 20),

            // Line Items (Products)
            const Text('Products:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (lineItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No product details available.'),
              )
            else
              ...lineItems.map((item) {
                final itemTitle = item['title'] ?? 'Product';
                // Variant title logic differs slightly between APIs
                final variantTitle = item['variantTitle'] ?? item['variant']?['title'] ?? '';
                final quantity = item['quantity'] ?? 1;

                // Price logic
                final priceMap = item['originalTotalPrice'] ?? item['price']; // Handle structure variance
                final price = priceMap?['amount'] ?? '0.00';
                final currency = priceMap?['currencyCode'] ?? '';

                // Image logic
                String? imageUrl;
                if (item['image'] != null) {
                  imageUrl = item['image']['url'];
                } else if (item['variant']?['image'] != null) {
                  imageUrl = item['variant']['image']['url'];
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      if (imageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          width: 50, height: 50,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      const SizedBox(width: 10),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '$itemTitle ${variantTitle.isNotEmpty ? '($variantTitle)' : ''}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Qty: $quantity',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                Text('$price $currency',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),

            // Shipping Details Section
            const Text('Shipping Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildAddressDetails(shippingAddress),
            const SizedBox(height: 20),

            // Billing Details Section (Optional - only if different or present)
            if (billingAddress.isNotEmpty && billingAddress != shippingAddress) ...[
              const Text('Billing Details:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              _buildAddressDetails(billingAddress),
              const SizedBox(height: 20),
            ],

            // Back Button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12)),
                onPressed: () {
                  Navigator.pop(context); // Navigate back to the orders list
                },
                child: const Text('Back to Orders',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100, // Fixed width for labels
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressDetails(Map<String, dynamic> address) {
    if (address.isEmpty) {
      return const Text('Address information not available.',
          style: TextStyle(fontSize: 16, color: Colors.grey));
    }

    // Helper to add comma if needed
    String formatLine(String? part1, String? part2) {
      if (part1 != null && part1.isNotEmpty && part2 != null && part2.isNotEmpty) {
        return '$part1, $part2';
      }
      return part1 ?? part2 ?? '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address['name'] != null || address['firstName'] != null)
          Text(address['name'] ?? '${address['firstName']} ${address['lastName']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

        if (address['address1'] != null)
          Text(address['address1'], style: const TextStyle(fontSize: 16)),

        if (address['address2'] != null && address['address2'].toString().isNotEmpty)
          Text(address['address2'], style: const TextStyle(fontSize: 16)),

        Text(formatLine(address['city'], address['province']), style: const TextStyle(fontSize: 16)),

        Text(formatLine(address['country'], address['zip']), style: const TextStyle(fontSize: 16)),

        if (address['phone'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Phone: ${address['phone']}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
      ],
    );
  }
}