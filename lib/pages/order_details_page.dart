import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';

class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const OrderDetailsPage({super.key, required this.orderId, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from((data['items'] as List?) ?? []);
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0.0;
    final shippingCost = (data['shippingCost'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final status = data['status'] as String? ?? 'pending';
    final paymentMethod = data['paymentMethod'] as String? ?? '';
    final paymentStatus = data['paymentStatus'] as String? ?? '';
    final address = data['address'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تفاصيل الطلب $orderId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الحالة: $status'),
                          Text('طريقة الدفع: $paymentMethod'),
                          Text('حالة الدفع: $paymentStatus'),
                          Text('العنوان: $address'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('العناصر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...items.map((it) => ListTile(
                                title: Text('منتج: ${it['productId']}'),
                                subtitle: Text((it['variantId'] as String?)?.isNotEmpty == true ? 'الخيار: ${it['variantId']}' : 'بدون خيار'),
                                trailing: Text('x${it['qty']} • ${(it['price'] as num?)?.toDouble() ?? 0.0}'),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي الجزئي'),
                              Text('${subtotal.toStringAsFixed(0)} ر.س'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الشحن'),
                              Text('${shippingCost.toStringAsFixed(0)} ر.س'),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${total.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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