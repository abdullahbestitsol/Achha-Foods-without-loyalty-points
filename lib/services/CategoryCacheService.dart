import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/Consts/conts.dart'; // Ensure this path is correct

class CategoryCacheService {
  // 1. Singleton instance
  static final CategoryCacheService _instance = CategoryCacheService._internal();

  factory CategoryCacheService() {
    return _instance;
  }

  CategoryCacheService._internal();

  // 2. State variables
  List<dynamic> _categories = [];
  bool _isLoaded = false;
  bool _isLoading = false;

  // Public getters
  List<dynamic> get categories => _categories;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  // 3. Category Fetching Logic (Only runs if data hasn't been loaded)
  Future<void> loadCategories() async {
    if (_isLoaded || _isLoading) {
      // Data is already available or currently being fetched, prevent duplicate calls
      return;
    }

    _isLoading = true;
    _categories = []; // Reset categories list
    List<dynamic> combinedCollections = [];

    // Define common request settings
    final String apiPath = '/admin/api/$adminApiVersion_const/';
    // Use 'limit: 250' to get all collections in one go (max limit for a single call)
    final Map<String, String> queryParams = {'fields': 'id,title,handle,image', 'limit': '250'};
    final Map<String, String> headers = {
      'X-Shopify-Access-Token': adminAccessToken_const,
      'Content-Type': 'application/json',
    };

    // Endpoints to check: Custom Collections and Smart Collections
    final List<String> collectionEndpoints = [
      // 'custom_collections.json',
      'smart_collections.json'
    ];

    try {
      for (String endpoint in collectionEndpoints) {
        final url = Uri.https(
          shopifyStoreUrl_const,
          '$apiPath$endpoint',
          queryParams,
        );

        final response = await http.get(url, headers: headers);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // Determine the correct JSON key (e.g., 'custom_collections' or 'smart_collections')
          final String collectionsKey = endpoint.split('.').first;
          final rawCollections = data[collectionsKey] as List<dynamic>? ?? [];

          combinedCollections.addAll(rawCollections);
          print('Successfully loaded ${rawCollections.length} from $endpoint');
        } else {
          // Log the failure but continue to try the next endpoint
          print('Failed to load $endpoint. Status: ${response.statusCode}');
        }
      }

      // Finalize the results
      if (combinedCollections.isNotEmpty) {
        _categories = combinedCollections;
        _isLoaded = true; // Mark as successfully loaded
      } else {
        print('Failed to load any categories from both endpoints.');
      }
    } catch (e) {
      // Handle network/parsing error
      print('Error fetching collections: $e');
    } finally {
      _isLoading = false;
      // Note: You may want to call notifyListeners() if this function is in a ChangeNotifier
    }
  }

  // Optional: Method to force a reload if needed
  void clearCache() {
    _categories = [];
    _isLoaded = false;
  }
}