import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'order_details_page.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _orders() {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user?.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _orders(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('لا توجد طلبات'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                    final status = data['status'] as String? ?? 'pending';
                    final address = data['address'] as String? ?? '';
                    return Card(
                      child: ListTile(
                        title: Text('الطلب ${docs[i].id}'),
                        subtitle: Text('الحالة: $status\nالعنوان: $address'),
                        trailing: Text('${total.toStringAsFixed(0)} ر.س'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsPage(orderId: docs[i].id, data: data),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
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