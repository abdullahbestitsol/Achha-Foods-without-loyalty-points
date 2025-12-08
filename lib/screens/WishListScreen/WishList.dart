import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Wishlist<T> {
  static List<dynamic> _cartItems = [];

  // Getter for cart items
  static List<dynamic> get cartItems => _cartItems;

  // Load wishlist items from shared preferences
  static Future<void> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistData = prefs.getString('wishlist') ?? '[]';
    _cartItems = List.from(json.decode(wishlistData));
  }

  // Save wishlist items to shared preferences
  static Future<void> saveWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistData = json.encode(_cartItems);
    prefs.setString('wishlist', wishlistData);
  }

  // Add a product to the wishlist
  static void addToWishlist(dynamic product) {
    _cartItems.add(product);
    saveWishlist();  // Save the updated wishlist
  }

  // Remove a product from the wishlist
  static void removeFromWishlist(dynamic product) {
    _cartItems.remove(product);
    saveWishlist();  // Save the updated wishlist
  }
}
