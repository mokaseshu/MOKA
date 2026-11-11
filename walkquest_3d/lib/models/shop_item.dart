enum ShopItemType { skin, trail, powerUp }

/// Something purchasable with coins.
class ShopItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final ShopItemType type;
  final int price;

  /// Trail color (ARGB) for trails, accent color for skins.
  final int color;

  /// glTF/GLB model for skins, rendered as the 3D avatar on the map.
  final String? modelUri;
  final double modelScale;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.type,
    required this.price,
    this.color = 0xFF7C4DFF,
    this.modelUri,
    this.modelScale = 1,
  });
}
