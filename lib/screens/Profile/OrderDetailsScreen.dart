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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return isoDate; // Return original if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final billingAddress = order['billingAddress'] ?? {};
    final shippingAddress = order['shippingAddress'] ?? {};
    final lineItems = (order['lineItems']?['edges'] as List<dynamic>?)
            ?.map((edge) => edge['node'] as Map<String, dynamic>)
            .toList() ??
        [];

    // Extracting the first product image for display
    // String? firstProductImageUrl;
    // if (lineItems.isNotEmpty) {
    //   firstProductImageUrl = lineItems[0]['variant']?['image']?['url'] ??
    //       lineItems[0]['image']?['url'];
    // }

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
              'Order #${order['orderNumber'] ?? 'N/A'}',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CustomColorTheme.CustomPrimaryAppColor),
            ),
            // const SizedBox(height: 16),

            // Product Image (first item in order)
            // if (firstProductImageUrl != null && firstProductImageUrl.isNotEmpty)
            //   Center(
            //     child: ClipRRect(
            //       borderRadius: BorderRadius.circular(8.0),
            //       child: Image.network(
            //         firstProductImageUrl,
            //         width: 150,
            //         height: 150,
            //         fit: BoxFit.cover,
            //         errorBuilder: (context, error, stackTrace) =>
            //             Icon(Icons.image_not_supported, size: 150, color: Colors.grey),
            //       ),
            //     ),
            //   )
            // else
            //   Center(child: Icon(Icons.image, size: 150, color: Colors.grey)),
            const SizedBox(height: 20),

            // Basic Order Info
            _buildInfoRow(
                'Order Date:', _formatDate(order['processedAt'] ?? 'N/A')),
            // _buildInfoRow(
            //     'Status:',
            //     (order['fulfillmentStatus'] as String?)
            //             ?.replaceAll('_', ' ')
            //             .toLowerCase() ??
            //         'N/A'),
            _buildInfoRow('Total:',
                '${order['totalPrice']?['amount'] ?? '0.00'} ${order['totalPrice']?['currencyCode'] ?? ''}'),
            const SizedBox(height: 20),

            // Line Items (Products)
            const Text('Products:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            if (lineItems.isEmpty)
              const Text('No products found for this order.')
            else
              ...lineItems.map((item) {
                final itemTitle = item['title'] ?? 'N/A';
                final variantTitle = item['variant']?['title'] ?? '';
                final quantity = item['quantity'] ?? 1;
                final price = item['originalTotalPrice']?['amount'] ?? '0.00';
                final currency =
                    item['originalTotalPrice']?['currencyCode'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '$itemTitle ${variantTitle.isNotEmpty ? '($variantTitle)' : ''}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      Text('Quantity: $quantity',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700])),
                      Text('Price: $price $currency',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),

            // Billing Details Section
            const Text('Billing Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildAddressDetails(billingAddress),
            const SizedBox(height: 20),

            // Shipping Details Section
            const Text('Shipping Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildAddressDetails(shippingAddress),
            const SizedBox(height: 20),

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address['name'] != null)
          Text('Name: ${address['name']}',
              style: const TextStyle(fontSize: 16)),
        if (address['address1'] != null)
          Text('Address 1: ${address['address1']}',
              style: const TextStyle(fontSize: 16)),
        if (address['address2'] != null)
          Text('Address 2: ${address['address2']}',
              style: const TextStyle(fontSize: 16)),
        if (address['city'] != null)
          Text('City: ${address['city']}',
              style: const TextStyle(fontSize: 16)),
        if (address['province'] != null)
          Text('Province: ${address['province']}',
              style: const TextStyle(fontSize: 16)),
        if (address['zip'] != null)
          Text('Postal Code: ${address['zip']}',
              style: const TextStyle(fontSize: 16)),
        if (address['country'] != null)
          Text('Country: ${address['country']}',
              style: const TextStyle(fontSize: 16)),
        if (address['phone'] != null)
          Text('Phone: ${address['phone']}',
              style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
