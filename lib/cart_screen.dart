import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'native_mode.dart';

/// مدل آیتم سبد خرید
class CartItem {
  final WpItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  int get unitPrice {
    final String raw = item.onSale && item.salePrice.isNotEmpty
        ? item.salePrice
        : item.price;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  int get unitRegularPrice {
    final String raw = item.regularPrice.isNotEmpty
        ? item.regularPrice
        : item.price;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? unitPrice;
  }
}

/// مدیریت مرکزی سبد خرید با ذخیره دائمی در حافظه گوشی (shared_preferences)
class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._();

  static const String _storageKey = 'wptf_persisted_cart';

  CartManager._() {
    _loadFromPrefs(); // به محض باز شدن اپ، سبد خرید از حافظه خوانده می‌شود
  }

  final List<CartItem> _items = <CartItem>[];
  List<CartItem> get items => List<CartItem>.unmodifiable(_items);

  int get totalCount =>
      _items.fold(0, (int sum, CartItem i) => sum + i.quantity);

  int get totalRegularPrice => _items.fold(
      0, (int sum, CartItem i) => sum + (i.unitRegularPrice * i.quantity));
  int get totalPrice =>
      _items.fold(0, (int sum, CartItem i) => sum + (i.unitPrice * i.quantity));
  int get totalDiscount =>
      (totalRegularPrice - totalPrice) > 0 ? (totalRegularPrice - totalPrice) : 0;

  void addItem(WpItem item) {
    final int index = _items.indexWhere((CartItem i) => i.item.id == item.id);
    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(item: item, quantity: 1));
    }
    _saveToPrefs();
    notifyListeners();
  }

  void removeOne(WpItem item) {
    final int index = _items.indexWhere((CartItem i) => i.item.id == item.id);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _saveToPrefs();
      notifyListeners();
    }
  }

  void deleteItem(int itemId) {
    _items.removeWhere((CartItem i) => i.item.id == itemId);
    _saveToPrefs();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _saveToPrefs();
    notifyListeners();
  }

  // --- ذخیره و بازیابی دائمی ---
  // نکته: ساختار ذخیره باید دقیقاً با انتظارات WpItem.fromMap بخواند |
  // فیلدهای قیمت زیر کلید product هستند وگرنه حراج بعد از ری‌استارت می‌پرد.

  Future<void> _saveToPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> rawList = _items
          .map((CartItem cartItem) => <String, dynamic>{
                'quantity': cartItem.quantity,
                'item': <String, dynamic>{
                  'id': cartItem.item.id,
                  'title': cartItem.item.title,
                  'type': cartItem.item.type,
                  'url': cartItem.item.url,
                  'featured_image': cartItem.item.featuredImage,
                  'product': <String, dynamic>{
                    'price': cartItem.item.price,
                    'regular_price': cartItem.item.regularPrice,
                    'sale_price': cartItem.item.salePrice,
                    'on_sale': cartItem.item.onSale,
                    'in_stock': cartItem.item.inStock,
                    'purchasable': cartItem.item.purchasable,
                  },
                },
              })
          .toList();
      await prefs.setString(_storageKey, jsonEncode(rawList));
    } catch (_) {
      // خطای ذخیره | سبد حافظه‌ای سر جایش می‌ماند
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) return;
      final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
      final List<CartItem> restored = <CartItem>[];
      for (final dynamic element in decoded) {
        if (element is! Map<String, dynamic>) continue;
        final Map<String, dynamic> itemMap =
            element['item'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final int quantity = (element['quantity'] as num?)?.toInt() ?? 1;
        if (quantity < 1 || itemMap.isEmpty) continue;
        restored.add(
          CartItem(item: WpItem.fromMap(itemMap), quantity: quantity),
        );
      }
      if (restored.isEmpty) return;
      _items
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } catch (_) {
      // خطای خواندن | سبد خالی شروع می‌شود
    }
  }
}

/// نمای اصلی سبد خرید
class CartView extends StatefulWidget {
  final AppConfig config;
  final VoidCallback onGoToShop;

