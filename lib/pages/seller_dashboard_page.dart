import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';

class SellerDashboardPage extends StatelessWidget {
  const SellerDashboardPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _myProducts(String uid) {
    return FirebaseFirestore.instance
        .collection('products')
        .where('publisherId', isEqualTo: uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _orders() {
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: ListView(
              children: [
                const Text('منتجاتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _myProducts(uid),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final items = snap.data!.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
                    if (items.isEmpty) return const Text('لا توجد منتجات');
                    return Column(
                      children: items
                          .map((p) => ListTile(
                                title: Text(p.title),
                                subtitle: Text('${p.price.toStringAsFixed(0)} ر.س'),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text('طلبات تحتوي على منتجاتي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _orders(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs.where((d) {
                      final sellerIds = List<String>.from((d.data()['sellerIds'] as List?) ?? []);
                      return sellerIds.contains(uid);
                    }).toList();
                    if (docs.isEmpty) return const Text('لا توجد طلبات');
                    return Column(
                      children: docs.map((d) {
                        final data = d.data();
                        final status = data['status'] as String? ?? 'pending';
                        final total = ((data['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0);
                        return ListTile(
                          title: Text('طلب ${d.id}'),
                          subtitle: Text('الحالة: $status'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$total ر.س'),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: status,
                                items: const [
                                  DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                                  DropdownMenuItem(value: 'processing', child: Text('قيد التجهيز')),
                                  DropdownMenuItem(value: 'shipped', child: Text('تم الشحن')),
                                  DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                                  DropdownMenuItem(value: 'canceled', child: Text('ملغي')),
                                ],
                                onChanged: (v) async {
                                  if (v == null) return;
                                  try {
                                    await FirebaseFirestore.instance.collection('orders').doc(d.id).update({'status': v});
                                  } catch (_) {}
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
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
