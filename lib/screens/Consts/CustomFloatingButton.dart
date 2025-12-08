import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../services/DynamicContentCache.dart';

class CustomWhatsAppFAB extends StatefulWidget {
  const CustomWhatsAppFAB({super.key}); // Added const constructor

  @override
  State<CustomWhatsAppFAB> createState() => _WhatsAppFABState();
}

class _WhatsAppFABState extends State<CustomWhatsAppFAB> {
  // Utility method to convert color string (e.g., "#FF0000") to Color object
  Color _hexToColor(String hexString) {
    String hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Assume full opacity if none is specified
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      // Fallback to a default color if parsing fails
      debugPrint('Error parsing color: $hexString. Falling back to green.');
      return Colors.green.shade600;
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    // 1. Get the instance using Provider
    final dynamicCache = Provider.of<DynamicContentCache>(context, listen: false);

    final String? contactNumber = dynamicCache.getContactUsNumber();

    if (contactNumber == null || contactNumber.isEmpty) {
      // Use ScaffoldMessenger to show a helpful message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp number not available')),
      );
      return;
    }

    final whatsappUrl = Uri.parse('https://wa.me/$contactNumber');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2. Retrieve the cache and listen for changes here (if needed in build)
    // Using Provider.of for the color and listening to changes is efficient here.
    final dynamicCache = Provider.of<DynamicContentCache>(context);

    // 3. SAFELY get the color string (default to a known hex for safety)
    final String colorString = dynamicCache.getFloatingBackgoundColor() ?? '#25D366'; // WhatsApp Green fallback

    return FloatingActionButton(
      // 4. FIX: Use the utility function to convert the string to a Color object
      backgroundColor: _hexToColor(colorString),
      child:  Icon(Iconsax.whatsapp, color: Colors.white), // Using Bold variant as it's common for FABs
      onPressed: () => _openWhatsApp(context),
    );
  }
}