  const CartView({
    super.key,
    required this.config,
    required this.onGoToShop,
  });

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  bool _handingOff = false;

  @override
  void initState() {
    super.initState();
    CartManager.instance.addListener(_update);
  }

  @override
  void dispose() {
    CartManager.instance.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  void _showHandoffError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('خطا در انتقال سبد به سایت | دوباره تلاش کنید'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// «ادامه فرایند خرید»: سبد فلاتر با یک توکن یک‌بارمصرف به سشن ووکامرس
  /// تزریق می‌شود و وب‌ویو مستقیم روی صفحه تسویه‌حسابِ پُر باز می‌شود.
  /// بدون این پل، وب‌ویو کوکی جدا دارد و «سبد خرید خالی» نشان می‌داد.
  Future<void> _proceedToCheckout() async {
    final List<CartItem> items = CartManager.instance.items;
    if (items.isEmpty || _handingOff) return;

    final String apiBase = widget.config.effectiveApiBaseUrl;
    final String siteBase = apiBase.contains('/wp-json/')
        ? apiBase.split('/wp-json/').first
        : widget.config.siteUrl;

    setState(() => _handingOff = true);
    try {
      final Uri uri = Uri.parse('${apiBase}cart-handoff');
      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final HttpClientRequest request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              for (final CartItem cartItem in items)
                <String, dynamic>{
                  'product_id': cartItem.item.id,
                  'quantity': cartItem.quantity,
                },
            ],
          }),
        ),
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      if (!mounted) return;
      final dynamic decoded = jsonDecode(body);
      final String? token = decoded is Map<String, dynamic>
          ? decoded['token'] as String?
          : null;
      if (response.statusCode != 200 || token == null || token.isEmpty) {
        _showHandoffError();
        setState(() => _handingOff = false);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NativeWebViewScreen(
            title: 'تسویه حساب و پرداخت',
            url: '$siteBase/?wptf_cart_token=$token',
          ),
        ),
      );
      setState(() => _handingOff = false);
    } catch (_) {
      if (!mounted) return;
      _showHandoffError();
      setState(() => _handingOff = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartManager cart = CartManager.instance;

    if (cart.items.isEmpty) {
      return _EmptyCartState(
        primaryColor: widget.config.primaryColor,
        onGoToShop: widget.onGoToShop,
      );
    }

    return Column(
      children: <Widget>[
        // هدر بالای سبد
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'سبد خرید شما',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Dk.text1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Dk.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${toPersianDigits('${cart.totalCount}')} کالا',
                      style: const TextStyle(fontSize: 11, color: Dk.text2, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => cart.clearCart(),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.delete_sweep_outlined, size: 18, color: Dk.text3),
                      SizedBox(width: 4),
                      Text('حذف همه', style: TextStyle(fontSize: 11.5, color: Dk.text3)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Dk.border),

        // لیست کالاها و خلاصه فاکتور
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            children: <Widget>[
              ...cart.items.map((CartItem item) => _CartItemCard(
                    cartItem: item,
                    primaryColor: widget.config.primaryColor,
                  )),
              const SizedBox(height: 10),
              _InvoiceCard(cart: cart),
            ],
          ),
        ),

        // نوار ثابت چسبیده به پایین (ادامه فرایند خرید)
        _StickyBottomBar(
          totalPrice: cart.totalPrice,
          primaryColor: widget.config.primaryColor,
          busy: _handingOff,
          onCheckout: _proceedToCheckout,
        ),
      ],
    );
  }
}

