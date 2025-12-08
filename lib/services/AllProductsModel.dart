import 'ProductVariant.dart';

/// -------------------- PRODUCT MODEL --------------------
class AllProductsModel {
  final String id; // product id
  final String productId;
  final String title;
  final String handle;
  final String description;
  final String image;
  final String product_status;
  final int quantity;
  final bool isDeal;
  final String variantId; // selected/default variant id (GID)
  final double price; // selected/default price
  final bool stockCheck; // selected/default stock
  final String ldescription;
  final String category;
  final String brandName;
  final double priceAfetDiscount;
  final String sku; // variant sku (selected/default)
  final double discountPercent;

  // 👇 ye naye fields add karo
  final String? inventoryManagement;
  final String? inventoryPolicy;
  final bool isPurchasable;
  final String? productType; // 👈 yahan product type (simple/variable)

  // NEW:
  final List<ProductVariant> variants; // all variants for this product
  final List<String> options; // ["Size","Color",...]

  AllProductsModel({
    required this.id,
    required this.title,
    required this.description,
    required this.handle,
    this.isDeal = false,
    required this.variantId,
    required this.image,
    required this.product_status,
    required this.price,
    required this.productId,
    required this.stockCheck,
    this.quantity = 1,
    this.sku = '',
    required this.ldescription,
    required this.category,
    required this.brandName,
    required this.priceAfetDiscount,
    required this.discountPercent,
    required this.variants,
    required this.options,
    this.inventoryManagement,
    this.inventoryPolicy,
    this.isPurchasable = true, // default true
    this.productType = "simple", // default simple
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'handle': handle,
      'image': image,
      'quantity': quantity,
      'variantId': variantId,
      'price': price,
      'sku': sku,
      'productId': productId,
      'stockCheck': stockCheck,
      'ldescription': ldescription,
      'category': category,
      // 'brandName': brandName,
      'brandName': 'Achha Foods',
      'priceAfetDiscount': priceAfetDiscount,
      'discountPercent': discountPercent,
      'variants': variants.map((v) => v.toJson()).toList(),
      'options': options,

      // 👇 naye fields ko bhi persist karo
      'inventoryManagement': inventoryManagement,
      'inventoryPolicy': inventoryPolicy,
      'isPurchasable': isPurchasable,
      'productType': productType,
    };
  }

  factory AllProductsModel.fromJson(Map<String, dynamic> json) {
    List<ProductVariant> parseVariants(dynamic v) {
      if (v is List) {
        return v
            .map((e) =>
            ProductVariant.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }

    final List<ProductVariant> variantsList = parseVariants(json['variants']);
    List<String> optionsList = [];
    final opts = json['options'];
    if (opts is List) {
      for (final o in opts) {
        if (o is Map<String, dynamic>) {
          optionsList.add((o['name'] ?? '').toString());
        } else if (o is String) {
          optionsList.add(o);
        }
      }
    }

    ProductVariant? first = variantsList.isNotEmpty ? variantsList.first : null;

    String firstImage = '';
    if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      final img0 = (json['images'] as List).first;
      if (img0 is Map && img0['src'] != null) {
        firstImage = img0['src'].toString();
      }
    } else if (json['image'] is String) {
      firstImage = json['image'] as String;
    }

    final String selectedVariantId = (() {
      final v = json['variantId'];
      if (v != null && v.toString().isNotEmpty) return v.toString();
      if (first != null) return first.id;
      return '';
    })();

    final double selectedPrice = () {
      if (json['price'] != null) {
        return (json['price'] is num)
            ? (json['price'] as num).toDouble()
            : double.tryParse(json['price'].toString()) ?? 0.0;
      }
      if (first != null) {
        return double.tryParse(first.price) ?? 0.0;
      }
      return 0.0;
    }();

    ProductVariant? selectedVariant;
    if (variantsList.isNotEmpty) {
      selectedVariant = variantsList.firstWhere(
            (v) => v.id == selectedVariantId,
        orElse: () => variantsList.first,
      );
    }

    final bool selectedStock =
    selectedVariant != null ? (selectedVariant.quantity > 0) : false;
    final String selectedSku = selectedVariant?.sku ?? '';

    return AllProductsModel(
      id: (json['id'] ?? json['productId'] ?? '').toString(),
      productId: (json['productId'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'No Title').toString(),
      description:
      (json['body_html'] ?? json['description'] ?? 'No Description')
          .toString(),
      handle: (json['handle'] ?? '').toString(),
      image: firstImage,
      product_status: (json['status'] ?? '').toString(),
      quantity:
      (json['quantity'] is num) ? (json['quantity'] as num).toInt() : 1,
      variantId: selectedVariantId,
      price: selectedPrice,
      stockCheck: json['stockCheck'] is bool
          ? json['stockCheck'] as bool
          : selectedStock,
      ldescription:
      (json['body_html'] ?? json['ldescription'] ?? 'No Description')
          .toString(),
      category: (json['product_type'] ?? json['category'] ?? 'Uncategorized')
          .toString(),
      // brandName: (json['vendor'] ?? json['brandName'] ?? 'No Brand').toString(),
      brandName: 'Achha Foods',
      sku: (json['sku'] ?? selectedSku).toString(),
      priceAfetDiscount: (json['priceAfetDiscount'] is num)
          ? (json['priceAfetDiscount'] as num).toDouble()
          : (json['priceAfetDiscount'] != null
          ? double.tryParse(json['priceAfetDiscount'].toString()) ??
          selectedPrice
          : selectedPrice),
      discountPercent: (json['discountPercent'] is num)
          ? (json['discountPercent'] as num).toDouble()
          : (double.tryParse('${json['discountPercent'] ?? 0.0}') ?? 0.0),
      variants: variantsList,
      options: optionsList,

      // 👇 naye fields bhi parse karo
      inventoryManagement: json['inventoryManagement']?.toString(),
      inventoryPolicy: json['inventoryPolicy']?.toString(),
      isPurchasable: json['isPurchasable'] is bool
          ? json['isPurchasable']
          : (json['isPurchasable']?.toString().toLowerCase() == "true"),
      productType: json['productType']?.toString() ?? "simple",
    );
  }
}
