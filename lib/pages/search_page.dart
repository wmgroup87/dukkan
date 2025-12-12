import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'product_reel.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String _selectedCategory = '';
  String _sort = 'الأحدث';

  Stream<QuerySnapshot<Map<String, dynamic>>> _products() {
    return FirebaseFirestore.instance
        .collection('products')
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
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: 'ابحث عن منتج'),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(
                          value: 'الأحدث',
                          child: Text('الأحدث'),
                        ),
                        DropdownMenuItem(
                          value: 'السعر ↑',
                          child: Text('السعر ↑'),
                        ),
                        DropdownMenuItem(
                          value: 'السعر ↓',
                          child: Text('السعر ↓'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _sort = v ?? 'الأحدث'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _products(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final itemsAll = snap.data!.docs
                          .map((d) => Product.fromMap(d.id, d.data()))
                          .toList();
                      final categories = itemsAll
                          .map((p) => p.category)
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList();
                      var items = itemsAll
                          .where((p) {
                            if (_query.isEmpty) return true;
                            final t = p.title.toLowerCase();
                            final c = p.category.toLowerCase();
                            return t.contains(_query) || c.contains(_query);
                          })
                          .where(
                            (p) =>
                                _selectedCategory.isEmpty ||
                                p.category == _selectedCategory,
                          )
                          .toList();
                      if (_sort == 'السعر ↑') {
                        items.sort((a, b) => a.price.compareTo(b.price));
                      } else if (_sort == 'السعر ↓') {
                        items.sort((a, b) => b.price.compareTo(a.price));
                      }
                      if (items.isEmpty) {
                        return const Center(child: Text('لا نتائج'));
                      }
                      return Column(
                        children: [
                          if (categories.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('الكل'),
                                  selected: _selectedCategory.isEmpty,
                                  onSelected: (_) =>
                                      setState(() => _selectedCategory = ''),
                                ),
                                ...categories.map(
                                  (cat) => ChoiceChip(
                                    label: Text(cat),
                                    selected: _selectedCategory == cat,
                                    onSelected: (_) =>
                                        setState(() => _selectedCategory = cat),
                                  ),
                                ),
                              ],
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final p = items[i];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      height: 360,
                                      child: ProductReel(
                                        product: p,
                                        onLike: () {},
                                        onComment: () {},
                                        onShare: () {},
                                        onMessage: () {},
                                        onFollow: () {},
                                        onAddToCart: () {},
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
