import 'package:flutter/material.dart';
import '../../services/HomeDataCacheService.dart';
import '../Shoppings/Category_Product.dart';

class CollectionWidget extends StatelessWidget {
  final List<CollectionModel> categories;
  final bool isLoading;
  final String? error;

  const CollectionWidget({
    super.key,
    required this.categories,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text("Error loading collections: $error")),
      );
    }

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("No collections found.")),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];

          Widget avatarChild;
          ImageProvider? backgroundImage;

          if (category.image.isNotEmpty) {
            backgroundImage = NetworkImage(category.image);
            avatarChild = const SizedBox.shrink();
          } else {
            backgroundImage = null;
            avatarChild = const Icon(
              Icons.image_not_supported,
              size: 32,
              color: Colors.grey,
            );
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProduct(
                    categoryName: category.title,
                    imagePath: category.image,
                    collectionId: category.collectionId,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 33,
                    backgroundImage: backgroundImage,
                    backgroundColor: Colors.grey[200],
                    child: avatarChild,
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 68,
                    child: Text(
                      category.title,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}