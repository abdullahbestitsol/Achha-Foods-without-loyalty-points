import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../Consts/CustomFloatingButton.dart';
import '../../Products/ProductDetailsScreen.dart';
import '../../services/AllProductsModel.dart';
import '../../services/CartServices.dart';
import '../../services/WishlistService.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // No need to manually load as ValueNotifier will handle updates
  }

  Future<void> _showDeleteConfirmationDialog(AllProductsModel product) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.redAccent),
              SizedBox(width: 8.0),
              Text(
                "Confirm Removal",
                style: TextStyle(
                  color: CustomColorTheme.CustomPrimaryAppColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to remove ${product.title} from your wishlist?",
            style: const TextStyle(color: Colors.black87),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: CustomColorTheme.CustomPrimaryAppColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                WishlistService.toggleWishlistItem(product);
                Fluttertoast.showToast(
                  msg: "${product.title} removed from wishlist",
                  backgroundColor: CustomColorTheme.CustomPrimaryAppColor,
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                "Confirm",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      body: ValueListenableBuilder<List<AllProductsModel>>(
        valueListenable: WishlistService.wishlistItemsNotifier,
        builder: (context, wishlistItems, _) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CustomColorTheme.CustomPrimaryAppColor,
                  child: const Center(
                    child: Text(
                      "Wishlist",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                wishlistItems.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Text(
                            "Your wishlist is empty",
                            style: TextStyle(
                              color: CustomColorTheme.CustomPrimaryAppColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: wishlistItems.length,
                          itemBuilder: (context, index) {
                            final product = wishlistItems[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              padding: const EdgeInsets.all(1.0),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey, width: 1.0),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8.0,
                                                  vertical: 4.0),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ProductDetailsScreen(
                                                        product: product),
                                              ),
                                            );
                                          },
                                          title: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 60,
                                                height: 60,
                                                child: product.image.isNotEmpty
                                                    ? Image.network(
                                                        product.image,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                                error,
                                                                stackTrace) =>
                                                            const Icon(Icons
                                                                .image_not_supported),
                                                      )
                                                    : const Icon(Icons
                                                        .image_not_supported),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product.title,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      "Price: \$${product.price.toStringAsFixed(2)}",
                                                      style: const TextStyle(
                                                          fontSize: 13),
                                                    ),
                                                    if (!product.stockCheck)
                                                      const Text(
                                                        "Out of Stock",
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: product.stockCheck
                                            ? () {
                                                CartService.toggleCartItem(
                                                    product);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        '${product.title} added to cart'),
                                                  ),
                                                );
                                              }
                                            : null,
                                        icon: const Icon(Icons.shopping_cart,
                                            color: Colors.white),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              CustomColorTheme.CustomPrimaryAppColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      IconButton(
                                        onPressed: () =>
                                            _showDeleteConfirmationDialog(
                                                product),
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
