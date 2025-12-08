import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:achhafoods/screens/Home%20Screens/homepage.dart';
import 'package:achhafoods/screens/CartScreen/CartScreen.dart';
import 'package:achhafoods/services/DynamicContentCache.dart';
import '../../services/AllProductsModel.dart';
import '../../services/CartServices.dart';
import '../../utilities/icon_mapping.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize = const Size.fromHeight(kToolbarHeight);

  const CustomAppBar({super.key});

  @override
  State<CustomAppBar> createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  @override
  Widget build(BuildContext context) {
    final dynamicContentCache = Provider.of<DynamicContentCache>(context);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            },
            child: _buildLogo(dynamicContentCache),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Stack(
            children: [
              _buildCartIcon(dynamicContentCache),
              _buildCartBadge(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(DynamicContentCache cache) {
    final imageUrl = cache.getAppbarImage();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        height: 40,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Image.asset("assets/images/emart.png", height: 40),
        ),
      );
    } else {
      return SizedBox(
        height: 40,
        child: Image.asset("assets/images/emart.png"),
      );
    }
  }

  Widget _buildCartIcon(DynamicContentCache cache) {
    final iconName = cache.getAppbarIcon();
    final iconData = IconMapping.getIconFromString(
      iconName ?? '',
      Icons.shopping_cart,
    );

    return IconButton(
      icon: Icon(
        iconData,
        color: const Color(0xffEC1D28),
        size: 28,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartScreen()),
        );
      },
    );
  }

  Widget _buildCartBadge() {
    return ValueListenableBuilder<List<AllProductsModel>>(
      valueListenable: CartService.cartItemsNotifier,
      builder: (context, cartItems, child) {
        final itemCount = cartItems.length;
        return itemCount > 0
            ? Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Center(
              child: Text(
                itemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )
            : const SizedBox.shrink();
      },
    );
  }
}