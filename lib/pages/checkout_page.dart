import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'orders_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

class CheckoutPage extends StatefulWidget {
  final Map<String, int>? initialCart;
  final List<Product>? initialProducts;

  const CheckoutPage({super.key, this.initialCart, this.initialProducts});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, int> _cart = {};
  final Map<String, Product> _products = {};
  final Map<String, double> _variantPriceDelta = {};
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _shipping = 'عادي';
  String _paymentMethod = 'الدفع عند الاستلام';
  String _name = '';
  String _email = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    if (widget.initialCart != null) {
      _cart = Map<String, int>.from(widget.initialCart!);
    }
    if (widget.initialProducts != null) {
      for (final p in widget.initialProducts!) {
        _products[p.id] = p;
      }
    }
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? {};
    final Map<String, dynamic> cartData = Map<String, dynamic>.from(
      (data['cart'] as Map<String, dynamic>?) ?? {},
    );
    final String initialAddress = (data['address'] as String?) ?? '';
    final String initialPhone =
        (data['phone'] as String?) ?? (user.phoneNumber ?? '');
    _name = (data['displayName'] as String?) ?? (user.displayName ?? '');
    _email = user.email ?? '';
    _addressController.text = initialAddress;
    _phoneController.text = initialPhone;
    final loc = data['location'];
    if (loc is Map<String, dynamic>) {
      _lat = (loc['lat'] as num?)?.toDouble();
      _lng = (loc['lng'] as num?)?.toDouble();
    }
    final Map<String, int> cartFromFirestore = cartData.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    final Map<String, int> cart =
        (widget.initialCart != null && widget.initialCart!.isNotEmpty)
        ? Map<String, int>.from(widget.initialCart!)
        : cartFromFirestore;
    final Set<String> productIds = cart.keys
        .map((k) => k.split('::').first)
        .toSet();
    final List<DocumentSnapshot<Map<String, dynamic>>> productDocs = [];
    for (final id in productIds) {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .doc(id)
          .get();
      if (snap.exists) productDocs.add(snap);
    }
    for (final doc in productDocs) {
      final p = Product.fromMap(doc.id, doc.data()!);
      _products[p.id] = _products[p.id] ?? p;
    }
    for (final entry in cart.entries) {
      final parts = entry.key.split('::');
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
          final pd = (varDoc.data()!['priceDelta'] as num?)?.toDouble() ?? 0.0;
          _variantPriceDelta[entry.key] = pd;
        }
      }
    }
    setState(() {
      _cart = cart;
    });
  }

  double _shippingCost() {
    if (_shipping == 'سريع') return 20.0;
    return 10.0;
  }

  double _itemPrice(String cartKey) {
    final productId = cartKey.split('::').first;
    final base = _products[productId]?.price ?? 0.0;
    final delta = _variantPriceDelta[cartKey] ?? 0.0;
    return base + delta;
  }

  double _subtotal() {
    double t = 0.0;
    _cart.forEach((key, qty) {
      t += _itemPrice(key) * qty;
    });
    return t;
  }

  Future<void> _placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_cart.isEmpty) return;
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final subtotal = _subtotal();
    final shippingCost = _shippingCost();
    final total = subtotal + shippingCost;

    final items = _cart.entries.map((e) {
      final productId = e.key.split('::').first;
      final variantId = e.key.contains('::') ? e.key.split('::')[1] : '';
      final price = _itemPrice(e.key);
      final sellerId = _products[productId]?.publisherId ?? '';
      return {
        'productId': productId,
        'variantId': variantId,
        'qty': e.value,
        'price': price,
        'sellerId': sellerId,
      };
    }).toList();
    final sellerIds = items
        .map((m) => m['sellerId'] as String)
        .toSet()
        .toList();

    final itemTitles = items
        .map(
          (m) =>
              _products[m['productId'] as String]?.title ??
              (m['productId'] as String),
        )
        .toList();

    final orderData = {
      'userId': user.uid,
      'items': items,
      'sellerIds': sellerIds,
      'itemTitles': itemTitles,
      'subtotal': subtotal,
      'shipping': _shipping,
      'shippingCost': shippingCost,
      'total': total,
      'address': address,
      'phone': phone,
      'contactName': _name,
      'email': _email,
      'location': {'lat': _lat, 'lng': _lng},
      'paymentMethod': _paymentMethod,
      'paymentStatus': _paymentMethod == 'الدفع عند الاستلام'
          ? 'unpaid'
          : 'paid',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final orders = FirebaseFirestore.instance.collection('orders');
      await orders.add(orderData);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'cart': {},
        'address': address,
        'phone': phone,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إنشاء الطلب')));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إنشاء الطلب: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _subtotal();
    final shippingCost = _shippingCost();
    final total = subtotal + shippingCost;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      // ملخص سريع للمنتج المطلوب
                      if (_cart.isNotEmpty)
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'المنتج المطلوب',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final firstKey = _cart.keys.first;
                                    final productId = firstKey
                                        .split('::')
                                        .first;
                                    final p = _products[productId];
                                    final qty = _cart[firstKey] ?? 1;
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.grey[200],
                                          child: Text(
                                            (p?.title ?? productId)
                                                .characters
                                                .first,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p?.title ?? productId,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black45,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'الكمية: $qty',
                                                style: TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${_itemPrice(firstKey).toStringAsFixed(0)} ر.س',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'معلومات الاتصال',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_name.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      'الاسم',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 8),
                              TextField(
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  hintText: 'رقم الهاتف للتواصل',
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              if (_lat != null && _lng != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 160,
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: ll.LatLng(
                                            _lat!,
                                            _lng!,
                                          ),
                                          initialZoom: 16,
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: ll.LatLng(_lat!, _lng!),
                                                width: 40,
                                                height: 40,
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: Colors.redAccent,
                                                  size: 32,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: 8),
                              TextField(
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                                controller: _addressController,
                                decoration: InputDecoration(
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  hintText: 'أدخل عنوان التسليم',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'طريقة الدفع',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                dropdownColor: Colors.white,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                value: _paymentMethod,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'الدفع عند الاستلام',
                                    child: Text('الدفع عند الاستلام'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'بطاقة',
                                    child: Text('بطاقة'),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _paymentMethod =
                                      v ?? 'الدفع عند الاستلام',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الشحن',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                                value: _shipping,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'عادي',
                                    child: Text('عادي'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'سريع',
                                    child: Text('سريع'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _shipping = v ?? 'عادي'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${subtotal.toStringAsFixed(0)} ر.س',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                ),
                              ),
                              const Text(
                                '  : الإجمالي الجزئي',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${shippingCost.toStringAsFixed(0)} ر.س',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                ),
                              ),
                              const Text(
                                '  : الشحن',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text(
                          'تأكيد الطلب',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(showNotifications: false, showProfile: false),
          ),
        ],
      ),
    );
  }
}
