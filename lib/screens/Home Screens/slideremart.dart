import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/DynamicAppData.dart';
import '../../services/DynamicContentCache.dart';
import '../Shoppings/Category_Product.dart';

class EmartSlider extends StatefulWidget {
  const EmartSlider({super.key});

  @override
  State<EmartSlider> createState() => _EmartSliderState();
}

class _EmartSliderState extends State<EmartSlider> {
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _timer;
  List<BannerItem> bannerItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadSliderImages();
  }

  Future<void> _loadSliderImages() async {
    try {
      final dynamicCache = DynamicContentCache.instance;
      await dynamicCache.loadDynamicData();
      final cachedData = dynamicCache.data;

      if (cachedData != null) {
        bannerItems = cachedData.bannerItems;
      }

      setState(() {
        _isLoading = false;
      });

      if (bannerItems.isNotEmpty) {
        _startAutoSlide();
      }
    } catch (e) {
      debugPrint("Error loading slider images: $e");
      setState(() => _isLoading = false);
    }
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (bannerItems.isEmpty) return;

      _currentPage = (_currentPage + 1) % bannerItems.length;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onBannerTap(BuildContext context, String? collectionId) {
    if (collectionId != null && collectionId.isNotEmpty) {
      debugPrint('Tapped banner. Collection ID: $collectionId');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryProduct(
            collectionId: collectionId,
            categoryName: 'Banner Products',
            imagePath: 'assets/placeholder.png',
            categoryHandle: '',
            productTypeFilter: '',
          ),
        ),
      );
    } else {
      debugPrint('Tapped banner, but no collectionId found in move_url.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingPlaceholder();
    if (bannerItems.isEmpty) {
      return _buildFallbackSlider();
    }

    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: bannerItems.length,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              final item = bannerItems[index];
              final imageUrl = item.imageUrl;
              final collectionId = item.moveUrl;

              return GestureDetector(
                onTap: () => _onBannerTap(context, collectionId),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const Text('Failed to load image', style: TextStyle(fontSize: 12)),
                            Text('URL: ${imageUrl.substring(0, 30)}...', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (bannerItems.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(bannerItems.length, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() => SizedBox(
    height: 180,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
    ),
  );

  Widget _buildFallbackSlider() {
    final fallbackImages = [
      'assets/images/sliderimg1.png',
      'assets/images/sliderimg2.png',
    ];

    if (fallbackImages.isEmpty) {
      return const SizedBox(height: 1);
    }

    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _pageController,
        itemCount: fallbackImages.length,
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            fallbackImages[index],
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.error)),
              );
            },
          ),
        ),
      ),
    );
  }
}