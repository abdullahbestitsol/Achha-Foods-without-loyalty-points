import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../screens/CartScreen/CheckoutScreen.dart';
import '../screens/Consts/CustomFloatingButton.dart';
import '../screens/Consts/appBar.dart';
import '../screens/Drawer/Drawer.dart';
import '../screens/Navigation Bar/NavigationBar.dart';
import '../services/AllProductsModel.dart';
import '../services/CartServices.dart';
import '../services/ProductVariant.dart';

// --- CONSTANTS FOR SVG ICONS (UNCHANGED) ---
const String _facebookSvg = '''
<svg fill="none" height="120" viewBox="0 0 120 120" width="120" xmlns="http://www.w3.org/2000/svg"><path d="m81.3942 66.8069 2.8527-18.2698h-17.8237v-11.8507c0-5.0051 2.4876-9.8755 10.4751-9.8755h8.1017v-15.5765s-7.3485-1.2344-14.4004-1.2344c-14.6743 0-24.2822 8.7533-24.2822 24.5991v13.938h-16.3174v18.2698h16.3174v44.1931h20.083v-44.1931z" fill="#000"></path></svg>
''';

const String _twitterSvg = '''
<svg fill="none" height="120" viewBox="0 0 120 120" width="120" xmlns="http://www.w3.org/2000/svg"><path d="m110 28.6577c-3.762 1.5577-7.524 2.8038-11.9122 3.1154 4.3882-2.4923 7.5232-6.5423 9.0912-11.2154-4.076 2.1808-8.4643 4.05-13.1665 4.9846-3.4482-4.05-8.7774-6.5423-14.7335-6.5423-11.2853 0-20.6897 9.0346-20.6897 20.5615 0 1.5577.3135 3.1154.627 4.6731-16.9279-.9346-32.2884-9.0346-42.3197-21.4961-1.8809 3.1153-2.8214 6.5423-2.8214 10.2807 0 7.1654 3.7618 13.3962 9.0909 17.1346-3.4482 0-6.583-.9346-9.4043-2.4923v.3116c0 9.9692 7.21 18.0692 16.6144 19.9384-1.5674.3116-3.4483.6231-5.3292.6231-1.2539 0-2.5078 0-3.7617-.3115 2.5078 8.1 10.3448 14.0192 19.1222 14.3307-6.8965 5.6077-15.9874 8.7231-25.3918 8.7231-1.5674 0-3.1348 0-5.0157-.3115 9.0909 5.6077 20.0627 9.0346 31.6614 9.0346 37.9311 0 58.6206-31.1538 58.6206-58.2577 0-.9346 0-1.8692 0-2.4923 3.762-2.8038 7.21-6.5423 9.718-10.5923z" fill="#000"></path></svg>
''';

const String _pinterestSvg = '''
<svg fill="none" height="120" viewBox="0 0 120 120" width="120" xmlns="http://www.w3.org/2000/svg"><path d="m59.9889 10c-27.6161 0-49.9889 22.3828-49.9889 50.0111 0 21.2047 13.1749 39.2754 31.7707 46.5439-.4221-3.957-.8442-10.0247.1778-14.3367.9109-3.912 5.8653-24.85 5.8653-24.85s-1.4885-3.0007-1.4885-7.4239c0-6.9571 4.0213-12.1582 9.0424-12.1582 4.2657 0 6.3319 3.2007 6.3319 7.0238 0 4.2898-2.7327 10.7134-4.1546 16.6259-1.1997 4.9789 2.4883 9.0464 7.3983 9.0464 8.887 0 15.7077-9.3798 15.7077-22.8939 0-11.9583-8.6203-20.3379-20.8621-20.3379-14.219 0-22.5505 10.669-22.5505 21.7159 0 4.3121 1.6441 8.9131 3.7103 11.4026.3999.489.4665.9335.3332 1.4447-.3777 1.5782-1.2219 4.9789-1.3997 5.668-.2221.9335-.7109 1.1113-1.6662.689-6.2431-2.9117-10.1311-12.0471-10.1311-19.3599 0-15.7812 11.4419-30.2511 33.0149-30.2511 17.3294 0 30.8153 12.3583 30.8153 28.8731 0 17.226-10.8642 31.118-25.9275 31.118-5.0656 0-9.8201-2.645-11.4419-5.7568 0 0-2.5106 9.5354-3.1105 11.8915-1.133 4.3565-4.1768 9.7795-6.2208 13.0915 4.6878 1.445 9.6423 2.223 14.7967 2.223 27.5939 0 49.9889-22.3828 49.9889-50.0111-.022-27.6061-22.395-49.9889-50.0111-49.9889z" fill="#000"></path></svg>
''';
// ----------------------------------

