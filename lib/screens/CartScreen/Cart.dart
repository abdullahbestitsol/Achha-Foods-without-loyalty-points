import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Cart<T> {
  // Use ValueNotifier for state management
  static ValueNotifier<List<dynamic>> cartItemsNotifier = ValueNotifier([]);

  // Getter for cart items
  static List<dynamic> get cartItems => cartItemsNotifier.value;

  // Load cart items from shared preferences
  static Future<void> loadCartItems() async {
    final prefs = await SharedPreferences.getInstance();

    // FIX 1: Safely retrieve the string. Use ?? '[]' to provide an empty JSON list
    // if 'cartItems' is null (e.g., first run). This prevents the null check error.
    String savedCartJson = prefs.getString('cartItems') ?? '[]';

    try {
      // FIX 2: Ensure the decoding and assignment is safe.
      List<dynamic> loadedItems = List.from(json.decode(savedCartJson));
      cartItemsNotifier.value = loadedItems;
    } catch (e) {
      // Handle potential decoding errors (e.g., if the saved data is corrupted)
      debugPrint('Error decoding cart data: $e');
      cartItemsNotifier.value = []; // Default to an empty list on error
    }
  }

  // Save cart items to shared preferences
  static Future<void> saveCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    String cartItemsJson = json.encode(cartItemsNotifier.value);
    await prefs.setString('cartItems', cartItemsJson);
  }

  // Add a product to the cart
  static void addToCart(dynamic product) {
    // Creating a new list ensures the ValueNotifier recognizes a change
    cartItemsNotifier.value = List.from(cartItemsNotifier.value)..add(product);
    saveCartItems(); // Save to shared preferences after adding
    // Note: ValueNotifier automatically notifies listeners when its .value is set
  }

  // Remove a product from the cart
  static void removeFromCart(dynamic product) {
    // Create a new list for the update
    List<dynamic> updatedCart = List.from(cartItemsNotifier.value)
      ..remove(product);

    // Update the cart items notifier
    cartItemsNotifier.value = updatedCart;

    // Save the updated cart items to SharedPreferences
    saveCartItems();

    debugPrint("Product deleted");
    // Assuming 'product' is a Map and has a 'name' key for printing
    if (product is Map<String, dynamic> && product.containsKey('name')) {
      debugPrint("Removing product: ${product['name']}");
    }
  }
}