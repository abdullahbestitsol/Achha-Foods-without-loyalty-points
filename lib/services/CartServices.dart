import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AllProductsModel.dart'; // Ensure this path is correct

/// -------------------- CART SERVICE --------------------
class CartService {
  static final ValueNotifier<List<AllProductsModel>> cartItemsNotifier =
  ValueNotifier([]);

  // 💡 NEW LOGIC: Always adds the new quantity to the existing item or adds a new item.
  static Future<void> addProductToCartOrUpdateQuantity(AllProductsModel product) async {
    final currentList = List<AllProductsModel>.from(cartItemsNotifier.value);

    // 1. Find the index of the existing item by variantId
    final index = currentList.indexWhere((item) => item.variantId == product.variantId);

    if (index != -1) {
      // 2. Item exists: Calculate the new total quantity
      final existingProduct = currentList[index];
      final newTotalQuantity = existingProduct.quantity + product.quantity;

      // 3. Create an updated product model
      final updatedProduct = AllProductsModel(
        id: existingProduct.id,
        product_status: existingProduct.product_status,
        title: existingProduct.title,
        description: existingProduct.description,
        handle: existingProduct.handle,
        variantId: existingProduct.variantId,
        image: existingProduct.image,
        price: existingProduct.price,
        productId: existingProduct.productId,
        stockCheck: existingProduct.stockCheck,
        quantity: newTotalQuantity, // Set the aggregated quantity
        sku: existingProduct.sku,
        ldescription: existingProduct.ldescription,
        category: existingProduct.category,
        brandName: 'Achha Foods',
        // brandName: existingProduct.brandName,
        priceAfetDiscount: existingProduct.priceAfetDiscount,
        discountPercent: existingProduct.discountPercent,
        variants: existingProduct.variants,
        options: existingProduct.options,
      );

      // 4. Replace the old product with the updated one
      currentList[index] = updatedProduct;

    } else {
      // 5. Item does not exist: Add the new product (with the quantity from the details screen)
      currentList.add(product);
    }

    cartItemsNotifier.value = currentList;
    await saveCart();
    cartItemsNotifier.notifyListeners();
  }

  // --------------------------------------------------------------------------------------
  // NOTE: The original `toggleCartItem` is kept below, but if you only use
  // `addProductToCartOrUpdateQuantity` from the details screen, you've solved your issue.
  // I recommend renaming the original `toggleCartItem` to `removeCartItem`
  // if its only function is to remove.
  // --------------------------------------------------------------------------------------

  static void updateQuantity(AllProductsModel product, int newQuantity) {
    // Update by variantId to allow multiple variants of same product in cart
    final index = cartItemsNotifier.value
        .indexWhere((p) => p.variantId == product.variantId);
    if (index != -1) {
      final p = cartItemsNotifier.value[index];
      final updatedProduct = AllProductsModel(
        id: p.id,
        product_status: p.product_status,
        title: p.title,
        description: p.description,
        handle: p.handle,
        variantId: p.variantId,
        image: p.image,
        price: p.price,
        productId: p.productId,
        stockCheck: p.stockCheck,
        quantity: newQuantity,
        sku: p.sku,
        ldescription: p.ldescription,
        category: p.category,
        // brandName: p.brandName,
        brandName: 'Achha Foods',
        priceAfetDiscount: p.priceAfetDiscount,
        discountPercent: p.discountPercent,
        variants: p.variants,
        options: p.options,
      );

      final newList = List<AllProductsModel>.from(cartItemsNotifier.value);
      newList[index] = updatedProduct;
      cartItemsNotifier.value = newList;
      saveCart();
    }
  }

  static void clearCart() {
    cartItemsNotifier.value = [];
    saveCart();
  }

  static Future<void> loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = prefs.getString('cart') ?? '[]';
    final List<dynamic> jsonList = json.decode(cartData);
    cartItemsNotifier.value =
        jsonList.map((item) => AllProductsModel.fromJson(item)).toList();
  }

  static Future<void> saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = json
        .encode(cartItemsNotifier.value.map((item) => item.toJson()).toList());
    await prefs.setString('cart', cartData);
  }

  // NOTE: This function still has the "remove" logic, which is why your previous
  // screen logic was toggling/removing. Use `addProductToCartOrUpdateQuantity` instead.
  static Future<void> toggleCartItem(AllProductsModel product) async {
    final currentList = List<AllProductsModel>.from(cartItemsNotifier.value);

    final exists =
    currentList.any((item) => item.variantId == product.variantId);
    if (exists) {
      currentList.removeWhere((item) => item.variantId == product.variantId);
    } else {
      currentList.add(product);
    }

    cartItemsNotifier.value = currentList;
    await saveCart();
    cartItemsNotifier.notifyListeners();
  }

  static bool isProductInCart(AllProductsModel product) {
    return cartItemsNotifier.value
        .any((item) => item.variantId == product.variantId);
  }
}