class ProductDetailsScreen extends StatefulWidget {
  final AllProductsModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _isProcessingCart = false;
  bool _isProcessingBuyNow = false;
  int _quantity = 1;

  ProductVariant? selectedVariant;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      final firstAvailable = widget.product.variants.firstWhere(
              (v) => v.quantity > 0,
          orElse: () => widget.product.variants.first);
      selectedVariant = firstAvailable;
    } else {
      selectedVariant = ProductVariant(
        id: widget.product.variantId,
        title: 'Default',
        price: widget.product.price.toString(),
        quantity: widget.product.stockCheck ? 999 : 0,
        sku: widget.product.sku,
      );
    }
  }

  Future<void> _refreshScreen() async {
    setState(() {
      _quantity = 1;
    });
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  // 💡 MOVED: Define buildSelectedCartItem at the class level
  AllProductsModel buildSelectedCartItem() {
    final currentPrice =
        double.tryParse(selectedVariant?.price ?? '') ?? widget.product.price;
    final bool inStock = (widget.product.inventoryManagement == null ||
        widget.product.inventoryPolicy == 'continue' ||
        (selectedVariant?.quantity ?? 0) > 0);

    return AllProductsModel(
      id: widget.product.id,
      product_status: widget.product.product_status,
      productId: widget.product.productId,
      title: widget.product.title,
      description: widget.product.description,
      handle: widget.product.handle,
      variantId: selectedVariant?.id ?? widget.product.variantId,
      image: widget.product.image,
      price: currentPrice,
      stockCheck: inStock,
      quantity: _quantity,
      sku: selectedVariant?.sku ?? widget.product.sku,
      ldescription: widget.product.ldescription,
      category: widget.product.category,
      // brandName: widget.product.brandName ,
      brandName: 'Achha Foods' ,
      priceAfetDiscount: currentPrice,
      discountPercent: widget.product.discountPercent,
      variants: widget.product.variants,
      options: widget.product.options,
    );
  }
  // --------------------------------------------------------

  double get _totalAmount {
    final currentPrice = double.tryParse(selectedVariant?.price ?? '') ?? widget.product.price;
    return currentPrice * _quantity;
  }

  String get _productShareUrl {
    return 'https://achhaemart.com/products/${widget.product.handle}';
  }

  void _shareProductDetails(String platform) async {
    final String title = widget.product.title;
    final String url = _productShareUrl;
    final String text = 'Check out this amazing product: $title! Buy it here: $url';

    try {
      await Share.share(
        text,
        subject: 'Product Recommendation: $title',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing to $platform: $e')),
        );
      }
    }
  }

  Future<void> _navigateToCheckout(bool isBuyNow) async {
    if (isBuyNow) {
      // 1. For "Buy it now," first add the current product to the cart
      setState(() => _isProcessingBuyNow = true);
      final productToAdd = buildSelectedCartItem();
      try {
        await CartService.addProductToCartOrUpdateQuantity(productToAdd);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding product to cart: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isProcessingBuyNow = false);
        return;
      }
    } else {
      // Only set processing state if not handled by BuyNow
      setState(() => _isProcessingCart = true);
    }

    // 2. Get the full, updated cart list
    final cartItems = CartService.cartItemsNotifier.value;

    // 3. Calculate total amounts from the full cart
    double originalAmount = 0.0;
    double finalAmount = 0.0;
    for (var item in cartItems) {
      final itemPrice = item.priceAfetDiscount > 0 ? item.priceAfetDiscount : item.price;
      originalAmount += itemPrice * item.quantity;
      finalAmount += itemPrice * item.quantity;
    }

    // 4. Navigate to the CheckoutScreen with the full cart data
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            cartItems: cartItems,
            originalAmount: originalAmount,
            finalAmount: finalAmount,
            discountCode: null,
          ),
        ),
      );
    }

    // 5. Reset processing states
    if (mounted) {
      setState(() {
        _isProcessingBuyNow = false;
        _isProcessingCart = false;
      });
    }
  }


  // Helper methods for UI (UNCHANGED)
  Widget _buildIconText(IconData icon, String text) {
    // ... (implementation)
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageText(String image, String text) {
    // ... (implementation)
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 20,
              child: Image(image: AssetImage(image))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareIcon(IconData icon, String platform) {
    // ... (implementation)
    return GestureDetector(
      onTap: () => _shareProductDetails(platform),
      child: Icon(
        icon,
        color: Colors.black87,
        size: 30,
      ),
    );
  }

  Widget _buildFacebookShareSvgIcon(String platform) {
    // ... (implementation)
    return GestureDetector(
      onTap: () => _shareProductDetails(platform),
      child: SvgPicture.string(
        _facebookSvg,
        height: 30,
        width: 30,
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildTwitterShareSvgIcon(String platform) {
    // ... (implementation)
    return GestureDetector(
      onTap: () => _shareProductDetails(platform),
      child: SvgPicture.string(
        _twitterSvg,
        height: 30,
        width: 30,
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildPinterestShareSvgIcon(String platform) {
    // ... (implementation)
    return GestureDetector(
      onTap: () => _shareProductDetails(platform),
      child: SvgPicture.string(
        _pinterestSvg,
        height: 30,
        width: 30,
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentPrice =
        double.tryParse(selectedVariant?.price ?? '') ?? widget.product.price;

    final bool inStock = (widget.product.inventoryManagement == null ||
        widget.product.inventoryPolicy == 'continue' ||
        (selectedVariant?.quantity ?? 0) > 0);

    // Removed local buildSelectedCartItem() definition as it is now a class method

    return ValueListenableBuilder<List<AllProductsModel>>(
        valueListenable: CartService.cartItemsNotifier,
        builder: (context, cartItems, child) {

          final bool isCartNotEmpty = cartItems.isNotEmpty;

          return Scaffold(
            floatingActionButton: CustomWhatsAppFAB(),
            appBar: const CustomAppBar(),
            drawer: const CustomDrawer(),
            bottomNavigationBar: const NewNavigationBar(),
            body: RefreshIndicator(
              onRefresh: _refreshScreen,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... (UI remains largely the same)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Image.network(
                          widget.product.image,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[400],
                                size: 60,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.product.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Achha Foods',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Rs. ${currentPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.product.discountPercent > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.product.discountPercent}% OFF',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // -------- Variant Selection UI (UNCHANGED) --------
                    if (widget.product.variants.length > 1)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Variant',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<ProductVariant>(
                            initialValue: selectedVariant,
                            isExpanded: true,
                            items: widget.product.variants.map((variant) {
                              final price = double.tryParse(variant.price) ?? 0.0;
                              return DropdownMenuItem(
                                value: variant,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment
                                      .spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        variant.title.isEmpty
                                            ? 'Default'
                                            : variant.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Rs. ${price.toStringAsFixed(0)}'),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedVariant = val;
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 5),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Html(
                      data: widget.product.description
                          .replaceAll(RegExp(r':hover'), ''),
                      style: {
                        "body": Style(
                          fontSize: FontSize(14),
                          color: Colors.black87,
                          margin: Margins.zero,
                        ),
                      },
                      onCssParseError: (css, messages) {
                        return null;
                      },
                    ),


                    // -------- Quantity Selection (UNCHANGED) --------
                    Row(
                      children: [
                        Text(
                          'Quantity:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Decrement Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: _decrementQuantity,
                            icon: const Icon(Icons.remove),
                          ),
                        ),

                        // Quantity Display
                        Container(
                          width: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Text(
                            '$_quantity',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),

                        // Increment Button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: _incrementQuantity,
                            icon: const Icon(Icons.add),
                          ),
                        ),

                      ],
                    ),

                    const SizedBox(height: 32),

                    // -------- Buy Now Button (ACTION UNCHANGED) --------
                    if (inStock)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                          ),
                          onPressed: (!inStock || _isProcessingBuyNow)
                              ? null
                              : () => _navigateToCheckout(true),
                          child: _isProcessingBuyNow
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                              : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Buy it now',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rs. ${_totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // -------- Add to Cart Button (ACTION UNCHANGED) --------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: inStock
                              ? Colors.green[400]
                              : Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isProcessingCart
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.shopping_cart, color: Colors.white),
                        label: Text(
                          inStock
                              ? 'Add to Cart'
                              : 'Out of Stock',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: (!inStock || _isProcessingCart)
                            ? null
                            : () async {
                          setState(() => _isProcessingCart = true);
                          try {
                            await CartService.addProductToCartOrUpdateQuantity(
                                buildSelectedCartItem());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added $_quantity item(s) to cart',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.green[400],
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isProcessingCart = false);
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // -------- Proceed to Checkout button (ACTION UNCHANGED) --------
                    if (isCartNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[400],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _navigateToCheckout(false),
                          child: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),


                    // --- START: Static Sections (UNCHANGED) ---
                    const Text(
                      'Serving Since 1940',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Icons Row 1
                    Row(
                      children: [
                        _buildImageText('assets/serving_images/bestquality.png', 'Best Quality'),
                        const SizedBox(width: 20),
                        _buildImageText('assets/serving_images/safety.png', 'Food Safety'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Icons Row 2
                    Row(
                      children: [
                        _buildImageText('assets/serving_images/shield.png', 'Always Fresh'),
                        const SizedBox(width: 20),
                        _buildImageText('assets/serving_images/leaf.png', '100% Natural'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Share Icons
                    Row(
                      children: [
                        _buildFacebookShareSvgIcon('Facebook'),
                        const SizedBox(width: 15),
                        _buildTwitterShareSvgIcon('Twitter'),
                        const SizedBox(width: 15),
                        _buildPinterestShareSvgIcon('Pinterest'),
                        const SizedBox(width: 15),
                        _buildShareIcon(Iconsax.whatsapp, 'WhatsApp'),
                        // const SizedBox(width: 15),
                        // _buildShareIcon(Icons.email, 'Email/Other'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}

// CircleAvatar(
//   radius: 24,
//   backgroundColor: Colors.grey[100],
//   child: IconButton(
//     icon: _isProcessingWishlist
//         ? const SizedBox(
//             width: 16,
//             height: 16,
//             child: CircularProgressIndicator(strokeWidth: 2),
//           )
//         : Icon(
//             isWishlisted
//                 ? Icons.favorite
//                 : Icons.favorite_border,
//             color: isWishlisted
//                 ? Colors.red[400]
//                 : Colors.grey[600],
//           ),
//     onPressed: _isProcessingWishlist
//         ? null
//         : () async {
//             setState(() => _isProcessingWishlist = true);
//             try {
//               await WishlistService.toggleWishlistItem(
//                   widget.product);
//             } finally {
//               if (mounted) {
//                 setState(() => _isProcessingWishlist = false);
//               }
//             }
//           },
//   ),
// ),