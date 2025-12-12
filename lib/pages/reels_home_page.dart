import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dukkan/models/product.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'publish_product_page.dart';
import 'chat_page.dart';
import 'package:dukkan/pages/notifications_page.dart';
import '../services/upload_manager.dart';
import 'package:dukkan/widgets/simple_comments_sheet.dart';
import 'package:dukkan/widgets/upload_status_banner.dart';
import 'package:dukkan/widgets/reels_product_pager.dart';
import 'package:dukkan/services/strings.dart';

class ReelsHomePage extends StatefulWidget {
  final String? filterPublisherId;
  final String? initialProductId;
  final bool openCommentsOnLoad;
  final String? initialReplyToCommentId;

  const ReelsHomePage({
    super.key,
    this.filterPublisherId,
    this.initialProductId,
    this.openCommentsOnLoad = false,
    this.initialReplyToCommentId,
  });

  @override
  State<ReelsHomePage> createState() => _ReelsHomePageState();
}

enum FeedFilter { all, following }

class _ReelsHomePageState extends State<ReelsHomePage> {
  final PageController _pageController = PageController();
  FeedFilter _feedFilter = FeedFilter.all;
  final Set<String> _followingIds = <String>{};
  bool _loadingFollowing = false;
  final List<String> _categories = [
    'الكل',
    'مواد التجميل',
    'الكترونيات',
    'كهربائيات',
    'البسة رجالية',
    'البسة نسائية',
    'أطفال',
    'مركبات',
    'مواد منزلية',
    'غذائية',
    'كتب وأدوات مكتبية',
    'رياضة وترفيه',
    'حيوانات أليفة',
    'ألعاب',
    'خدمات',
    'أخرى',
  ];
  String _selectedCategory = 'الكل';
  final Map<String, bool> _likeInProgress = {};
  bool _initialPageSet = false;
  final Map<String, int> _cart = {};
  String _searchQuery = '';
  bool _showSearch = false;

