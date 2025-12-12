import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'checkout_page.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';

class CartPage extends StatefulWidget {
  final List<Product> products;
  final Map<String, int> cart;
  final ValueChanged<Map<String, int>>? onCartChanged;

  const CartPage({
    super.key,
    required this.products,
    required this.cart,
    this.onCartChanged,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<String, int> _cart;
  final Map<String, double> _variantPriceDelta = {};
  final Map<String, String> _variantName = {};
  final Map<String, Uint8List?> _runtimeThumb = {};

  @override
  void initState() {
    super.initState();
    _cart = Map<String, int>.from(widget.cart);
    _loadVariantData();
  }

  Future<void> _loadVariantData() async {
    for (final key in _cart.keys) {
      final parts = key.split('::');
      if (parts.length == 2) {
        final productId = parts.first;
        final variantId = parts.last;
        final varDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .collection('variants')
            .doc(variantId)
            .get();
        if (varDoc.exists) {
          final data = varDoc.data()!;
          _variantPriceDelta[key] = (data['priceDelta'] as num?)?.toDouble() ?? 0.0;
          _variantName[key] = (data['name'] as String?) ?? variantId;
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _syncCartToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    try {
      // Convert values to ints (Firestore-friendly)
      final Map<String, dynamic> cartData = _cart.map((k, v) => MapEntry(k, v));
      await userDoc.set({'cart': cartData}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت مزامنة العربة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر مزامنة العربة: $e')));
      }
    }
  }

  void _changeQuantity(String productId, int delta) {
    setState(() {
      final current = _cart[productId] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = next;
      }
    });
    // notify parent immediately (optimistic)
    widget.onCartChanged?.call(Map<String, int>.from(_cart));
    _syncCartToFirestore();
    _loadVariantData();
  }

  Future<Uint8List?> _generateThumb(Product p) async {
    if (p.mediaType != 'video') return null;
    if (p.thumbnailUrl.isNotEmpty) return null;
    final url = p.imageUrl;
    try {
      if (url.startsWith('http')) {
        final resp = await http.get(Uri.parse(url));
        final dir = await getTemporaryDirectory();
        final filePath = path.join(dir.path, 'tmp_vid_${DateTime.now().millisecondsSinceEpoch}.mp4');
        final file = await File(filePath).writeAsBytes(resp.bodyBytes);
        final bytes = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 240,
          quality: 60,
        );
        try {
          await file.delete();
        } catch (_) {}
        return bytes;
      } else {
        return await VideoThumbnail.thumbnailData(
          video: url,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 240,
          quality: 60,
        );
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cart.entries
        .map(
          (e) {
            final productId = e.key.split('::').first;
            final product = widget.products.firstWhere((p) => p.id == productId);
            return _CartItem(
              product: product,
              quantity: e.value,
              cartKey: e.key,
            );
          },
        )
        .toList();

    double itemPrice(String cartKey) {
      final productId = cartKey.split('::').first;
      final product = widget.products.firstWhere((p) => p.id == productId);
      final delta = _variantPriceDelta[cartKey] ?? 0.0;
      return product.price + delta;
    }

    final total = _cart.entries.fold<double>(0.0, (prev, e) => prev + itemPrice(e.key) * e.value);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          cartItems.isEmpty
              ? const Center(
                  child: Text(
                    'عربة التسوق فارغة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 50, left: 10, right: 5),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.black12,
                                child: item.product.mediaType == 'video'
                                    ? (item.product.thumbnailUrl.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              item.product.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, e, s) =>
                                                  const Icon(
                                                Icons.videocam_outlined,
                                                color: Colors.black45,
                                              ),
                                            ),
                                          )
                                        : FutureBuilder<Uint8List?>(
                                            future: (_runtimeThumb[item.product.id] != null
                                                    ? Future.value(_runtimeThumb[item.product.id])
                                                    : _generateThumb(item.product)),
                                            builder: (context, snap) {
                                              final bytes = snap.data;
                                              _runtimeThumb[item.product.id] = bytes;
                                              if (bytes != null && bytes.isNotEmpty) {
                                                return ClipOval(
                                                  child: Image.memory(
                                                    bytes,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }
                                              return const Icon(
                                                Icons.videocam_outlined,
                                                color: Colors.black54,
                                              );
                                            },
                                          ))
                                    : ClipOval(
                                        child: Image.network(
                                          item.product.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) =>
                                              const Icon(
                                            Icons.broken_image,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ),
                              ),
                              title: Text(
                                item.product.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'السعر: ${itemPrice(item.cartKey).toStringAsFixed(0)} ر.س',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  if (_variantName[item.cartKey] != null)
                                    Text(
                                      'الخيار: ${_variantName[item.cartKey]}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black38,
                                      ),
                                    ),
                                ],
                              ),

                              trailing: SizedBox(
                                width: 150,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Decrement
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _changeQuantity(item.cartKey, -1),
                                    ),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    // Increment
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.green,
                                      ),
                                      onPressed: () =>
                                          _changeQuantity(item.cartKey, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الإجمالي',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${total.toStringAsFixed(0)} ر.س',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CheckoutPage(
                                      initialCart: Map<String, int>.from(_cart),
                                      initialProducts: widget.products,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              child: const Text(
                                'إتمام الشراء',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // floating top bar moved out of padding
                    ],
                  ),
                ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(showProfile: false, showNotifications: false),
          ),
        ],
      ),
    );
  }
}

class _CartItem {
  final Product product;
  final int quantity;
  final String cartKey;

  _CartItem({required this.product, required this.quantity, required this.cartKey});
}
