import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart'; // Add this import
import '../../services/DynamicContentCache.dart';
import '../../services/HomeDataCacheService.dart';
import '../Shoppings/Category_Product.dart';
import '../Shoppings/Shop.dart';
import 'package:achhafoods/screens/CartScreen/CartScreen.dart';
import 'package:achhafoods/screens/ContactUs/Contacts.dart';
import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
import 'package:achhafoods/screens/Profile/OrderDetails.dart';
import 'package:achhafoods/screens/Refferal/ReferralScreen.dart';
import 'package:achhafoods/screens/LoyalityPoints/LoyaltyPointsScreen.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final HomeDataCacheService _homeDataCache = HomeDataCacheService();
  bool _isCustomerLoggedIn = false;
  Color? drawerIconColor = Colors.grey[800];
  final Color _lightDividerColor = Colors.grey.shade300;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _homeDataCache.loadAllData();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final customerDataString = prefs.getString('customerData');

    if (customerDataString != null) {
      try {
        final Map<String, dynamic> customerData = jsonDecode(customerDataString);
        final accessToken = customerData['accessToken'];

        if (accessToken != null && accessToken.toString().isNotEmpty) {
          setState(() => _isCustomerLoggedIn = true);
        } else {
          setState(() => _isCustomerLoggedIn = false);
        }
      } catch (e) {
        print("Error decoding customer data: $e");
        setState(() => _isCustomerLoggedIn = false);
      }
    } else {
      setState(() => _isCustomerLoggedIn = false);
    }
  }

  Widget _buildLightDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: _lightDividerColor,
      indent: 16.0,
      endIndent: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Provider to get DynamicContentCache instance
    final dynamicCache = Provider.of<DynamicContentCache>(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            child: Image(image: AssetImage("assets/images/emart.png")),
          ),

          // Home - Dynamic Text
          _createDrawerItem(
            icon: Icons.home,
            text: dynamicCache.getSidebarHome()?? 'Home',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const HomePage()));
            },
          ),
          _buildLightDivider(),

          // Store - Dynamic Text
          _createDrawerItem(
            icon: Icons.store,
            text: dynamicCache.getSidebarStore() ?? 'Store',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const Shop()));
            },
          ),
          _buildLightDivider(),

          // Product Categories - Dynamically Fetched and Built
          ListenableBuilder(
            listenable: _homeDataCache,
            builder: (context, child) {
              return _createDynamicCategoriesDropdown(
                categories: _homeDataCache.allCategories,
                isLoading: _homeDataCache.isCategoriesLoading,
                error: _homeDataCache.categoriesError,
              );
            },
          ),

          _buildLightDivider(),

          _createDrawerItem(
            icon: Icons.local_offer,
            text: dynamicCache.getSidebarDeals()?? 'Deals',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProduct(
                    categoryName: dynamicCache.getSidebarDrawerText() ?? 'Deals',
                    imagePath: '',
                    categoryHandle: '',
                    collectionId: dynamicCache.getSidebarDrawerCollectionID() ?? '431094661397',
                    productTypeFilter: '',
                  ),
                ),
              );
            },
          ),

          _buildLightDivider(),

          // Cart - Dynamic Text
          _createDrawerItem(
            icon: Icons.shopping_cart,
            text: dynamicCache.getSidebarCart()?? 'Cart',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CartScreen()));
            },
          ),

          if (_isCustomerLoggedIn) ...[
            _buildLightDivider(),

            // My Orders - Dynamic Text
            _createDrawerItem(
              icon: Icons.shopping_bag,
              text: dynamicCache.getSidebarMyOrders()?? 'My Orders',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyOrdersScreen()));
              },
            ),
            _buildLightDivider(),

            // Refer a Friend - Dynamic Text
            // _createDrawerItem(
            //   icon: Icons.share,
            //   text: dynamicCache.getSidebarReferAFriend()?? 'Refer a Friend',
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const ReferralScreen(),
            //       ),
            //     );
            //   },
            // ),
            // _buildLightDivider(),

            // Loyalty Points - Dynamic Text
            // _createDrawerItem(
            //   icon: Icons.stars,
            //   text: dynamicCache.getSidebarLoyaltyPoints()?? 'Loyalty Points',
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const LoyaltyPointsScreen(),
            //       ),
            //     );
            //   },
            // ),
          ],

          _buildLightDivider(),

          // Contacts - Dynamic Text
          _createDrawerItem(
            icon: Icons.contacts,
            text: dynamicCache.getSidebarContacts()?? 'Contacts',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const Contacts()));
            },
          ),
          _buildLightDivider(),
        ],
      ),
    );
  }

  // ... rest of your existing methods (_createDynamicCategoriesDropdown, _createDrawerItem, _createDrawerItemDropdown) remain the same
  Widget _createDynamicCategoriesDropdown({
    required List<dynamic> categories,
    required bool isLoading,
    String? error,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
            child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    if (error != null) {
      return _createDrawerItem(
        icon: Icons.error_outline,
        text: 'Categories Error: $error',
        onTap: () {
          _homeDataCache.loadAllData(forceReload: true);
        },
      );
    }

    if (categories.isEmpty) {
      return _createDrawerItem(
        icon: Icons.category,
        text: 'Categories (None Found)',
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const Shop()));
        },
      );
    }

    return _createDrawerItemDropdown(
      icon: Icons.category,
      text: 'Product Categories', // You can make this dynamic too if needed
      categories: categories,
    );
  }

  Widget _createDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: drawerIconColor),
      title: Text(text),
      onTap: onTap,
    );
  }

  Widget _createDrawerItemDropdown({
    required IconData icon,
    required String text,
    required List<dynamic> categories,
  }) {
    final List<Widget> categoryListTiles = [];
    final List<CollectionModel> collections = categories.cast<CollectionModel>();

    for(int i = 0; i < collections.length; i++) {
      final category = collections[i];
      final categoryTitle = category.title;
      final collectionId = category.collectionId;
      final imageUrl = category.image;
      const String categoryHandlePlaceholder = 'no-handle-in-model';

      Widget tile = ListTile(
        contentPadding: const EdgeInsets.only(left: 32.0),
        leading: imageUrl.isNotEmpty
            ? SizedBox(
          width: 30,
          height: 30,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.category, color: drawerIconColor),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          ),
        )
            : Icon(Icons.image_not_supported, color: drawerIconColor),
        title: Text(categoryTitle),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryProduct(
                categoryName: categoryTitle,
                imagePath: imageUrl,
                categoryHandle: categoryHandlePlaceholder,
                collectionId: collectionId,
                productTypeFilter: '',
              ),
            ),
          );
        },
      );

      categoryListTiles.add(tile);

      if (i < collections.length - 1) {
        categoryListTiles.add(Divider(
          height: 1,
          thickness: 1,
          indent: 32 + 16,
          endIndent: 16,
          color: Colors.grey.shade200,
        ));
      }
    }

    return ExpansionTile(
      iconColor: drawerIconColor,
      collapsedIconColor: drawerIconColor,
      leading: Icon(icon, color: drawerIconColor),
      title: Text(text),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: categoryListTiles,
    );
  }
}