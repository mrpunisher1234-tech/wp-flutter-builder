class WpAttributeOption {
  const WpAttributeOption({required this.name, required this.value});

  final String name;
  final String value;

  factory WpAttributeOption.fromMap(dynamic raw) {
    if (raw is Map) {
      return WpAttributeOption(
        name: ((raw['name'] as String?) ?? '').trim(),
        value: ((raw['value'] as String?) ?? '').trim(),
      );
    }
    final String text = (raw as String? ?? '').trim();
    return WpAttributeOption(name: text, value: text);
  }
}

class WpVariation {
  const WpVariation({
    required this.id,
    required this.attributes,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.inStock,
    required this.purchasable,
    required this.onSale,
    required this.sku,
    required this.image,
    this.stockQuantity,
  });

  final int id;
  final Map<String, String> attributes;
  final String price;
  final String regularPrice;
  final String salePrice;
  final bool inStock;
  final bool purchasable;
  final bool onSale;
  final String sku;
  final String image;
  final int? stockQuantity;

  factory WpVariation.fromMap(
    Map<String, dynamic> map, {
    String Function(String url)? mapUrl,
  }) {
    final Map<String, String> attributes = <String, String>{};
    final dynamic rawAttributes = map['attributes'];
    if (rawAttributes is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawAttributes.entries) {
        attributes['${entry.key}'] = '${entry.value}';
      }
    }
    final String image = ((map['image'] as String?) ?? '').trim();
    return WpVariation(
      id: (map['id'] as num?)?.toInt() ?? 0,
      attributes: Map<String, String>.unmodifiable(attributes),
      price: (map['price'] as String?) ?? '',
      regularPrice: (map['regular_price'] as String?) ?? '',
      salePrice: (map['sale_price'] as String?) ?? '',
      inStock: map['in_stock'] == true,
      purchasable: map['purchasable'] == true,
      onSale: map['on_sale'] == true,
      sku: (map['sku'] as String?) ?? '',
      image: mapUrl == null ? image : mapUrl(image),
      stockQuantity: (map['stock_quantity'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'attributes': attributes,
    'price': price,
    'regular_price': regularPrice,
    'sale_price': salePrice,
    'in_stock': inStock,
    'stock_quantity': stockQuantity,
    'purchasable': purchasable,
    'on_sale': onSale,
    'sku': sku,
    'image': image,
  };
}

String variationCartKey(int productId, WpVariation? variation) {
  final List<String> entries = <String>[];
  if (variation != null) {
    final List<String> keys = variation.attributes.keys.toList()..sort();
    entries.addAll(keys.map((String key) => '$key=${variation.attributes[key]}'));
  }
  return '$productId:${variation?.id ?? 0}:${entries.join('|')}';
}
