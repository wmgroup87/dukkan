import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherName;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _getOtherUid() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      final data = doc.data();
      if (data == null) return null;
      final raw = (data['participants'] as List?) ?? const [];
      final participants = raw.whereType<String>().toList();
      for (final id in participants) {
        if (id != currentUser.uid) return id;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createMessageNotification({
    required String recipientUid,
    required String text,
  }) async {
    final actor = FirebaseAuth.instance.currentUser;
    if (actor == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
            'type': 'message',
            'actorUid': actor.uid,
            'actorName': actor.displayName ?? '',
            'conversationId': widget.conversationId,
            'text': text,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
  }

  Future<void> _sendMessage(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لإرسال رسالة')),
      );
      return;
    }

    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    final messagesRef = convRef.collection('messages');
    final now = FieldValue.serverTimestamp();
    try {
      await messagesRef.add({'uid': user.uid, 'text': text, 'createdAt': now});
      await convRef.set({'lastMessageAt': now}, SetOptions(merge: true));
      final otherUid = await _getOtherUid();
      if (otherUid != null && otherUid.isNotEmpty) {
        await _createMessageNotification(recipientUid: otherUid, text: text);
      }
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    }
  }

  Future<void> _sendImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لإرسال صورة')),
      );
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final file = File(picked.path);

      String contentTypeFromPath(String path) {
        final ext = path.split('.').last.toLowerCase();
        if (ext == 'jpg' || ext == 'jpeg') return 'image/jpeg';
        if (ext == 'png') return 'image/png';
        if (ext == 'gif') return 'image/gif';
        return 'application/octet-stream';
      }

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('conversations')
          .child(widget.conversationId)
          .child('messages')
          .child(
            '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.${picked.path.split('.').last}',
          );

      final metadata = SettableMetadata(
        contentType: contentTypeFromPath(file.path),
      );

      try {
        final UploadTask uploadTask = storageRef.putFile(file, metadata);
        final TaskSnapshot snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        final convRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId);
        final messagesRef = convRef.collection('messages');
        final now = FieldValue.serverTimestamp();
        await messagesRef.add({
          'uid': user.uid,
          'imageUrl': downloadUrl,
          'createdAt': now,
          'type': 'image',
        });
        await convRef.set({'lastMessageAt': now}, SetOptions(merge: true));
        final otherUid = await _getOtherUid();
        if (otherUid != null && otherUid.isNotEmpty) {
          await _createMessageNotification(
            recipientUid: otherUid,
            text: 'صورة جديدة',
          );
        }
      } on FirebaseException {
        try {
          final bytes = await file.readAsBytes();
          final UploadTask fallback = storageRef.putData(bytes, metadata);
          final TaskSnapshot snap2 = await fallback;
          final downloadUrl = await snap2.ref.getDownloadURL();

          final convRef = FirebaseFirestore.instance
              .collection('conversations')
              .doc(widget.conversationId);
          final messagesRef = convRef.collection('messages');
          final now = FieldValue.serverTimestamp();
          await messagesRef.add({
            'uid': user.uid,
            'imageUrl': downloadUrl,
            'createdAt': now,
            'type': 'image',
          });
          await convRef.set({'lastMessageAt': now}, SetOptions(merge: true));
          final otherUid = await _getOtherUid();
          if (otherUid != null && otherUid.isNotEmpty) {
            await _createMessageNotification(
              recipientUid: otherUid,
              text: 'صورة جديدة',
            );
          }
        } on FirebaseException catch (e2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في التخزين (${e2.code}): ${e2.message}'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الصورة: $e')));
    }
  }

  void _openImageWithHero(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(imageUrl: url, heroTag: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId);
    final messagesQuery = convRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: messagesQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('لا توجد رسائل بعد.'));
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final text = data['text'] as String? ?? '';
                        final uid = data['uid'] as String? ?? '';
                        final img = data['imageUrl'] as String?;
                        final ts = data['createdAt'] as Timestamp?;
                        final timeStr = _formatTime(ts);
                        final isMe =
                            uid == FirebaseAuth.instance.currentUser?.uid;
                        final bubble = img != null
                            ? GestureDetector(
                                onTap: () => _openImageWithHero(img),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 260,
                                      maxHeight: 360,
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(color: Colors.black12),
                                        Hero(
                                          tag: img,
                                          child: Image.network(
                                            img,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            loadingBuilder: (ctx, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  value:
                                                      progress.expectedTotalBytes !=
                                                          null
                                                      ? progress.cumulativeBytesLoaded /
                                                            (progress
                                                                    .expectedTotalBytes ??
                                                                1)
                                                      : null,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blueAccent
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                  ),
                                ),
                              );

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                bubble,
                                const SizedBox(height: 4),
                                if (timeStr.isNotEmpty)
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 25,
                  top: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.black),
                        controller: _controller,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black12,
                          hintText: 'اكتب رسالة...',
                          hintStyle: const TextStyle(color: Colors.black38),
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black38),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        minLines: 1,
                        maxLines: 6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendImage,
                      icon: const Icon(
                        Icons.photo_outlined,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {
                        final txt = _controller.text.trim();
                        if (txt.isNotEmpty) _sendMessage(txt);
                      },
                      icon: const Icon(
                        Icons.send_outlined,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: StreamBuilder<DocumentSnapshot>(
              stream: convRef.snapshots(),
              builder: (context, convSnap) {
                String titleName = widget.otherName;
                final currentUser = FirebaseAuth.instance.currentUser;

                if (convSnap.hasData && currentUser != null) {
                  final data = convSnap.data!.data() as Map<String, dynamic>?;
                  final rawParticipants =
                      (data?['participants'] as List?) ?? const [];
                  final participants = rawParticipants
                      .whereType<String>()
                      .toList();

                  final otherUid = participants
                      .where((id) => id != currentUser.uid)
                      .cast<String>()
                      .toList()
                      .cast<String>()
                      .fold<String>('', (prev, el) => prev.isEmpty ? el : prev);

                  if (otherUid.isNotEmpty) {
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUid)
                          .snapshots(),
                      builder: (context, userSnap) {
                        String displayName = titleName;
                        if (userSnap.hasData) {
                          final userData =
                              userSnap.data!.data() as Map<String, dynamic>?;
                          final maybeName =
                              (userData?['displayName'] as String?)?.trim();
                          if (maybeName != null && maybeName.isNotEmpty) {
                            displayName = maybeName;
                          }
                        }

                        return FloatingTopBar(
                          title: 'مراسلة $displayName',
                          showNotifications: false,
                          showProfile: false,
                        );
                      },
                    );
                  }
                }

                return FloatingTopBar(
                  title: 'مراسلة $titleName',
                  showNotifications: false,
                  showProfile: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ImagePreviewPage extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const ImagePreviewPage({super.key, required this.imageUrl, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag ?? imageUrl,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
