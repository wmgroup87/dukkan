import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/pages/chat_page.dart';
import 'package:dukkan/pages/user_profile_page.dart';
import 'package:dukkan/pages/reels_home_page.dart';
import 'package:dukkan/pages/product_reel.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';

enum NotificationFilter { all, messages, follows, likes, comments }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationFilter _filter = NotificationFilter.all;
  final Map<String, String> _nameCache = {};

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<String> _getDisplayName(String uid, String fallback) async {
    if (uid.isEmpty) return fallback;
    final cached = _nameCache[uid];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final name = (data?['displayName'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        _nameCache[uid] = name;
        return name;
      }
    } catch (_) {}
    return fallback;
  }

  bool _matchesFilter(String type) {
    switch (_filter) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.messages:
        return type == 'message';
      case NotificationFilter.follows:
        return type == 'follow';
      case NotificationFilter.likes:
        return type == 'like';
      case NotificationFilter.comments:
        return type == 'comment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Stack(
          children: [
            const Center(child: Text('يجب تسجيل الدخول لعرض الإشعارات')),
          ],
        ),
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 72),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: ref.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('خطأ: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final type = (data['type'] as String?) ?? 'general';
                      return _matchesFilter(type);
                    }).toList();
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('لا توجد إشعارات متطابقة'),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final type = (data['type'] as String?) ?? 'عام';
                        final actorUid = (data['actorUid'] as String?) ?? '';
                        final actorFallback =
                            ((data['actorName'] as String?) ?? '').trim();
                        final text = (data['text'] as String?) ?? '';
                        final read = (data['read'] as bool?) ?? false;

                        Color leadingBg;
                        IconData leadingIcon;
                        switch (type) {
                          case 'message':
                            leadingIcon = Icons.message;
                            leadingBg = Colors.teal;
                            break;
                          case 'follow':
                            leadingIcon = Icons.person_add;
                            leadingBg = Colors.deepPurple;
                            break;
                          case 'like':
                            leadingIcon = Icons.favorite;
                            leadingBg = Colors.redAccent;
                            break;
                          case 'comment':
                            leadingIcon = Icons.comment;
                            leadingBg = Colors.orangeAccent;
                            break;
                          default:
                            leadingIcon = Icons.notifications;
                            leadingBg = Colors.blueGrey;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: read
                              ? Colors.white
                              : Colors.blueAccent.withOpacity(0.08),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: leadingBg,
                              child: Icon(
                                leadingIcon,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: FutureBuilder<String>(
                              future: _getDisplayName(
                                actorUid,
                                actorFallback.isNotEmpty ? actorFallback : type,
                              ),
                              builder: (context, snap) {
                                final name =
                                    snap.data ??
                                    (actorFallback.isNotEmpty
                                        ? actorFallback
                                        : type);
                                return Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black38,
                                  ),
                                );
                              },
                            ),
                            subtitle: Builder(
                              builder: (context) {
                                final ts = data['createdAt'] as Timestamp?;
                                final t = _formatTime(ts);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.black45,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (t.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            color: Colors.black38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: Icon(
                                read
                                    ? Icons.mark_email_read
                                    : Icons.mark_email_unread,
                                color: read ? Colors.grey : Colors.blueAccent,
                              ),
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                try {
                                  await doc.reference.set({
                                    'read': !read,
                                  }, SetOptions(merge: true));
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تعذر تغيير حالة الإشعار: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            onTap: () async {
                              if (!read) {
                                try {
                                  await doc.reference.set({
                                    'read': true,
                                  }, SetOptions(merge: true));
                                } catch (_) {}
                              }

                              // Navigate based on notification type
                              final notifType = (data['type'] as String?) ?? '';

                              if (notifType == 'message' &&
                                  data.containsKey('conversationId')) {
                                final convId = data['conversationId'] as String;
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        conversationId: convId,
                                        otherName: data['actorName'] ?? '',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              if ((notifType == 'like' ||
                                      notifType == 'comment') &&
                                  data.containsKey('productId')) {
                                final productId = data['productId'] as String;
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ReelsHomePage(
                                        initialProductId: productId,
                                        openCommentsOnLoad:
                                            notifType == 'comment',
                                        initialReplyToCommentId:
                                            (data['commentId'] as String?) ??
                                            '',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              if (notifType == 'follow' &&
                                  data.containsKey('actorUid')) {
                                final actorUid = data['actorUid'] as String;
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserProfilePage(userId: actorUid),
                                    ),
                                  );
                                }
                                return;
                              }

                              // Fallbacks: prefer product if available, else profile
                              if (data.containsKey('productId')) {
                                final productId = data['productId'] as String;
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) {
                                        return FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('products')
                                              .doc(productId)
                                              .get(),
                                          builder: (context, snap) {
                                            if (snap.connectionState !=
                                                ConnectionState.done) {
                                              return const Scaffold(
                                                body: Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                ),
                                              );
                                            }
                                            if (!snap.hasData ||
                                                !snap.data!.exists) {
                                              return const Scaffold(
                                                body: Center(
                                                  child: Text(
                                                    'المنتج غير موجود',
                                                  ),
                                                ),
                                              );
                                            }
                                            final prod = Product.fromMap(
                                              snap.data!.id,
                                              snap.data!.data()
                                                  as Map<String, dynamic>,
                                            );
                                            return Scaffold(
                                              backgroundColor: Colors.grey[50],
                                              body: Stack(
                                                children: [
                                                  ProductReel(
                                                    product: prod,
                                                    onLike: () {},
                                                    onComment: () {},
                                                    onShare: () {},
                                                    onMessage: () {},
                                                    onFollow: () {},
                                                    onAddToCart: () {},
                                                  ),
                                                  Positioned(
                                                    top: 0,
                                                    left: 0,
                                                    right: 0,
                                                    child: FloatingTopBar(),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  );
                                }
                                return;
                              }

                              if (data.containsKey('actorUid')) {
                                final actorUid = data['actorUid'] as String;
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserProfilePage(userId: actorUid),
                                    ),
                                  );
                                }
                                return;
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            top: 64,
            right: 12,
            child: TextButton(
              onPressed: () async {
                final batch = FirebaseFirestore.instance.batch();
                final snap = await ref.get();
                for (final d in snap.docs) {
                  batch.set(d.reference, {
                    'read': true,
                  }, SetOptions(merge: true));
                }
                try {
                  await batch.commit();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تمييز الكل كمقروء')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر تمييز الكل: $e')),
                    );
                  }
                }
              },
              child: const Text('تمييز الكل'),
            ),
          ),
          Positioned(
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
