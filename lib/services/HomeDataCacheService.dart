import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../screens/Consts/conts.dart';
import 'AllProductsModel.dart';
import 'AllProductsService.dart';

class CollectionModel {
  final String title;
  final String image;
  final String collectionId;

  CollectionModel({
    required this.title,
    required this.image,
    required this.collectionId,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    final imageUrl = json['image_url']?.toString() ?? '';
    final shopifyId = json['shopify_id']?.toString() ?? '';
    return CollectionModel(
      title: json['title'] ?? 'No Title',
      image: imageUrl,
      collectionId: shopifyId,
    );
  }
}

// --- The Singleton Cache Service ---

class HomeDataCacheService with ChangeNotifier {
  static final HomeDataCacheService _instance = HomeDataCacheService._internal();
  factory HomeDataCacheService() => _instance;
  HomeDataCacheService._internal();

  final AllProductsService _productService = AllProductsService();

  // Product State
  List<AllProductsModel> _allProducts = [];
  bool _isProductsLoaded = false;
  bool _isProductsLoading = false;
  String? _productsError;

  // Category State
  List<CollectionModel> _allCategories = [];
  bool _isCategoriesLoaded = false;
  bool _isCategoriesLoading = false;
  String? _categoriesError;

  // Public Getters
  List<AllProductsModel> get allProducts => _allProducts;
  bool get isProductsLoaded => _isProductsLoaded;
  bool get isProductsLoading => _isProductsLoading;
  String? get productsError => _productsError;

  List<CollectionModel> get allCategories => _allCategories;
  bool get isCategoriesLoaded => _isCategoriesLoaded;
  bool get isCategoriesLoading => _isCategoriesLoading;
  String? get categoriesError => _categoriesError;

  // --- Core Loading Function ---
  Future<void> loadAllData({bool forceReload = false}) async {
    // Only fetch if not already loaded or if a forced reload is requested
    if (!forceReload && _isProductsLoaded && _isCategoriesLoaded) return;

    // Fetch Products (can run concurrently with categories)
    if (forceReload || !_isProductsLoaded) {
      _fetchProducts(forceReload);
    }

    // Fetch Categories
    if (forceReload || !_isCategoriesLoaded) {
      _fetchCategories(forceReload);
    }
  }

  // --- Specific Fetch Functions ---

  Future<void> _fetchProducts(bool forceReload) async {
    if (_isProductsLoading && !forceReload) return;
    _isProductsLoading = true;
    _productsError = null;
    notifyListeners();

    try {
      _allProducts = await _productService.fetchProducts();
      _isProductsLoaded = true;
    } catch (e) {
      _productsError = e.toString();
      _allProducts = [];
    } finally {
      _isProductsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCategories(bool forceReload) async {
    if (_isCategoriesLoading && !forceReload) return;
    _isCategoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    // 1. Define common parameters and lists
    final String apiPath = '$localurl/api/collections';
    try {

        final response = await http.get(
          Uri.parse(apiPath),
          headers: {
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final Map<String,dynamic> data = json.decode(response.body);

          if(data['status'] == true && data['data'] is List){
            final rawCollections = data['data'] as List<dynamic>;
            final newCollections = rawCollections
            .map((json)=> CollectionModel.fromJson(json as Map<String,dynamic>))
            .toList();

            _allCategories = newCollections;
            _isCategoriesLoaded = true;
            _categoriesError = null;
          }else{
            _categoriesError = 'API returned unexpected data format. ${data['message'] ?? 'Invalid response format.'}';
            _allCategories = [];
          }
        } else {
          _categoriesError = 'Failed to load collections: ${response.statusCode}';
          _allCategories = [];
      }
    } catch (e) {
      _categoriesError = 'Network error during collection fetch: $e';
      _allCategories = [];
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  // Used by RefreshIndicator
  Future<void> refreshAllData() async {
    _isProductsLoaded = false;
    _isCategoriesLoaded = false;
    // We don't notify here, because loadAllData will notify upon completion
    await loadAllData(forceReload: true);
  }
}