import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dukkan/models/product.dart';
import 'package:dukkan/services/publisher_cache.dart';

class SimpleCommentsSheet extends StatefulWidget {
  final Product product;
  final ScrollController controller;
  final String? initialReplyToCommentId;

  const SimpleCommentsSheet({
    super.key,
    required this.product,
    required this.controller,
    this.initialReplyToCommentId,
  });

  @override
  State<SimpleCommentsSheet> createState() => _SimpleCommentsSheetState();
}

class _SimpleCommentsSheetState extends State<SimpleCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final Map<String, bool> _commentLikeInProgress = {};
  final Map<String, bool> _localCommentLiked = {};
  final Map<String, int> _localCommentLikesCount = {};
  final Map<String, bool> _expandedReplies = {};
  String? _replyToCommentId;
  String? _replyToDisplayName;

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _postComment(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول للتعليق')));
      return;
    }
    final commentsRef = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .collection('comments');
    try {
      if (_replyToCommentId != null) {
        await commentsRef.doc(_replyToCommentId).collection('replies').add({
          'uid': user.uid,
          'displayName':
              user.displayName ?? user.email ?? user.phoneNumber ?? 'مستخدم',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'replyTo': _replyToDisplayName ?? '',
        });
        await commentsRef.doc(_replyToCommentId).update({
          'repliesCount': FieldValue.increment(1),
        });
      } else {
        await commentsRef.add({
          'uid': user.uid,
          'displayName':
              user.displayName ?? user.email ?? user.phoneNumber ?? 'مستخدم',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'likesCount': 0,
          'repliesCount': 0,
        });
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .update({'commentsCount': FieldValue.increment(1)});
      }
      _controller.clear();
      _replyToCommentId = null;
      _replyToDisplayName = null;
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال التعليق: $e')));
    }
  }

  Future<void> _reportComment(String commentId, String ownerUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .collection('comments')
          .doc(commentId)
          .collection('reports')
          .add({
        'reporterUid': user.uid,
        'reason': 'abuse',
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الإبلاغ عن التعليق')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الإبلاغ: $e')),
      );
    }
  }

  Future<void> _blockUser(String ownerUid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('blockedPublishers')
          .doc(ownerUid)
          .set({
        'publisherId': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حظر المستخدم')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحظر: $e')),
      );
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول للإعجاب')));
      return;
    }
    if (_commentLikeInProgress[commentId] == true) return;
    _commentLikeInProgress[commentId] = true;

    final commentRef = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .collection('comments')
        .doc(commentId);
    final likeRef = commentRef.collection('likes').doc(user.uid);
    try {
      final likeSnap = await likeRef.get();
      final serverLiked = likeSnap.exists;
      setState(() {
        final cur = _localCommentLiked[commentId] ?? serverLiked;
        _localCommentLiked[commentId] = !cur;
        final cnt = _localCommentLikesCount[commentId] ?? 0;
        _localCommentLikesCount[commentId] = !cur
            ? cnt + 1
            : (cnt > 0 ? cnt - 1 : 0);
      });
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final fresh = await tx.get(likeRef);
        if (!serverLiked && !fresh.exists) {
          tx.set(likeRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(commentRef, {'likesCount': FieldValue.increment(1)});
        } else {
          tx.delete(likeRef);
          tx.update(commentRef, {'likesCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          final cur = _localCommentLiked[commentId] ?? false;
          _localCommentLiked[commentId] = !cur;
          final cnt = _localCommentLikesCount[commentId] ?? 0;
          _localCommentLikesCount[commentId] = !cur
              ? cnt + 1
              : (cnt > 0 ? cnt - 1 : 0);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث إعجاب التعليق: $e')));
      }
    } finally {
      _commentLikeInProgress.remove(commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsRef = FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product.id)
        .collection('comments')
        .orderBy('createdAt', descending: true);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: commentsRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد تعليقات بعد.',
                      style: TextStyle(color: Colors.black),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.controller,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final commentId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final text = data['text'] as String? ?? '';
                    final uid = (data['uid'] as String?) ?? '';
                    final repliesCount = (data['repliesCount'] as int?) ?? 0;
                    final serverLikes = (data['likesCount'] as int?) ?? 0;
                    final local = _localCommentLikesCount[commentId];
                    final likesCount = local ?? serverLikes;
                    final localLiked = _localCommentLiked[commentId] ?? false;

                    final notifier = PublisherCache.instance.getNotifier(uid);
                    if (uid.isNotEmpty) {
                      PublisherCache.instance.ensureListening(uid);
                    }

                    return ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: notifier,
                      builder: (context, userDoc, _) {
                        final displayName =
                            (userDoc != null &&
                                    (userDoc['displayName'] as String?)
                                            ?.isNotEmpty ==
                                        true)
                                ? (userDoc['displayName'] as String)
                                : ((data['displayName'] as String?) ?? 'مستخدم');
                        final photoUrl = (userDoc != null)
                            ? (userDoc['photoUrl'] as String?)
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[200],
                                backgroundImage: (photoUrl != null &&
                                        photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? Text(
                                        displayName.characters.first,
                                      )
                                    : null,
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: Text(
                                text,
                                style: const TextStyle(color: Colors.black),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.reply, size: 18),
                                    label: const Text(
                                      'رد',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () {
                                      _replyToCommentId = commentId;
                                      _replyToDisplayName = displayName;
                                      FocusScope.of(context)
                                          .requestFocus(_inputFocusNode);
                                      setState(() {});
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.favorite,
                                      color:
                                          localLiked ? Colors.red : Colors.grey,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _toggleCommentLike(commentId),
                                  ),
                                  Text(
                                    likesCount.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  PopupMenuButton<String>(
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                                      PopupMenuItem(value: 'block', child: Text('حظر المستخدم')),
                                    ],
                                    onSelected: (v) {
                                      if (v == 'report') _reportComment(commentId, uid);
                                      if (v == 'block') _blockUser(uid);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (repliesCount > 0)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    final cur =
                                        _expandedReplies[commentId] ?? false;
                                    setState(() =>
                                        _expandedReplies[commentId] = !cur);
                                  },
                                  child: Text(
                                    _expandedReplies[commentId] == true
                                        ? 'إخفاء الردود ($repliesCount)'
                                        : 'عرض الردود ($repliesCount)',
                                  ),
                                ),
                              ),
                            if (_expandedReplies[commentId] == true)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 48,
                                  right: 12,
                                  bottom: 8,
                                ),
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('products')
                                      .doc(widget.product.id)
                                      .collection('comments')
                                      .doc(commentId)
                                      .collection('replies')
                                      .orderBy('createdAt', descending: false)
                                      .snapshots(),
                                  builder: (context, rSnap) {
                                    if (!rSnap.hasData) {
                                      return const SizedBox.shrink();
                                    }
                                    final rDocs = rSnap.data!.docs;
                                    if (rDocs.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: rDocs.map((rd) {
                                        final rData = rd.data()
                                            as Map<String, dynamic>;
                                        final rText =
                                            (rData['text'] as String?) ?? '';
                                        final rReplyTo =
                                            (rData['replyTo'] as String?) ?? '';
                                        final rUid =
                                            (rData['uid'] as String?) ?? '';
                                        final rNotifier = PublisherCache
                                            .instance
                                            .getNotifier(rUid);
                                        if (rUid.isNotEmpty) {
                                          PublisherCache.instance
                                              .ensureListening(rUid);
                                        }
                                        return ValueListenableBuilder<
                                            Map<String, dynamic>?>(
                                          valueListenable: rNotifier,
                                          builder: (context, rUserDoc, _) {
                                            final rName = (rUserDoc != null &&
                                                    (rUserDoc['displayName']
                                                                as String?)
                                                            ?.isNotEmpty ==
                                                        true)
                                                ? (rUserDoc['displayName']
                                                    as String)
                                                : ((rData['displayName']
                                                        as String?) ??
                                                    'مستخدم');
                                            final rPhoto = (rUserDoc != null)
                                                ? (rUserDoc['photoUrl']
                                                    as String?)
                                                : null;
                                            return ListTile(
                                              dense: true,
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    Colors.grey[200],
                                                backgroundImage: (rPhoto !=
                                                            null &&
                                                        rPhoto.isNotEmpty)
                                                    ? NetworkImage(rPhoto)
                                                    : null,
                                                child: (rPhoto == null ||
                                                        rPhoto.isEmpty)
                                                    ? Text(
                                                        rName.characters.first,
                                                      )
                                                    : null,
                                              ),
                                              title: Text(
                                                rName,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (rReplyTo.isNotEmpty)
                                                    Text(
                                                      'ردًا على: $rReplyTo',
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  Text(
                                                    rText,
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(color: Colors.black54),
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      hintText: _replyToCommentId == null
                          ? 'اكتب تعليقك'
                          : 'ردًا على: ${_replyToDisplayName ?? ''}',
                      hintStyle: TextStyle(color: Colors.black38),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isEmpty) return;
                    _postComment(text);
                  },
                  child: const Text('إرسال'),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}