/// کارت تک کالا با استپر تعداد و سطل زباله هوشمند
class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final Color primaryColor;

  const _CartItemCard({required this.cartItem, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final WpItem item = cartItem.item;
    final CartManager manager = CartManager.instance;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dk.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // تصویر کالا
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 86,
              height: 86,
              color: Dk.surface2,
              child: item.featuredImage.isNotEmpty
                  ? Image.network(
                      item.featuredImage,
                      fit: BoxFit.contain,
                      errorBuilder: (_, Object? error, StackTrace? trace) =>
                          const Icon(Icons.image, color: Dk.text4),
                    )
                  : const Icon(Icons.image, color: Dk.text4),
            ),
          ),
          const SizedBox(width: 12),

          // اطلاعات و قیمت و استپر
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Dk.text1,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, size: 14, color: Dk.success),
                    SizedBox(width: 4),
                    Text('موجود در انبار', style: TextStyle(fontSize: 10.5, color: Dk.success)),
                  ],
                ),
                const SizedBox(height: 10),

                // قیمت و استپر در یک ردیف
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // استپر تعداد
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Dk.border, width: 1.2),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: <Widget>[
                          // دکمه مثبت
                          InkWell(
                            onTap: () => manager.addItem(item),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.add, size: 16, color: Dk.text1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              toPersianDigits('${cartItem.quantity}'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Dk.text1),
                            ),
                          ),
                          // دکمه منفی یا سطل زباله
                          InkWell(
                            onTap: () => manager.removeOne(item),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                cartItem.quantity == 1 ? Icons.delete_outline : Icons.remove,
                                size: 16,
                                color: cartItem.quantity == 1 ? Dk.discount : Dk.text1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // نمایش قیمت | ضربدر تعداد (استاندارد دیجی‌کالا)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (item.onSale && item.regularPrice.isNotEmpty)
                          Text(
                            formatToman(
                              '${cartItem.unitRegularPrice * cartItem.quantity}',
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Dk.text4,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          formatToman(
                            '${cartItem.unitPrice * cartItem.quantity}',
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Dk.text1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت فاکتور و ریز قیمت‌ها
class _InvoiceCard extends StatelessWidget {
  final CartManager cart;
  const _InvoiceCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Dk.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'جزئیات قیمت سفارش',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Dk.text1),
          ),
          const SizedBox(height: 14),
          _InvoiceRow(
            label: 'قیمت کالاها (${toPersianDigits('${cart.totalCount}')})',
            value: formatToman('${cart.totalRegularPrice}'),
          ),
          if (cart.totalDiscount > 0) ...<Widget>[
            const SizedBox(height: 10),
            _InvoiceRow(
              label: 'سود شما از خرید',
              value: formatToman('${cart.totalDiscount}'),
              valueColor: Dk.discount,
            ),
          ],
          const SizedBox(height: 10),
          const _InvoiceRow(
            label: 'هزینه ارسال',
            value: 'محاسبه در مرحله بعد',
            valueColor: Dk.text3,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Dk.border),
          ),
          _InvoiceRow(
            label: 'مبلغ نهایی قابل پرداخت',
            value: formatToman('${cart.totalPrice}'),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InvoiceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13.5 : 12,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? Dk.text1 : Dk.text2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 12.5,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Dk.text1,
          ),
        ),
      ],
    );
  }
}

/// نوار ثابت پایینی جهت اتصال به تسویه حساب
class _StickyBottomBar extends StatelessWidget {
  final int totalPrice;
  final Color primaryColor;
  final bool busy;
  final VoidCallback onCheckout;

  const _StickyBottomBar({
    required this.totalPrice,
    required this.primaryColor,
    required this.busy,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Dk.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: busy ? null : onCheckout,
            child: Text(
              busy ? 'در حال انتقال به سایت…' : 'ادامه فرایند خرید',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('مبلغ قابل پرداخت', style: TextStyle(fontSize: 10.5, color: Dk.text3)),
              const SizedBox(height: 2),
              Text(
                formatToman('$totalPrice'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Dk.text1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// وضعیت سبد خرید خالی (Empty State)
class _EmptyCartState extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onGoToShop;

  const _EmptyCartState({required this.primaryColor, required this.onGoToShop});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Dk.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: Dk.border),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: Dk.text4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'سبد خرید شما خالی است!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Dk.text1),
            ),
            const SizedBox(height: 8),
            const Text(
              'می‌توانید برای مشاهده محصولات جدید به صفحه اصلی بازگردید.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Dk.text3, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor, width: 1.3),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onGoToShop,
              child: const Text('شروع خرید از فروشگاه', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
