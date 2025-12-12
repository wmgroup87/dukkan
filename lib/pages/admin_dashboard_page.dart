import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 12, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs;
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();
                          final title = data['title'] as String? ?? d.id;
                          return Card(
                            child: ListTile(
                              title: Text(title),
                              subtitle: Text('السعر: ${((data['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)} ر.س'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance.collection('products').doc(d.id).delete();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنتج')));
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف المنتج: $e')));
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
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