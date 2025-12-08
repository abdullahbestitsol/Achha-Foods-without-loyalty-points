import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../CartScreen/Cart.dart';

class CustomAppBarDetails extends StatelessWidget
    implements PreferredSizeWidget {
  final dynamic product; // Accept either AllProductsModel or HeatingpadModel

  @override
  final Size preferredSize; // This defines the size of the app bar

  const CustomAppBarDetails({super.key, required this.product})
      : preferredSize = const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          SizedBox(
            height: 40,
            child: Image.asset("assets/images/achhafoods.png"),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // Assuming Cart.addToCart works with both model types
              Cart.addToCart(product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${product.title} added to cart')),
              );
            },
            icon: SvgPicture.asset(
              "assets/icons/Bookmark.svg",
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
