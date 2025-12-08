// import 'dart:convert';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:achhafoods/screens/Consts/CustomColorTheme.dart';
//
// import '../../services/AllProductsModel.dart';
// import '../../services/AllProductsService.dart';
// import '../CartScreen/Cart.dart';
// import '../Consts/const_keys.dart';
// import '../WishListScreen/WishList.dart';
//
// const double defaultPadding = 16.0;
// const double defaultBorderRadius = 12.0;
//
// // Model for WooCommerce product
// // class AllProducts {
// //   final int id;
// //   final String name;
// //   final String slug;
// //   final String permalink;
// //   final String dateCreated;
// //   final String dateModified;
// //   final String type;
// //   final String status;
// //   final bool featured;
// //   final String description;
// //   final String shortDescription;
// //   final String sku;
// //   final String price;
// //   final String regularPrice;
// //   final String salePrice;
// //   final bool onSale;
// //
// //   AllProducts({
// //     required this.id,
// //     required this.name,
// //     required this.slug,
// //     required this.permalink,
// //     required this.dateCreated,
// //     required this.dateModified,
// //     required this.type,
// //     required this.status,
// //     required this.featured,
// //     required this.description,
// //     required this.shortDescription,
// //     required this.sku,
// //     required this.price,
// //     required this.regularPrice,
// //     required this.salePrice,
// //     required this.onSale,
// //   });
// //
// //   factory AllProducts.fromJson(Map<String, dynamic> json) {
// //     return AllProducts(
// //       id: json['id'],
// //       name: json['name'],
// //       slug: json['slug'],
// //       permalink: json['permalink'],
// //       dateCreated: json['date_created'],
// //       dateModified: json['date_modified'],
// //       type: json['type'],
// //       status: json['status'],
// //       featured: json['featured'],
// //       description: json['description'],
// //       shortDescription: json['short_description'],
// //       sku: json['sku'],
// //       price: json['price'],
// //       regularPrice: json['regular_price'],
// //       salePrice: json['sale_price'],
// //       onSale: json['on_sale'],
// //     );
// //   }
// // }
// //
// // // Model for displaying product information
// // class AllProductsModel {
// //   final String image, brandName, title;
// //   final double price, originalPrice;
// //   final int productID;
// //   final double? priceAfetDiscount;
// //   final int? discountPercent;
// //   final bool StockCheck, isAvailable;
// //   final String description, ldescription, category;
// //   int quantity; // Added quantity field
// //
// //   AllProductsModel({
// //     required this.image,
// //     required this.productID,
// //     required this.category,
// //     required this.brandName,
// //     required this.title,
// //     required this.price,
// //     required this.originalPrice,
// //     required this.description,
// //     required this.ldescription,
// //     required this.isAvailable,
// //     required this.StockCheck,
// //     this.priceAfetDiscount,
// //     this.discountPercent,
// //     this.quantity = 1, // Default quantity is 1
// //   });
// // }
// //
// // // Service class to fetch all products from WooCommerce API
// // class AllProductsService {
// //   Future<List<AllProductsModel>> fetchProducts() async {
// //     final response = await http.get(Uri.parse(ApiConfig.getProductsUrl()));
// //
// //     if (response.statusCode == 200) {
// //       List<dynamic> jsonResponse = json.decode(response.body);
// //
// //       // Convert JSON products to AllProductsModel without filtering
// //       return jsonResponse.map<AllProductsModel>((product) {
// //         bool isInStock = product['stock_status'] == "instock";
// //
// //         return AllProductsModel(
// //           image:
// //               product['images'].isNotEmpty ? product['images'][0]['src'] : '',
// //           title: product['name'],
// //           category:
// //               product['categories'] != null && product['categories'].isNotEmpty
// //                   ? product['categories'][0]
// //                       ['name'] // Retrieves the name of the first category
// //                   : 'Uncategorized', // Fallback in case no category is present,
// //           productID: product['id'],
// //           brandName: product['sku'], // Assuming SKU is the brand name
// //           StockCheck: isInStock,
// //           originalPrice: double.tryParse(product['regular_price'] ?? '') ?? 0.0,
// //           isAvailable: isInStock,
// //           description: product['short_description'],
// //           ldescription: product['description'],
// //           price: double.tryParse(product['regular_price'] ?? '') ?? 0.0,
// //           priceAfetDiscount: double.tryParse(product['price'] ?? '') ?? 0.0,
// //           discountPercent: product['on_sale'] &&
// //                   product['sale_price'] != null &&
// //                   product['regular_price'] != null
// //               ? ((1 -
// //                           (double.tryParse(product['sale_price'] ?? '1')! /
// //                               double.tryParse(
// //                                   product['regular_price'] ?? '1')!)) *
// //                       100)
// //                   .round()
// //               : null,
// //         );
// //       }).toList();
// //     } else {
// //       throw Exception('Failed to load products');
// //     }
// //   }
// //
// //   void updateQuantity(AllProductsModel product, bool increase) {
// //     // Ensure quantity is initialized if it's null
// //     product.quantity ??= 1;
// //
// //     if (increase) {
// //       product.quantity++;
// //     } else {
// //       if (product.quantity > 1) {
// //         product.quantity--;
// //       }
// //     }
// //   }
// // }
//
// // HeatingPadSlider class that combines all components
// class AllProductsSlider extends StatefulWidget {
//   const AllProductsSlider({super.key});
//
//   @override
//   State<AllProductsSlider> createState() => _HeatingPadSliderState();
// }
//
// class _HeatingPadSliderState extends State<AllProductsSlider> {
//   int _selectedIndex = 0;
//   late PageController _pageController;
//   late Timer _timer;
//   late Future<List<AllProductsModel>> _offersFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(initialPage: 0);
//     _offersFuture = AllProductsService().fetchProducts(); // Fetch products
//
//     // Start the timer after the offers are fetched
//     _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
//       _offersFuture.then((offers) {
//         if (offers.isNotEmpty) {
//           setState(() {
//             if (_selectedIndex < offers.length - 1) {
//               _selectedIndex++;
//             } else {
//               _selectedIndex = 0;
//             }
//           });
//
//           _pageController.animateToPage(
//             _selectedIndex,
//             duration: const Duration(milliseconds: 350),
//             curve: Curves.easeOutCubic,
//           );
//         }
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     _timer.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AspectRatio(
//       aspectRatio: 1.87,
//       child: FutureBuilder<List<AllProductsModel>>(
//         future: _offersFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(
//                 child: CircularProgressIndicator()); // Loading indicator
//           } else if (snapshot.hasError) {
//             return Center(
//                 child: Text('Error: ${snapshot.error}')); // Error handling
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return const Center(
//                 child: Text('No offers available.')); // No data handling
//           }
//
//           List<AllProductsModel> offers =
//               snapshot.data!; // Use the fetched offers
//
//           return Stack(
//             alignment: Alignment.bottomRight,
//             children: [
//               PageView.builder(
//                 controller: _pageController,
//                 itemCount: offers.length,
//                 onPageChanged: (int index) {
//                   setState(() {
//                     _selectedIndex = index;
//                   });
//                 },
//                 itemBuilder: (context, index) {
//                   return GestureDetector(
//                       // onTap: ()=>Navigator.push(context,MaterialPageRoute(builder: (context)=>AllProductsDetailsScreen(product: offers[index]))),
//                       child: buildOfferWidget(offers[index]));
//                 },
//               ),
//               FittedBox(
//                 child: Padding(
//                   padding: const EdgeInsets.all(defaultPadding),
//                   child: SizedBox(
//                     height: 16,
//                     child: Row(
//                       children: List.generate(
//                         offers.length,
//                         (index) {
//                           return Padding(
//                             padding:
//                                 const EdgeInsets.only(left: defaultPadding / 4),
//                             child: DotIndicator(
//                               isActive: index == _selectedIndex,
//                               activeColor: Colors.white70,
//                               inActiveColor: Colors.white54,
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//   // bool isWishlisted = false; // Track if the product is wishlisted
//
//   void _toggleWishlist(AllProductsModel offer) {
//     bool isWishlisted = Wishlist.cartItems.any((item) =>
//         item['id'] == offer.productID); // Check wishlist status dynamically
//     setState(() {
//       if (isWishlisted) {
//         var product = Wishlist.cartItems.firstWhere(
//           (item) => item['id'] == offer.productID,
//           orElse: () => null,
//         );
//         if (product != null) {
//           Wishlist.removeFromWishlist(product); // Remove product from wishlist
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('${offer.title} removed from wishlist')),
//           );
//         }
//       } else {
//         var product = {
//           'id': offer.productID, // Include productId
//           'name': offer.title,
//           'priceAfetDiscount': offer.priceAfetDiscount ?? 0.0,
//           'quantity': 1,
//           'totalPrice': offer.priceAfetDiscount ?? 0.0,
//           'images': offer.image,
//           'categories': offer.category,
//           'originalPrice': offer.originalPrice,
//           'StockStatus': offer.StockCheck,
//           'longDesc': offer.ldescription,
//           'shortDesc': offer.description
//         };
//         Wishlist.addToWishlist(product); // Add product to wishlist
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('${offer.title} added to wishlist')),
//         );
//       }
//     });
//   }
//
//   Widget buildOfferWidget(AllProductsModel offer) {
//     bool isWishlisted =
//         Wishlist.cartItems.any((item) => item['id'] == offer.productID);
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: CustomColorTheme
//             .CustomBlueColor, // Sample color, replace with your design
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Image on the left side
//           Flexible(
//             flex: 1,
//             child: Image.network(
//               offer.image,
//               fit:
//                   BoxFit.cover, // Ensures the image covers the entire container
//               height: double.infinity, // Make image take full height
//               width: double.infinity, // Make image take full width
//             ),
//           ),
//           const SizedBox(width: 8), // Space between image and text
//           // Text data on the right side
//           Expanded(
//             flex: 1, // You can adjust flex to fit your content
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   offer.title,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 // const SizedBox(height: 5),
//                 Stack(
//                   children: [
//                     Text(
//                       'Rs ${offer.price.toStringAsFixed(2)}',
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 10,
//                       ),
//                     ),
//                     Positioned(
//                       bottom: 8,
//                       right: 0,
//                       child: Container(
//                         width: 100, // Adjust width as needed
//                         height: 2, // Set height for the strikethrough effect
//                         color: Colors.black54, // Color for strikethrough line
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (offer.priceAfetDiscount != null) ...[
//                   // const SizedBox(height: 5),
//                   Row(
//                     children: [
//                       const Text(
//                         'After Discount: ',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         'Rs ${offer.priceAfetDiscount!.toStringAsFixed(2)}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(
//                     height: 5,
//                   ),
//                   SizedBox(
//                     height: 40,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         // IconButton(
//                         //   icon: Icon(
//                         //     isWishlisted
//                         //         ? Icons.favorite
//                         //         : Icons.favorite_border,
//                         //     color: isWishlisted ? Colors.red : Colors.white,
//                         //   ),
//                         //   onPressed: () => _toggleWishlist(
//                         //       offer), // Toggle wishlist on heart icon press
//                         // ),
//                         IconButton(
//                           onPressed: () {
//                             var product = {
//                               'id': offer.productID, // Include productId
//                               'name': offer.title,
//                               'priceAfetDiscount':
//                                   offer.priceAfetDiscount ?? 0.0,
//                               'quantity': 1,
//                               'totalPrice': offer.priceAfetDiscount ?? 0.0,
//                               'images': offer.image,
//                               'categories': offer.category,
//                               // 'originalPrice': offer.originalPrice,
//                               // 'StockStatus': offer.StockCheck,
//                               'longDesc': offer.ldescription,
//                               'shortDesc': offer.description
//                             };
//                             print(product);
//                             // Image(image: NetworkImage(offer.image))
//                             Cart.addToCart(product); // Add product to cart
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                   content:
//                                       Text('${offer.title} added to cart')),
//                             );
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: CustomColorTheme.CustomBlueColor,
//                           ),
//                           icon: const Icon(Icons.shopping_cart,
//                               color: Colors.white),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//                 const SizedBox(height: 10),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// const Duration defaultDuration = Duration(milliseconds: 300);
//
// // DotIndicator widget for the carousel
// class DotIndicator extends StatelessWidget {
//   const DotIndicator({
//     super.key,
//     this.isActive = false,
//     this.inActiveColor,
//     this.activeColor = Colors.red,
//   });
//
//   final bool isActive;
//   final Color? inActiveColor, activeColor;
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedContainer(
//       duration: defaultDuration,
//       height: isActive ? 12 : 4,
//       width: 4,
//       decoration: BoxDecoration(
//         color: isActive
//             ? activeColor
//             : inActiveColor ?? CustomColorTheme.primaryColor,
//         borderRadius: const BorderRadius.all(Radius.circular(defaultPadding)),
//       ),
//     );
//   }
// }
