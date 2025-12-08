import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart'; // Import the Shimmer package
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import '../../Products/ProductCard.dart';
import '../../services/AllProductsModel.dart';
import '../../services/AllProductsService.dart';
import '../Consts/appBar.dart';
import '../Consts/CustomFloatingButton.dart';

// --- NEW DATA STRUCTURE FOR THE FUTURE ---
typedef CollectionProductsResult = Map<String, dynamic>;

class CategoryProduct extends StatefulWidget {
  final String categoryName;
  final String categoryHandle;
  final String imagePath;
  final String collectionId; // Collection ID for filtering
  final String productTypeFilter; // Not used here, but kept for compatibility

  const CategoryProduct({
    super.key,
    required this.categoryName,
    required this.imagePath,
    this.categoryHandle = '',
    required this.collectionId,
    this.productTypeFilter = '',
  });

  @override
  State<CategoryProduct> createState() => _CategoryProductState();
}

class _CategoryProductState extends State<CategoryProduct> {
  final AllProductsService _service = AllProductsService();

  late Future<CollectionProductsResult> _productsFuture;

  String _searchQuery = "";
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: CategoryProduct widget ID: ${widget.collectionId}');

    _productsFuture = _service.fetchProductsByCollectionId(widget.collectionId);

    // Scroll listener for Back to Top button
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 300 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: CustomWhatsAppFAB(),
      bottomNavigationBar: const NewNavigationBar(),
      drawer: const CustomDrawer(),
      appBar: const CustomAppBar(),
      backgroundColor: Colors.grey[50],

      body: FutureBuilder<CollectionProductsResult>(
        future: _productsFuture,
        builder: (context, snapshot) {
          // 🛑 SHIMMER LOADER INTEGRATION 🛑
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Display shimmer effect while loading
            return const ProductShimmerLoader();
          }
          // 🛑 END SHIMMER INTEGRATION 🛑

          if (snapshot.hasError) {
            return Center(
                child: Text('Error loading products: ${snapshot.error}'));
          }

          final resultData = snapshot.data;
          final List<AllProductsModel> allProducts =
              (resultData?['products'] as List<dynamic>?)
                  ?.cast<AllProductsModel>() ??
                  [];

          final String fetchedCollectionName =
              resultData?['collectionName'] as String? ?? widget.categoryName;

          // Apply search filter
          final filteredProducts = allProducts
              .where((p) =>
              p.title.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 🔹 Title: Use the fetched collection name
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Text(
                    fetchedCollectionName, // USE THE NEWLY FETCHED NAME
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),

              // 🔍 Search Bar (Sticky) - Uncommented for completeness
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickySearchBarDelegate(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      decoration: InputDecoration(
                        // Use the fetched name in the hint
                        hintText: "Search products in $fetchedCollectionName...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                          borderSide:
                          BorderSide(color: Colors.grey.shade400, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 🔹 Products Grid
              filteredProducts.isEmpty
                  ? const SliverFillRemaining(
                child: Center(
                    child: Text("No products found in this category")),
              )
                  : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final product = filteredProducts[index];
                      return ProductCard(product: product);
                    },
                    childCount: filteredProducts.length,
                  ),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.65, // Adjusted to match Shop
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Back to top button - Uncommented for completeness
      // floatingActionButton: _showBackToTop
      //     ? FloatingActionButton(
      //   backgroundColor: Colors.red[400],
      //   child: const Icon(Icons.arrow_upward, color: Colors.white),
      //   onPressed: () {
      //     _scrollController.animateTo(
      //       0,
      //       duration: const Duration(milliseconds: 500),
      //       curve: Curves.easeOut,
      //     );
      //   },
      // )
      //     : CustomWhatsAppFAB(),
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
      color: Colors.grey[50], // Match background color
      child: child,
    );
  }

  @override
  double get maxExtent => 70; // height of search bar
  @override
  double get minExtent => 70;

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return false;
  }
}

// ====================================================================
// 🌟 NEW SHIMMER LOADER WIDGET 🌟
// ====================================================================

class ProductShimmerLoader extends StatelessWidget {
  const ProductShimmerLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      // The Shimmer effect should mirror the final layout structure
      child: CustomScrollView(
        slivers: [
          // Shimmer for the Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Container(
                width: 150,
                height: 30,
                color: Colors.white, // Shimmer base color is light grey
              ),
            ),
          ),
          // Shimmer for Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Shimmer Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                    (_, index) => const _ShimmerGridItem(),
                childCount: 6, // Display a few shimmer items
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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