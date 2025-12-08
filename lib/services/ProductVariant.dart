
/// -------------------- VARIANT MODEL --------------------
class ProductVariant {
  final String id; // Shopify GID: gid://shopify/ProductVariant/xxx
  final String title; // e.g., "Red / Large"
  final String price; // string to match Shopify JSON, parse when needed
  final int quantity; // inventory_quantity
  final String sku;

  ProductVariant({
    required this.id,
    required this.title,
    required this.price,
    required this.quantity,
    required this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    // Accept both Shopify product JSON and our own persisted toJson format
    final dynamic idRaw = json['admin_graphql_api_id'] ?? json['id'];
    final String gid = idRaw == null
        ? ''
        : idRaw.toString().startsWith('gid://')
        ? idRaw.toString()
        : "gid://shopify/ProductVariant/${idRaw.toString()}";

    return ProductVariant(
      id: gid,
      title: (json['title'] ?? '').toString(),
      price: (json['price'] ?? '0.0').toString(),
      quantity: (json['inventory_quantity'] is int)
          ? json['inventory_quantity'] as int
          : (json['quantity'] is int) // our persisted key fallback
          ? json['quantity'] as int
          : int.tryParse(
          '${json['inventory_quantity'] ?? json['quantity'] ?? 0}') ??
          0,
      sku: (json['sku'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // we persist a normalized object
      'id': id,
      'title': title,
      'price': price,
      'quantity': quantity,
      'sku': sku,
    };
  }
}

