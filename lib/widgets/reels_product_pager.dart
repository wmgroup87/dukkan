import 'package:flutter/material.dart';
import '../models/product.dart';
import '../pages/product_reel.dart';
import '../pages/user_profile_page.dart';

class ReelsProductPager extends StatelessWidget {
  final PageController controller;
  final List<Product> products;
  final void Function(Product) onLike;
  final void Function(Product) onComment;
  final void Function(Product) onShare;
  final void Function(Product) onMessage;
  final void Function(Product) onFollow;
  final void Function(Product) onAddToCart;
  final VoidCallback onSearchTap;

  const ReelsProductPager({
    super.key,
    required this.controller,
    required this.products,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMessage,
    required this.onFollow,
    required this.onAddToCart,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductReel(
          product: product,
          onLike: () => onLike(product),
          onComment: () => onComment(product),
          onShare: () => onShare(product),
          onMessage: () => onMessage(product),
          onFollow: () => onFollow(product),
          onPublisherTap: () {
            if (product.publisherId.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfilePage(userId: product.publisherId),
              ),
            );
          },
          onAddToCart: () => onAddToCart(product),
          onSearchTap: onSearchTap,
        );
      },
    );
  }
}