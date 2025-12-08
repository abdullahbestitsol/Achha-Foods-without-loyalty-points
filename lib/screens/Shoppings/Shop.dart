import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart'; // 🚨 NEW: Import Shimmer
import 'package:provider/provider.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import '../../Products/ProductCard.dart';
import '../Consts/CustomFloatingButton.dart';
import '../../services/CartServices.dart';
import '../../services/DynamicContentCache.dart';
import '../../services/WishlistService.dart';
import '../../services/HomeDataCacheService.dart';
import '../Collections/CollectionWidget.dart'; // Assumed to exist
import '../Consts/appBar.dart';
// Assuming you use this for icons

class Shop extends StatefulWidget {
  const Shop({super.key});

  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  final HomeDataCacheService _cacheService = HomeDataCacheService();

  String _searchQuery = "";
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _cacheService.loadAllData();

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  Future<void> _initializeServices() async {
    // These services need to be loaded once at startup
    await WishlistService.loadWishlist();
    await CartService.loadCart();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // NOTE: The original _buildCategoryList was redundant as you use CollectionWidget.
  // We'll focus on how to display shimmer for categories within the build method.

  @override
  Widget build(BuildContext context) {
    final dynamicCache = Provider.of<DynamicContentCache>(context);

    return Scaffold(
      // floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      drawer: const CustomDrawer(),
      appBar: const CustomAppBar(),
      backgroundColor: Colors.grey[50],

      body: ListenableBuilder(
        listenable: _cacheService,
        builder: (context, child) {
          final allProducts = _cacheService.allProducts;
          final allCategories = _cacheService.allCategories;
          final isProductsLoading = _cacheService.isProductsLoading;
          final productsError = _cacheService.productsError;
          final isCategoriesLoading = _cacheService.isCategoriesLoading;
          final categoriesError = _cacheService.categoriesError;

          final filteredProducts = allProducts
              .where((p) => p.title.toLowerCase().contains(_searchQuery))
              .toList();

          return RefreshIndicator(
            onRefresh: _cacheService.refreshAllData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 🔹 Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 24, 12),
                    child: ListenableBuilder(
                      listenable: dynamicCache,
                      builder: (context, _) {
                        final shopTitle = dynamicCache.getShopTitle();

                        if (shopTitle != null && shopTitle.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              shopTitle,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),

                // 🔍 Search Bar (Sticky)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickySearchBarDelegate(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                        decoration: InputDecoration(
                          hintText: "Search products...",
                          prefixIcon:
                          const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.grey.shade400, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 🔹 Popular Categories
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListenableBuilder(
                        listenable: dynamicCache,
                        builder: (context, _) {
                          final categoryTitle =
                          dynamicCache.getShopPopularCategories();

                          if (categoryTitle != null && categoryTitle.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                categoryTitle,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: isCategoriesLoading
                            ? const CategoryShimmerLoader() // 🚨 SHIMMER FOR CATEGORIES
                            : CollectionWidget(
                          categories: allCategories,
                          isLoading: isCategoriesLoading,
                          error: categoriesError,
                        ),
                      )
                    ],
                  ),
                ),

                // 🔹 Products Grid
                isProductsLoading
                    ? const SliverToBoxAdapter(
                  child: ProductGridShimmerLoader(), // 🚨 SHIMMER FOR PRODUCTS
                )
                    : productsError != null
                    ? SliverFillRemaining(
                  child: Center(child: Text("Error: $productsError")),
                )
                    : filteredProducts.isEmpty
                    ? const SliverFillRemaining(
                  child: Center(child: Text("No products found")),
                )
                    : SliverPadding(
                  padding:
                  const EdgeInsets.only(left: 16, right: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final product = filteredProducts[index];
                        return ProductCard(
                          key: ValueKey(product.id),
                          product: product,
                        );
                      },
                      childCount: filteredProducts.length,
                    ),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.65,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // Back to top button (uncommented for completeness)
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
        backgroundColor: Colors.red[400],
        child: const Icon(Icons.arrow_upward, color: Colors.white),
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        },
      )
          : CustomWhatsAppFAB(),
    );
  }
}

/// Sticky Search Bar Delegate
class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickySearchBarDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50],
      child: child,
    );
  }

  @override
  double get maxExtent => 70;
  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    // Changed to true so the hint text (if dynamic) can update after loading
    return true;
  }
}

// ====================================================================
// 🌟 NEW SHIMMER LOADER WIDGETS 🌟
// ====================================================================

// --- 1. Shimmer for the Horizontal Category List ---
class CategoryShimmerLoader extends StatelessWidget {
  const CategoryShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 6, // Show a few placeholders
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 68,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- 2. Shimmer for the Product Grid ---
class ProductGridShimmerLoader extends StatelessWidget {
  const ProductGridShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling issues
          itemCount: 6, // Show a few placeholder products
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, index) => const _ShimmerGridItem(),
        ),
      ),
    );
  }
}

// --- Reusable Grid Item Placeholder ---
class _ShimmerGridItem extends StatelessWidget {
  const _ShimmerGridItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Placeholder (main visual area)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Title Line 1
        Container(
          width: double.infinity,
          height: 14,
          color: Colors.white,
        ),
        const SizedBox(height: 6),
        // Title Line 2 (shorter)
        Container(
          width: 80,
          height: 14,
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        // Price Line
        Container(
          width: 60,
          height: 18,
          color: Colors.white,
        ),
      ],
    );
  }
}