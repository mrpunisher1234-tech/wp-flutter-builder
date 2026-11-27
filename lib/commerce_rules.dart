int shippingCost({
  required int subtotal,
  required bool freeShippingEnabled,
  required int freeShippingThreshold,
  required int defaultShippingCost,
}) {
  final bool free = freeShippingEnabled &&
      freeShippingThreshold > 0 &&
      subtotal >= freeShippingThreshold;
  return free ? 0 : defaultShippingCost;
}
