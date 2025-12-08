import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Add this import
import '../../services/DynamicContentCache.dart';

class DynamicSingleBanner extends StatefulWidget {
  const DynamicSingleBanner({
    super.key,
  });

  @override
  State<DynamicSingleBanner> createState() => DynamicSingleBannerState();
}

class DynamicSingleBannerState extends State<DynamicSingleBanner> {
  String? singleBannerImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSingleBannerImage();
  }

  Future<void> refreshBanner() => _loadSingleBannerImage();

  Future<void> _loadSingleBannerImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      singleBannerImageUrl = null;
    });

    try {
      // Use Provider to get the instance in initState context
      final dynamicCache = DynamicContentCache.instance;
      final cachedData = dynamicCache.data;

      if (cachedData != null) {
        singleBannerImageUrl = cachedData.singleImage;
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Alternative approach using Provider in build method
    final dynamicCache = Provider.of<DynamicContentCache>(context);
    final imageUrl = dynamicCache.getSingleImage();

    if (_isLoading) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        height: 180,
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
                    const Text('Failed to load banner',
                        style: TextStyle(fontSize: 12)),
                    Text('URL: ${imageUrl.substring(0, 30)}...',
                        style: const TextStyle(fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}