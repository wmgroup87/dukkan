import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'reels_home_page.dart';
import 'chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({required this.userId, super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final int value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isFollowing = false;
  bool _loading = false;
  Stream<QuerySnapshot>? _postsStream;
  Stream<QuerySnapshot>? _postsCountStream;
  Stream<QuerySnapshot>? _followersCountStream;
  Stream<QuerySnapshot>? _followingCountStream;

  Map<String, dynamic>? _userData;
  bool _userLoading = true;

  Future<void> _loadInitial() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return;
    try {
      // Check current project's subcollection name first
      final sub1 = await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .collection('followingCount')
          .doc(widget.userId)
          .get();
      if (sub1.exists) {
        setState(() => _isFollowing = true);
        return;
      }

      // Fallback to legacy subcollection name
      final sub2 = await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .collection('following')
          .doc(widget.userId)
          .get();
      if (sub2.exists) {
        setState(() => _isFollowing = true);
        return;
      }

      // Final fallback: an array field on the user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .get();
      final data = userDoc.data();
      if (data != null && data['following'] is List) {
        final list = data['following'] as List;
        if (list.contains(widget.userId)) {
          setState(() => _isFollowing = true);
          return;
        }
      }

      setState(() => _isFollowing = false);
    } catch (_) {
      // ignore errors and leave default false
      setState(() => _isFollowing = false);
    }
  }

  Future<void> _toggleFollow() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الدخول')));
      return;
    }

    setState(() => _loading = true);
    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(current.uid)
        .collection('followingCount')
        .doc(widget.userId);
    final followerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followersCount')
        .doc(current.uid);
    final publisherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    final currentDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(current.uid);

    final newValue = !_isFollowing;
    final delta = newValue ? 1 : -1;

    try {
      await Future.wait([
        publisherDoc.set({
          'followersCount': FieldValue.increment(delta),
        }, SetOptions(merge: true)),
        currentDoc.set({
          'followingCount': FieldValue.increment(delta),
        }, SetOptions(merge: true)),
      ]);

      if (newValue) {
        await followingRef.set({
          'publisherId': widget.userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await followerRef.set({
          'uid': current.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('notifications')
              .add({
                'type': 'follow',
                'actorUid': current.uid,
                'actorName': current.displayName ?? '',
                'text': 'بدأ بمتابعتك',
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
        } catch (_) {}
      } else {
        await followingRef.delete();
        await followerRef.delete();
      }

      setState(() => _isFollowing = newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'تمت المتابعة' : 'تم إلغاء المتابعة'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث المتابعة: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUser() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (mounted) {
        setState(() {
          if (userDoc.exists) {
            _userData = userDoc.data();
          }
          _userLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLoading = false;
        });
      }
    }
  }

  Future<void> _openChatWithUser() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول للمراسلة')),
      );
      return;
    }
    final otherUid = widget.userId;
    if (otherUid.isEmpty || otherUid == current.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن مراسلة هذا المستخدم')),
      );
      return;
    }
    final ids = [current.uid, otherUid]..sort();
    final convId = ids.join('_');
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId);
    try {
      await convRef.set({
        'participants': ids,
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final otherName = (_userData?['displayName'] as String?) ?? 'مستخدم';
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatPage(conversationId: convId, otherName: otherName),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إنشاء المحادثة: $e')));
      }
    }
  }

  @override
  void didUpdateWidget(UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      setState(() {
        _isFollowing = false;
        _loading = false;
        _userData = null;
        _userLoading = true;
      });
      _loadInitial();
      _loadUser();
      _postsCountStream = FirebaseFirestore.instance
          .collection('products')
          .where('publisherId', isEqualTo: widget.userId)
          .snapshots();
      _followersCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followersCount')
          .snapshots();
      _followingCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followingCount')
          .snapshots();
      _postsStream = FirebaseFirestore.instance
          .collection('products')
          .where('publisherId', isEqualTo: widget.userId)
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadUser();
    _postsCountStream = FirebaseFirestore.instance
        .collection('products')
        .where('publisherId', isEqualTo: widget.userId)
        .snapshots();
    _followersCountStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followersCount')
        .snapshots();
    _followingCountStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('followingCount')
        .snapshots();
    _postsStream = FirebaseFirestore.instance
        .collection('products')
        .where('publisherId', isEqualTo: widget.userId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          if (_userLoading)
            const Center(child: CircularProgressIndicator())
          else if (_userData == null)
            const Center(child: Text('المستخدم غير موجود'))
          else
            Builder(
              builder: (context) {
                final displayName =
                    (_userData!['displayName'] as String?) ?? 'مستخدم';
                final photoUrl = (_userData!['photoUrl'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 100),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? Text(displayName.characters.first)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _loading ? null : _toggleFollow,
                            child: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isFollowing ? 'إلغاء المتابعة' : 'متابعة',
                                  ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _openChatWithUser,
                            child: const Text('مراسلة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Counts row: posts, followers, following (live via snapshots)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Posts count
                            StreamBuilder<QuerySnapshot>(
                              stream: _postsCountStream,
                              builder: (context, s) {
                                final postsCount = s.hasData
                                    ? s.data!.docs.length
                                    : 0;
                                return _ProfileStat(
                                  label: 'المنشورات',
                                  value: postsCount,
                                );
                              },
                            ),

                            // Followers count
                            StreamBuilder<QuerySnapshot>(
                              stream: _followersCountStream,
                              builder: (context, s) {
                                final followersCount = s.hasData
                                    ? s.data!.docs.length
                                    : 0;
                                return _ProfileStat(
                                  label: 'المتابِعون',
                                  value: followersCount,
                                );
                              },
                            ),

                            // Following count
                            StreamBuilder<QuerySnapshot>(
                              stream: _followingCountStream,
                              builder: (context, s) {
                                final followingCount = s.hasData
                                    ? s.data!.docs.length
                                    : 0;
                                return _ProfileStat(
                                  label: 'يتابع',
                                  value: followingCount,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // User's posts grid (Instagram-like)
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _postsStream,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snap.hasData) {
                              return const Center(
                                child: Text('لا توجد منشورات'),
                              );
                            }
                            final rawDocs = snap.data!.docs;
                            if (rawDocs.isEmpty) {
                              return const Center(
                                child: Text('لا توجد منشورات'),
                              );
                            }

                            // Sort posts by createdAt (newest first) locally
                            final docs = rawDocs.toList()
                              ..sort((a, b) {
                                final aData = a.data() as Map<String, dynamic>;
                                final bData = b.data() as Map<String, dynamic>;
                                final aTs = aData['createdAt'];
                                final bTs = bData['createdAt'];
                                final int aMillis = aTs is Timestamp
                                    ? aTs.millisecondsSinceEpoch
                                    : 0;
                                final int bMillis = bTs is Timestamp
                                    ? bTs.millisecondsSinceEpoch
                                    : 0;
                                return bMillis.compareTo(aMillis);
                              });

                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.0,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                    childAspectRatio: 1.0,
                                  ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final item = doc.data() as Map<String, dynamic>;
                                final imageUrl =
                                    item['imageUrl'] as String? ?? '';

                                Widget buildThumb() {
                                  final mediaType =
                                      (doc['mediaType'] as String?) ?? 'image';
                                  final thumb =
                                      (doc['thumbnailUrl'] as String?) ?? '';
                                  if (mediaType == 'video') {
                                    if (thumb.isNotEmpty) {
                                      return AspectRatio(
                                        aspectRatio: 1.0,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.zero,
                                          child: Image.network(
                                            thumb,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stack) {
                                                  return Container(
                                                    color: Colors.grey[300],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.videocam_outlined,
                                                      ),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      );
                                    }

                                    Future<Uint8List?> gen() async {
                                      try {
                                        if (imageUrl.startsWith('http')) {
                                          final resp = await http.get(
                                            Uri.parse(imageUrl),
                                          );
                                          final dir =
                                              await getTemporaryDirectory();
                                          final filePath = path.join(
                                            dir.path,
                                            'tmp_vid_${DateTime.now().millisecondsSinceEpoch}.mp4',
                                          );
                                          final file = await File(
                                            filePath,
                                          ).writeAsBytes(resp.bodyBytes);
                                          final bytes =
                                              await VideoThumbnail.thumbnailData(
                                                video: file.path,
                                                imageFormat: ImageFormat.JPEG,
                                                maxWidth: 480,
                                                quality: 75,
                                              );
                                          try {
                                            await file.delete();
                                          } catch (_) {}
                                          return bytes;
                                        } else {
                                          return await VideoThumbnail.thumbnailData(
                                            video: imageUrl,
                                            imageFormat: ImageFormat.JPEG,
                                            maxWidth: 480,
                                            quality: 75,
                                          );
                                        }
                                      } catch (_) {
                                        return null;
                                      }
                                    }

                                    return AspectRatio(
                                      aspectRatio: 1.0,
                                      child: FutureBuilder<Uint8List?>(
                                        future: gen(),
                                        builder: (context, snap) {
                                          final bytes = snap.data;
                                          if (bytes != null &&
                                              bytes.isNotEmpty) {
                                            return ClipRRect(
                                              borderRadius: BorderRadius.zero,
                                              child: Image.memory(
                                                bytes,
                                                fit: BoxFit.cover,
                                              ),
                                            );
                                          }
                                          return Container(
                                            color: Colors.black,
                                            child: const Center(
                                              child: Icon(
                                                Icons.videocam,
                                                color: Colors.white70,
                                                size: 36,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }

                                  if (imageUrl.isNotEmpty) {
                                    return AspectRatio(
                                      aspectRatio: 1.0,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.zero,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              },
                                          errorBuilder:
                                              (context, error, stack) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    );
                                  }

                                  return AspectRatio(
                                    aspectRatio: 1.0,
                                    child: Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.videocam_outlined),
                                      ),
                                    ),
                                  );
                                }

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ReelsHomePage(
                                          filterPublisherId: widget.userId,
                                          initialProductId: doc.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: buildThumb(),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
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
