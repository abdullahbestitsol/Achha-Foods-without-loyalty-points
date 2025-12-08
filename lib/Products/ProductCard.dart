
import 'package:flutter/material.dart';
import '../services/AllProductsModel.dart';
import '../services/CartServices.dart';
import '../services/WishlistService.dart';
import 'ProductDetailsScreen.dart';

class ProductCard extends StatefulWidget {
  final AllProductsModel product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bool inStock = (widget.product.inventoryManagement == null ||
        widget.product.inventoryPolicy == 'continue' ||
        (widget.product.quantity) > 0);

    final bool purchasable = inStock && widget.product.isPurchasable;
    final bool isVariableProduct =
        widget.product.productType?.toLowerCase() == "variable";

    return ValueListenableBuilder(
      valueListenable: WishlistService.wishlistItemsNotifier,
      builder: (context, wishlistItems, _) {
        return ValueListenableBuilder(
          valueListenable: CartService.cartItemsNotifier,
          builder: (context, cartItems, _) {
            // final isWishlisted =
            // WishlistService.isProductWishlisted(widget.product);

            final isInCart = CartService.isProductInCart(widget.product);

            return MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailsScreen(product: widget.product),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.identity()
                    ..scale(_isHovering ? 1.02 : 1.0),
                  child: Card(
                    elevation: _isHovering ? 4 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Container(
                                  color: Colors.grey[100],
                                  child: Image.network(
                                    widget.product.image,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey[400],
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    // widget.product.brandName,
                                    'Achha Foods',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Rs. ${widget.product.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (widget.product.discountPercent > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius:
                                            BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${widget.product.discountPercent}% OFF',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // ❤️ Wishlist Button
                        // Positioned(
                        //   top: 8,
                        //   right: 8,
                        //   child: CircleAvatar(
                        //     radius: 18,
                        //     backgroundColor: Colors.white.withOpacity(0.9),
                        //     child: IconButton(
                        //       icon: Icon(
                        //         isWishlisted
                        //             ? Icons.favorite
                        //             : Icons.favorite_border,
                        //         color: isWishlisted
                        //             ? Colors.red[400]
                        //             : Colors.grey[600],
                        //         size: 18,
                        //       ),
                        //       onPressed: () {
                        //         WishlistService.toggleWishlistItem(
                        //             widget.product);
                        //       },
                        //     ),
                        //   ),
                        // ),
                        // 🛒 Cart Button (hide if variable OR not purchasable)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: (isVariableProduct || !purchasable)
                                ? const SizedBox
                                .shrink() // 🔹 Nothing will show
                                : CircleAvatar(
                              radius: 18,
                              backgroundColor: isInCart
                                  ? Colors.blue[50]
                                  : Colors.green[50],
                              child: IconButton(
                                icon: Icon(
                                  isInCart
                                      ? Icons.check
                                      : Icons.add_shopping_cart,
                                  color: isInCart
                                      ? Colors.blue[400]
                                      : Colors.green[600],
                                  size: 18,
                                ),
                                onPressed: () {
                                  CartService.toggleCartItem(
                                      widget.product);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isInCart
                                            ? 'Removed from cart'
                                            : 'Added to cart',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      backgroundColor: isInCart
                                          ? Colors.blue[400]
                                          : Colors.green[400],
                                      duration:
                                      const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