  Stream<List<Product>> _productsStream() {
    final baseStream = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return baseStream.asyncMap((snapshot) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _followingIds.isEmpty && !_loadingFollowing) {
        await _loadFollowingIds(user.uid);
      }
      final List<Product> products = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final product = Product.fromMap(doc.id, data);

        if (widget.filterPublisherId != null &&
            widget.filterPublisherId!.isNotEmpty &&
            product.publisherId != widget.filterPublisherId) {
          continue;
        }

        if (_selectedCategory.isNotEmpty &&
            _selectedCategory != 'الكل' &&
            product.category != _selectedCategory) {
          continue;
        }

        if (_feedFilter == FeedFilter.following &&
            user != null &&
            _followingIds.isNotEmpty &&
            !_followingIds.contains(product.publisherId)) {
          continue;
        }

        if (_searchQuery.isNotEmpty) {
          final t = product.title.toLowerCase();
          if (!t.contains(_searchQuery)) {
            continue;
          }
        }

        if (user != null) {
          try {
            final likeDoc = await doc.reference
                .collection('likes')
                .doc(user.uid)
                .get();
            product.isLiked = likeDoc.exists;
            product.isFollowed = _followingIds.contains(product.publisherId);
          } catch (_) {}
        }
        products.add(product);
      }
      return products;
    });
  }

  Future<void> _loadFollowingIds(String uid) async {
    if (_loadingFollowing) return;
    _loadingFollowing = true;
    try {
      final sub = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('followingCount')
          .get();
      _followingIds.clear();
      for (final d in sub.docs) {
        _followingIds.add(d.id);
      }
      setState(() {});
    } catch (_) {
    } finally {
      _loadingFollowing = false;
    }
  }

  Future<void> _createNotification({
    required String recipientUid,
    required Map<String, dynamic> data,
  }) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
            'actorUid': actor.uid,
            'actorName': actor.displayName ?? '',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            ...data,
          });
    } catch (_) {}
  }

  void _toggleLike(Product product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول للإعجاب بالمنتج')),
      );
      return;
    }

    if (_likeInProgress[product.id] == true) return;
    _likeInProgress[product.id] = true;

    final productRef = FirebaseFirestore.instance
        .collection('products')
        .doc(product.id);
    final likeDocRef = productRef.collection('likes').doc(user.uid);

    try {
      // Check current server-side like state for this user
      final likeSnap = await likeDocRef.get();
      final bool currentlyLiked = likeSnap.exists;

      // Optimistically update UI
      setState(() {
        product.isLiked = !currentlyLiked;
        if (!currentlyLiked) {
          product.likesCount++;
        } else {
          product.likesCount = product.likesCount > 0
              ? product.likesCount - 1
              : product.likesCount;
        }
      });

      // Apply atomic change using a transaction to avoid races
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final freshLikeSnap = await tx.get(likeDocRef);
        if (freshLikeSnap.exists && !currentlyLiked) {
          // Another client already liked in the meantime; nothing to do
          return;
        }
        if (!freshLikeSnap.exists && currentlyLiked) {
          // Another client removed the like in the meantime; nothing to do
          return;
        }

        if (!currentlyLiked) {
          tx.set(likeDocRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(productRef, {'likesCount': FieldValue.increment(1)});
          await _createNotification(
            recipientUid: product.publisherId,
            data: {
              'type': 'like',
              'productId': product.id,
              'text': 'أُعجب بمنتجك',
            },
          );
        } else {
          tx.delete(likeDocRef);
          tx.update(productRef, {'likesCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      if (mounted) {
        // revert optimistic update on failure
        setState(() {
          product.isLiked = !product.isLiked;
          if (product.isLiked) {
            product.likesCount++;
          } else {
            product.likesCount = product.likesCount > 0
                ? product.likesCount - 1
                : product.likesCount;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الإعجاب: $e')));
      }
    } finally {
      _likeInProgress.remove(product.id);
    }
  }

  void _toggleFollow(Product product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        product.publisherId.isEmpty ||
        user.uid == product.publisherId) {
      return;
    }
    final followersCountRef = FirebaseFirestore.instance
        .collection('users')
        .doc(product.publisherId)
        .collection('followersCount')
        .doc(user.uid);
    final followingCountRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('followingCount')
        .doc(product.publisherId);

    // تحقق من الحالة الحقيقية في فايربيس
    final followersDoc = await followersCountRef.get();
    final isActuallyFollowed = followersDoc.exists;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final publisherUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(product.publisherId);
      final currentUserRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      if (!isActuallyFollowed) {
        // متابعة جديدة فقط إذا لم يكن يتابع فعلاً
        batch.set(followersCountRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(followingCountRef, {
          'publisherId': product.publisherId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also update aggregate counters on user docs (merge to create field if absent)
        batch.set(publisherUserRef, {
          'followersCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
        batch.set(currentUserRef, {
          'followingCount': FieldValue.increment(1),
        }, SetOptions(merge: true));

        await batch.commit();
        // update local following cache so UI stays consistent until stream updates
        setState(() {
          product.isFollowed = true;
          _followingIds.add(product.publisherId);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تمت المتابعة')));
        }
        await _createNotification(
          recipientUid: product.publisherId,
          data: {'type': 'follow', 'text': 'بدأ بمتابعتك'},
        );
      } else {
        // إلغاء المتابعة فقط إذا كان يتابع فعلاً
        batch.delete(followersCountRef);
        batch.delete(followingCountRef);

        // decrement aggregate counters
        batch.set(publisherUserRef, {
          'followersCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
        batch.set(currentUserRef, {
          'followingCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));

        await batch.commit();
        // update local following cache so UI stays consistent until stream updates
        setState(() {
          product.isFollowed = false;
          _followingIds.remove(product.publisherId);
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم إلغاء المتابعة')));
        }
      }
    } catch (e) {
      // revert local state if something went wrong
      setState(() {
        product.isFollowed = isActuallyFollowed;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث المتابعة: $e')));
    }
  }

  void _addToCart(Product product) {
    setState(() {
      _cart.update(product.id, (q) => q + 1, ifAbsent: () => 1);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${product.title} إلى عربة التسوق'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  void _openComments(Product product, {String? initialReplyToCommentId}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return SimpleCommentsSheet(
              product: product,
              controller: controller,
              initialReplyToCommentId: initialReplyToCommentId,
            );
          },
        );
      },
    );
  }

  void _openChat(Product product) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول للمراسلة')),
      );
      return;
    }

    // Conversation id by sorted participant ids to ensure single convo between two users
    final otherUid = product.publisherId;
    if (otherUid.isEmpty || otherUid == user.uid) {
      // Cannot message self or unknown publisher
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن بدء محادثة مع هذا المستخدم')),
      );
      return;
    }

    final ids = [user.uid, otherUid]..sort();
    final convId = ids.join('_');

    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId);
    convRef
        .set({
          'participants': ids,
          'lastMessageAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .then((_) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: convId,
                otherName: product.publisherName,
              ),
            ),
          );
        })
        .catchError((e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تعذر إنشاء المحادثة: $e')));
        });
  }

  void _shareProduct(Product product) {
    final String baseText = 'شاهد هذا المنتج: ${product.title}';
    final String url = product.imageUrl;
    final String text = url.isNotEmpty ? '$baseText\n$url' : baseText;

    // Use SharePlus.instance.share() (new API)
    SharePlus.instance.share(ShareParams(text: text));

    // Record share in Firestore (increment sharesCount)
    try {
      FirebaseFirestore.instance.collection('products').doc(product.id).set({
        'sharesCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore failures for share metric
    }
  }

  void _openPublishProduct() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PublishProductPage()));
  }

  int get _cartItemsCount =>
      _cart.values.isEmpty ? 0 : _cart.values.reduce((a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _productsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('حدث خطأ في تحميل المنتجات: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final products = snapshot.data!;

        // إذا تم تمرير initialProductId من شاشة أخرى، اجعل PageView يبدأ من هذا المنتج مرة واحدة فقط
        if (!_initialPageSet &&
            widget.initialProductId != null &&
            products.isNotEmpty) {
          final idx = products.indexWhere(
            (p) => p.id == widget.initialProductId,
          );
          if (idx != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _pageController.jumpToPage(idx);
                if (widget.openCommentsOnLoad) {
                  _openComments(
                    products[idx],
                    initialReplyToCommentId: widget.initialReplyToCommentId,
                  );
                }
              }
            });
          }
          _initialPageSet = true;
        }

        Widget mainContent;
        if (products.isEmpty) {
          mainContent = const Center(
            child: Text('لا توجد منتجات بعد. قم بنشر منتج جديد.'),
          );
        } else {
          mainContent = ReelsProductPager(
            controller: _pageController,
            products: products,
            onLike: _toggleLike,
            onComment: (p) => _openComments(p),
            onShare: _shareProduct,
            onMessage: _openChat,
            onFollow: _toggleFollow,
            onAddToCart: _addToCart,
            onSearchTap: () {
              setState(() {
                _showSearch = true;
              });
            },
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              mainContent,
              // Global upload progress bar (fixed under top bar) to ensure visibility
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: const UploadStatusBanner(),
              ),
              Positioned(
                top: 120,
                left: 12,
                right: 12,
                child: Offstage(
                  offstage: !_showSearch,
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: Strings.t('search_hint'),
                        hintStyle: TextStyle(color: Colors.black45),
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
                        prefixIconColor: Colors.black54,
                        suffixIconColor: Colors.black54,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showSearch = false;
                            });
                          },
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          _searchQuery = v.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                ),
              ),
              // الشريط العلوي: اسم التطبيق + أيقونات البروفايل وعربة التسوق
              SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.filterPublisherId != null
                            ? Icons.arrow_back
                            : Icons.add,
                      ),
                      onPressed: () {
                        if (widget.filterPublisherId != null) {
                          Navigator.of(context).pop();
                        } else {
                          _openPublishProduct();
                        }
                      },
                    ),
                    const SizedBox(width: 5),
                    // Feed filter toggle
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,

                          children: [
                            if (widget.filterPublisherId == null)
                              GestureDetector(
                                onTap: () async {
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user == null) return;
                                  await _loadFollowingIds(user.uid);
                                  setState(() {
                                    _feedFilter = FeedFilter.following;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _feedFilter == FeedFilter.following
                                        ? Colors.blueAccent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    Strings.t('following_tab'),
                                    style: TextStyle(
                                      color: _feedFilter == FeedFilter.following
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            // قائمة الأقسام المنسدلة
                            Flexible(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _feedFilter == FeedFilter.all
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: DropdownButton<String>(
                                  borderRadius: BorderRadius.circular(20),
                                  value: _selectedCategory,
                                  items: _categories
                                      .map(
                                        (cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Row(
                                            children: [
                                              Text(
                                                Strings.category(cat),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      _feedFilter ==
                                                          FeedFilter.all
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
                                      setState(() {
                                        _selectedCategory = val;
                                        _feedFilter = FeedFilter.all;
                                      });
                                    }
                                  },
                                  underline: Container(),
                                  style: TextStyle(
                                    color: _feedFilter == FeedFilter.all
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  dropdownColor: Colors.blueGrey,
                                  isDense: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                    color: _feedFilter == FeedFilter.all
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  iconEnabledColor:
                                      _feedFilter == FeedFilter.all
                                      ? Colors.white
                                      : Colors.black87,
                                  alignment: Alignment.centerRight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Upload status area: thin animated bar + percent / retry
                    ValueListenableBuilder<UploadStatus>(
                      valueListenable: UploadManager.instance.status,
                      builder: (context, status, _) {
                        if (status == UploadStatus.idle) {
                          return const SizedBox.shrink();
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Thin bar that shows progress or final state
                                ValueListenableBuilder<double?>(
                                  valueListenable:
                                      UploadManager.instance.progress,
                                  builder: (context, progress, _) {
                                    final pct = (progress ?? 0.0).clamp(
                                      0.0,
                                      1.0,
                                    );
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: status == UploadStatus.failed
                                            ? Colors.redAccent
                                            : (status == UploadStatus.success
                                                  ? Colors.green
                                                  : Colors.transparent),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                              status == UploadStatus.uploading
                                              ? pct
                                              : 1.0,
                                          child: Container(
                                            color: status == UploadStatus.failed
                                                ? Colors.redAccent
                                                : (status ==
                                                          UploadStatus.success
                                                      ? Colors.green
                                                      : Colors.redAccent),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ValueListenableBuilder<double?>(
                                        valueListenable:
                                            UploadManager.instance.progress,
                                        builder: (context, progress, _) {
                                          final pct = (progress ?? 0.0).clamp(
                                            0.0,
                                            1.0,
                                          );
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[300],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value: pct,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.blueAccent),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '${(pct * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(
                                                  color: Colors.blueAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    if (status == UploadStatus.failed)
                                      TextButton.icon(
                                        onPressed: () async {
                                          try {
                                            await UploadManager.instance
                                                .retry();
                                          } catch (e) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'تعذر إعادة المحاولة: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.refresh,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'إعادة',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // تمت إزالة أيقونة البحث من الشريط العلوي لتجنب ازدحام الأيقونات
                    IconButton(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.shopping_cart_outlined),
                          if (_cartItemsCount > 0)
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
                                    _cartItemsCount.toString(),
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
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CartPage(
                              products: products,
                              cart: _cart,
                              onCartChanged: (m) => setState(() {
                                _cart.clear();
                                _cart.addAll(m);
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.filterPublisherId == null)
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
                          final unread = snap.hasData
                              ? snap.data!.docs.length
                              : 0;
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
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    if (widget.filterPublisherId == null)
                      IconButton(
                        icon: const Icon(Icons.person_outline),
                        onPressed: _openProfile,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
