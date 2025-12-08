import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AllProductsModel.dart';

/// -------------------- WISHLIST SERVICE --------------------
class WishlistService {
  static final ValueNotifier<List<AllProductsModel>> wishlistItemsNotifier =
  ValueNotifier([]);

  static Future<void> loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistData = prefs.getString('wishlist') ?? '[]';
    final List<dynamic> jsonList = json.decode(wishlistData);
    wishlistItemsNotifier.value =
        jsonList.map((item) => AllProductsModel.fromJson(item)).toList();
  }

  static Future<void> saveWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final wishlistData = json.encode(
        wishlistItemsNotifier.value.map((item) => item.toJson()).toList());
    await prefs.setString('wishlist', wishlistData);
  }

  static Future<void> toggleWishlistItem(AllProductsModel product) async {
    final currentList =
    List<AllProductsModel>.from(wishlistItemsNotifier.value);

    // Wishlist uniqueness by product.id (as per your previous logic)
    final exists = currentList.any((item) => item.id == product.id);
    if (exists) {
      currentList.removeWhere((item) => item.id == product.id);
    } else {
      currentList.add(product);
    }

    wishlistItemsNotifier.value = currentList;
    await saveWishlist();
    wishlistItemsNotifier.notifyListeners();
  }

  static bool isProductWishlisted(AllProductsModel product) {
    return wishlistItemsNotifier.value.any((item) => item.id == product.id);
  }
}