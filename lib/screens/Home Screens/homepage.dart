import 'dart:async';
import 'dart:convert';
import 'package:achhafoods/screens/Collections/CollectionWidget.dart';
import 'package:achhafoods/screens/Consts/CustomFloatingButton.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../Products/ProductCard.dart';
import 'package:shimmer/shimmer.dart';
import 'package:achhafoods/screens/Consts/appBar.dart';
import 'package:achhafoods/screens/Drawer/Drawer.dart';
import 'package:achhafoods/screens/Home%20Screens/slideremart.dart';
import 'package:achhafoods/screens/Navigation%20Bar/NavigationBar.dart';
import '../../services/AllProductsModel.dart';
import '../../services/DynamicContentCache.dart';
import '../../services/HomeDataCacheService.dart';
import '../Consts/conts.dart';
import 'DynamicSingleBanner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeDataCacheService _productCacheService = HomeDataCacheService();
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  // Add state for collection products
  List<AllProductsModel> _collectionProducts = [];
  bool _isCollectionLoading = false;
  String? _collectionError;
  String _collectionName = 'Featured Products';

  final GlobalKey<DynamicSingleBannerState> _bannerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _productCacheService.loadAllData();
    _loadCollectionProducts();

    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 400;
      if (shouldShow != _showBackToTop) {
        setState(() {
          _showBackToTop = shouldShow;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCollectionProducts() async {
    if (_isCollectionLoading) return;

    setState(() {
      _isCollectionLoading = true;
      _collectionError = null;
    });

    try {
      final result = await fetchProductsByCollectionId('482865316117');
      setState(() {
        _collectionProducts = result['products'] ?? [];
        _collectionName = result['collectionName'] ?? 'Featured Products';
      });
    } catch (e) {
      setState(() {
        _collectionError = e.toString();
        _collectionProducts = [];
      });
    } finally {
      setState(() {
        _isCollectionLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> fetchProductsByCollectionId(
      String collectionId) async {
    if (collectionId.isEmpty) {
      return {
        'products': <AllProductsModel>[],
        'collectionName': 'N/A'
      };
    }

    List<AllProductsModel> products = [];
    String collectionName = 'Featured Products';

    final productsUrl = Uri.https(
        shopifyStoreUrl_const,
        '/admin/api/$adminApiVersion_const/products.json',
        {
          'collection_id': collectionId,
          'limit': '220',
          'fields': 'id,title,handle,body_html,images,variants,product_type,vendor,options'
        }
    );

    final collectionNameUrl = Uri.https(
      shopifyStoreUrl_const,
      '/admin/api/$adminApiVersion_const/collections/$collectionId.json',
    );

    try {
      final response = await http.get(
        collectionNameUrl,
        headers: {
          'X-Shopify-Access-Token': adminAccessToken_const,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final collectionData = data['collection'] ?? data['custom_collection'] ?? data['smart_collection'];

        if (collectionData != null) {
          collectionName = collectionData['title'] ?? 'Featured Products';
        }
      }
    } catch (e) {
      debugPrint('Error fetching collection name: $e');
    }

    try {
      final response = await http.get(
        productsUrl,
        headers: {
          'X-Shopify-Access-Token': adminAccessToken_const,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> productJson = data['products'] ?? [];
        products = productJson
            .map((json) => AllProductsModel.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }

    return {
      'products': products,
      'collectionName': collectionName,
    };
  }

  // --- SHIMMER LOADING WIDGET ---
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Slider Placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 20),

            // Title Placeholder
            Container(
              height: 20,
              width: 200,
              color: Colors.white,
            ),
            const SizedBox(height: 10),

            // Categories Placeholder (Horizontal List)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(height: 10, width: 50, color: Colors.white),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Grid Title Placeholder
            Container(
              height: 20,
              width: 150,
              color: Colors.white,
            ),
            const SizedBox(height: 10),

            // Product Grid Placeholder
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 16,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid({
    required String? title,
    required List<AllProductsModel> products,
    required String? error,
  }) {
    if (error != null) {
      return Center(child: Text("Error: $error"));
    }

    final displayProducts = products.toList();

    if (displayProducts.isEmpty) {
      return const Center(child: Text("No products found."));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: displayProducts.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, index) {
            final product = displayProducts[index];
            return ProductCard(product: product);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Provider to get DynamicContentCache instance
    final dynamicCache = Provider.of<DynamicContentCache>(context);

    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      bottomNavigationBar: const NewNavigationBar(),
      backgroundColor: Colors.grey[50],
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

      body: ListenableBuilder(
        listenable: Listenable.merge([_productCacheService, dynamicCache]),
        builder: (context, child) {
          final isProductsLoading = _productCacheService.isProductsLoading;
          final isCategoriesLoading = _productCacheService.isCategoriesLoading;
          final isDynamicLoading = dynamicCache.isLoading;

          if (isProductsLoading || isCategoriesLoading || isDynamicLoading || _isCollectionLoading) {
            return _buildShimmerLoading();
          }

          final allProducts = _productCacheService.allProducts;
          final allCategories = _productCacheService.allCategories;
          final hotDeals = allProducts.toList();

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  await _productCacheService.refreshAllData();
                  await dynamicCache.loadDynamicData();
                  await _loadCollectionProducts();
                  _bannerKey.currentState?.refreshBanner();
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const EmartSlider(),
                        const SizedBox(height: 10),

                        // 🔹 Popular Categories
                        ListenableBuilder(
                          listenable: dynamicCache,
                          builder: (context, _) {
                            final popularCollectionsTitle = dynamicCache.getPopularCollectionsTitle();
                            if (popularCollectionsTitle != null && popularCollectionsTitle.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                child: Text(
                                  popularCollectionsTitle,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        CollectionWidget(
                          categories: allCategories,
                          isLoading: false,
                          error: _productCacheService.categoriesError,
                        ),

                        const SizedBox(height: 20),

                        // 🔹 Collection Products
                        _buildProductGrid(
                          title: _collectionName,
                          products: _collectionProducts,
                          error: _collectionError,
                        ),

                        const SizedBox(height: 20),

                        // 🌟 SINGLE BANNER IMAGE
                        DynamicSingleBanner(
                          key: _bannerKey,
                        ),
                        const SizedBox(height: 20),

                        // 🔹 Hot Deals
                        ListenableBuilder(
                          listenable: dynamicCache,
                          builder: (context, _) {
                            final hotTitle = dynamicCache.getHotDealsTitle();
                            return _buildProductGrid(
                              title: hotTitle,
                              products: hotDeals,
                              error: _productCacheService.productsError,
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // if (_showBackToTop)
              //   Positioned(
              //     bottom: 20,
              //     right: 20,
              //     child: FloatingActionButton(
              //       onPressed: () {
              //         _scrollController.animateTo(
              //           0,
              //           duration: const Duration(milliseconds: 500),
              //           curve: Curves.easeOut,
              //         );
              //       },
              //       backgroundColor: Colors.red[400],
              //       child: const Icon(Icons.arrow_upward, color: Colors.white),
              //     ),
              //   ),
            ],
          );
        },
      ),
    );
  }
}