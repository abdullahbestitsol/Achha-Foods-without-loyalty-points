import 'dart:convert';
import 'package:achhafoods/screens/Consts/conts.dart';
import 'package:http/http.dart' as http;
import 'AllProductsModel.dart';

/// -------------------- SERVICE: FETCH PRODUCTS --------------------
class AllProductsService {
  final String shopifyStoreUrl = shopifyStoreUrl_const;
  final String apiVersion = adminApiVersion_const;
  // NOTE: This is your Admin API token—keep it secure.
  final String accessToken = adminAccessToken_const;


  /// Fetches products for a specific collection and also retrieves the collection's name.
  ///
  /// Returns a Future<Map<String, dynamic>> containing:
  /// - 'products': List<AllProductsModel>
  /// - 'collectionName': String
  Future<Map<String, dynamic>> fetchProductsByCollectionId(
      String collectionId) async {
    if (collectionId.isEmpty) {
      print('Collection ID is empty. Returning no products.');
      return {
        'products': <AllProductsModel>[],
        'collectionName': 'N/A'
      };
    }

    // Default values for the return map
    List<AllProductsModel> products = [];
    String collectionName = 'Unknown Collection';

    // --- 1. Construct the Product URL ---
    // Status filter is added locally as API doesn't support collection_id + status query.
    final productsUrl = Uri.https(
        shopifyStoreUrl,
        '/admin/api/$adminApiVersion_const/products.json',
        {
          'collection_id': collectionId,
          'limit': '220',
          'status': 'active',
          'fields': 'id,title,handle,body_html,images,variants,product_type,vendor,options'
        }
    );

    print('Url: $productsUrl');

    // --- 2. Construct the Collection Name URL ---
    final collectionNameUrl = Uri.https(
      shopifyStoreUrl,
      '/admin/api/$adminApiVersion_const/collections/$collectionId.json',
    );

    print('Fetching products for Collection ID: $collectionId from $productsUrl');

    // --- FETCH COLLECTION NAME FIRST ---
    try {
      final response = await http.get(
        collectionNameUrl,
        headers: {
          'X-Shopify-Access-Token': accessToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Collections can be 'custom_collection' or 'smart_collection'
        final collectionData = data['collection'] ?? data['custom_collection'] ?? data['smart_collection'];

        if (collectionData != null) {
          collectionName = collectionData['title'] ?? 'Unknown Collection';
        }
        print('Fetched Collection Name: $collectionName');
      } else {
        print('Failed to fetch collection name. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching collection name: $e');
    }

    // --- FETCH PRODUCTS ---
    try {
      final response = await http.get(
        productsUrl,
        headers: {
          'X-Shopify-Access-Token': accessToken,
          'Content-Type': 'application/json',
        },
      );

      print('Products Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> productJson = data['products'] ?? [];

        print('Fetched ${productJson.length} products for collection (before filtering).');

        products = productJson
            .map((json) => AllProductsModel.fromJson(json))
            .toList();

        // **FIXED LOCAL FILTER: Check for 'active' OR empty string (which Shopify returns for published products)**
        products = products.where((product) {
          final status = product.product_status.toLowerCase();
          print('Product Status: $status');
          return status == 'active' || status.isEmpty;
        }).toList();

        print('Returning ${products.length} active/published products for collection.');

      } else {
        print(
            'Failed to load products for collection. Status code: ${response.statusCode} - ${response.body}');
        // Products remains empty list
      }
    } catch (e) {
      print('Error fetching products by collection: $e');
      // Products remains empty list
    }

    // --- RETURN COMBINED DATA ---
    return {
      'products': products,
      'collectionName': collectionName,
    };
  }

  // NOTE: The fetchProducts() function uses the efficient API-level filtering via query parameter.
  Future<List<AllProductsModel>> fetchProducts() async {
    final url = Uri.https(
      shopifyStoreUrl,
      '/admin/api/$adminApiVersion_const/products.json',
      {
        'limit': '250',
        'status': 'active', // <--- CORRECTLY FILTERING BY QUERY PARAMETER
        'fields':
        'id,title,handle,body_html,images,variants,product_type,vendor,options'
      },
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'X-Shopify-Access-Token': accessToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final productsData = data['products'] as List;

        List<AllProductsModel> activeProducts = productsData
            .map((j) => AllProductsModel.fromJson(j as Map<String, dynamic>))
            .toList();

        print('Fetched and returning ${activeProducts.length} active products (API filtered).');

        return activeProducts;

      } else {
        throw Exception(
            'Failed to load products: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }
}