import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dukkan/services/strings.dart';

class ReelsTopBar extends StatelessWidget {
  final String? filterPublisherId;
  final int cartItemsCount;
  final List<String> categories;
  final String selectedCategory;
  final bool followingSelected;
  final bool showInlineSearch;
  final String? searchHint;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onOpenPublishProduct;
  final VoidCallback onOpenProfile;
  final VoidCallback onSelectFollowing;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenNotifications;

  const ReelsTopBar({
    super.key,
    required this.filterPublisherId,
    required this.cartItemsCount,
    required this.categories,
    required this.selectedCategory,
    required this.followingSelected,
    this.showInlineSearch = false,
    this.searchHint,
    this.searchQuery,
    this.onSearchChanged,
    required this.onOpenPublishProduct,
    required this.onOpenProfile,
    required this.onSelectFollowing,
    required this.onSelectAll,
    required this.onSelectCategory,
    required this.onOpenCart,
    required this.onOpenNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
          children: [
            IconButton(
              icon: Icon(
                filterPublisherId != null ? Icons.arrow_back : Icons.add,
              ),
              onPressed: () {
                if (filterPublisherId != null) {
                  Navigator.of(context).pop();
                } else {
                  onOpenPublishProduct();
                }
              },
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filterPublisherId == null)
                    GestureDetector(
                      onTap: () => onSelectFollowing(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: followingSelected
                              ? Colors.blueAccent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          Strings.t('following_tab'),
                          style: TextStyle(
                            color: followingSelected
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: !followingSelected
                          ? Colors.blueAccent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCategory,
                      items: categories
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  Text(
                                    Strings.category(cat),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: !followingSelected
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          onSelectAll();
                          onSelectCategory(val);
                        }
                      },
                      underline: Container(),
                      style: TextStyle(
                        color: !followingSelected ? Colors.white : Colors.black,
                      ),
                      dropdownColor: Colors.blueGrey,
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color:
                            !followingSelected ? Colors.white : Colors.black87,
                      ),
                      iconEnabledColor:
                          !followingSelected ? Colors.white : Colors.black87,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  if (cartItemsCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            cartItemsCount.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: onOpenCart,
            ),
            if (filterPublisherId == null)
              StreamBuilder<QuerySnapshot>(
                stream: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    return const Stream<QuerySnapshot>.empty();
                  }
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('notifications')
                      .where('read', isEqualTo: false)
                      .snapshots();
                }(),
                builder: (context, snap) {
                  final unread = snap.hasData ? snap.data!.docs.length : 0;
                  final label = unread > 99 ? '99+' : unread.toString();
                  return IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none),
                        if (unread > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    onPressed: onOpenNotifications,
                  );
                },
              ),
            if (filterPublisherId == null)
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: onOpenProfile,
              ),
          ],
        ),
            if (showInlineSearch)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: searchHint ?? 'ابحث عن منتج...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => onSearchChanged?.call(v.trim()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}