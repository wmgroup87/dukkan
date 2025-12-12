import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dukkan/services/strings.dart';

import 'package:dukkan/services/publisher_cache.dart';
import 'package:dukkan/models/product.dart';

class ProductReel extends StatefulWidget {
  final Product product;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMessage;
  final VoidCallback onFollow;
  final VoidCallback? onPublisherTap;
  final VoidCallback onAddToCart;
  final VoidCallback? onSearchTap;

  const ProductReel({
    super.key,
    required this.product,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onMessage,
    required this.onFollow,
    this.onPublisherTap,
    required this.onAddToCart,
    this.onSearchTap,
  });

  @override
  State<ProductReel> createState() => _ProductReelState();
}

class _ProductReelState extends State<ProductReel> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoFuture;
  String? _videoInitError;
  double? _downloadProgress;
  bool _isDownloading = false;
  File? _downloadedFile;
  bool _reporting = false;
  bool _blocking = false;

  // PublisherCache singleton manages shared listeners for publisher docs.

  @override
  void initState() {
    super.initState();
    _setupVideoIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ensure cache starts listening for this publisher when widget appears
    if (widget.product.publisherId.isNotEmpty) {
      PublisherCache.instance.ensureListening(widget.product.publisherId);
    }
  }

  @override
  void didUpdateWidget(covariant ProductReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.imageUrl != widget.product.imageUrl ||
        oldWidget.product.mediaType != widget.product.mediaType) {
      _disposeVideo();
      _setupVideoIfNeeded();
    }
  }

  void _setupVideoIfNeeded() {
    if (widget.product.mediaType == 'video' &&
        widget.product.imageUrl.isNotEmpty) {
      _videoInitError = null;
      // Use an async initializer so we can attempt to resolve storage paths
      _initializeVideoFuture = () async {
        String url = widget.product.imageUrl;

        try {
          if (!url.startsWith('http')) {
            try {
              Reference ref;
              if (url.startsWith('gs://')) {
                ref = FirebaseStorage.instance.refFromURL(url);
              } else {
                ref = FirebaseStorage.instance.ref().child(url);
              }
              final resolved = await ref.getDownloadURL();
              url = resolved;
            } catch (e) {
              // ignore resolution error; we'll try to initialize with given url
              // ignore: avoid_print
              print('Could not resolve storage path to download URL: $e');
            }
          }

          // Debug: log the final URL we are going to use for the video player
          // so you can open it in a browser or curl it to inspect headers/body.
          // ignore: avoid_print
          print('Video URL used: $url');

          _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.setVolume(0.0);
          await _videoController!.play();
        } catch (e, s) {
          _videoInitError = e.toString();
          // ignore: avoid_print
          print('Video init failed: $e');
          // ignore: avoid_print
          print(s);
          try {
            await _videoController?.dispose();
          } catch (_) {}
          _videoController = null;

          // Fallback: try downloading the video and play from file
          try {
            await _downloadAndPlayFile(url);
          } catch (e2, s2) {
            // ignore: avoid_print
            print('Download-and-play fallback failed: $e2');
            // ignore: avoid_print
            print(s2);
          }
        }
      }();
    }
  }

  Future<void> _reportProduct() async {
    if (_reporting) return;
    _reporting = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .collection('reports')
          .add({
            'reporterUid': user.uid,
            'reason': 'abuse',
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال البلاغ: $e')));
    } finally {
      _reporting = false;
    }
  }

  Future<void> _blockPublisher() async {
    if (_blocking) return;
    _blocking = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('blockedPublishers')
          .doc(widget.product.publisherId)
          .set({
            'publisherId': widget.product.publisherId,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حظر الناشر')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الحظر: $e')));
    } finally {
      _blocking = false;
    }
  }

  Future<void> _downloadAndPlayFile(String url) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        client.close();
        throw Exception('Download failed: ${streamed.statusCode}');
      }

      final tmpDir = await getTemporaryDirectory();
      final filename =
          'dukkan_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${tmpDir.path}/$filename');
      final sink = file.openWrite();

      int received = 0;
      final contentLength = streamed.contentLength;
      if (mounted) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = contentLength != null ? 0.0 : null;
        });
      }

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength != null && mounted) {
          setState(() {
            _downloadProgress = received / contentLength;
          });
        }
      }

      await sink.close();
      client.close();
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
          _downloadedFile = file;
        });
      }

      // Initialize controller from file
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0.0);
      await _videoController!.play();

      // clear any previous error state
      _videoInitError = null;
      // set _initializeVideoFuture so FutureBuilder sees completion
      _initializeVideoFuture = Future.value();
    } catch (e) {
      rethrow;
    }
  }

  void _disposeVideo() {
    _initializeVideoFuture = null;
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    // Remove any downloaded temporary file
    if (_downloadedFile != null) {
      try {
        if (_downloadedFile!.existsSync()) {
          _downloadedFile!.deleteSync();
        }
      } catch (_) {}
      _downloadedFile = null;
      _downloadProgress = null;
      _isDownloading = false;
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // صورة المنتج أو فيديو
        if (widget.product.mediaType == 'video')
          _buildVideoPlayer()
        else
          Image.network(
            widget.product.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) {
              return Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        // تظليل خفيف لقراءة النصوص
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha((0.1 * 255).round()),
                Colors.black.withAlpha((0.5 * 255).round()),
                Colors.black.withAlpha((0.9 * 255).round()),
              ],
            ),
          ),
        ),
        // المحتوى السفلي: نصوص وأزرار
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // معلومات المنتج والناشر وأزرار الشراء
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // استخدم الكاش لعرض بيانات الناشر (يعرض التحديثات فوراً ويقلّل قراءات Firestore)
                    Builder(
                      builder: (context) {
                        final notifier = PublisherCache.instance.getNotifier(
                          widget.product.publisherId,
                        );
                        // Start listening for publisher updates (no-op if already listening)
                        if (widget.product.publisherId.isNotEmpty) {
                          PublisherCache.instance.ensureListening(
                            widget.product.publisherId,
                          );
                        }

                        return ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: notifier,
                          builder: (context, data, _) {
                            String displayName = widget.product.publisherName;
                            String? photoUrl;
                            if (data != null) {
                              displayName =
                                  (data['displayName'] as String?) ??
                                  displayName;
                              photoUrl =
                                  (data['photoUrl'] as String?) ?? photoUrl;
                            }

                            return Row(
                              children: [
                                GestureDetector(
                                  onTap: widget.onPublisherTap,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white24,
                                        backgroundImage:
                                            (photoUrl != null &&
                                                photoUrl.isNotEmpty)
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child:
                                            (photoUrl == null ||
                                                photoUrl.isEmpty)
                                            ? Text(
                                                displayName.isNotEmpty
                                                    ? displayName
                                                          .characters
                                                          .first
                                                    : 'م',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: widget.onFollow,
                                  child: Text(
                                    widget.product.isFollowed
                                        ? Strings.t('following')
                                        : Strings.t('follow'),
                                    style: TextStyle(
                                      color: widget.product.isFollowed
                                          ? Colors.blueAccent
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.product.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.product.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      widget.product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.product.price.toStringAsFixed(0)} ر.س',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onAddToCart,
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: Text(
                          Strings.t('add_to_cart'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // عمود الأيقونات (إعجاب، تعليق، مشاركة، مراسلة)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReelIconButton(
                    icon: Icons.search,
                    label: Strings.t('search'),
                    onTap: () => widget.onSearchTap?.call(),
                  ),
                  const SizedBox(height: 16),
                  _ReelIconButton(
                    icon: widget.product.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.product.isLiked
                        ? Colors.redAccent
                        : Colors.white,
                    label: widget.product.likesCount.toString(),
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 12),
                  _ReelIconButton(
                    icon: Icons.comment_outlined,
                    label: widget.product.commentsCount.toString(),
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 12),
                  _ReelIconButton(
                    icon: Icons.share_outlined,
                    label: Strings.t('share'),
                    onTap: widget.onShare,
                  ),
                  const SizedBox(height: 12),
                  _ReelIconButton(
                    icon: Icons.message_outlined,
                    label: Strings.t('message'),
                    onTap: widget.onMessage,
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Text('إبلاغ عن المنتج'),
                      ),
                      PopupMenuItem(value: 'block', child: Text('حظر الناشر')),
                    ],
                    onSelected: (v) {
                      if (v == 'report') _reportProduct();
                      if (v == 'block') _blockPublisher();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null) {
      return Container(
        color: Colors.grey.shade900,
        child: Center(
          child: _videoInitError == null
              ? (_isDownloading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: _downloadProgress,
                                  strokeWidth: 6,
                                  color: Colors.redAccent,
                                  backgroundColor: Colors.white24,
                                ),
                                Center(
                                  child: Text(
                                    _downloadProgress != null
                                        ? '${(_downloadProgress! * 100).toStringAsFixed(0)}%'
                                        : '...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'جارٍ تنزيل الفيديو...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 56,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'فشل تحميل الفيديو',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeVideoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Initialization finished; controller may be null if init failed.
          if (_videoController != null) {
            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_videoController!),
                    if (_videoInitError != null)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Text(
                            'فشل تشغيل الفيديو',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          // Initialization completed but controller is null -> show error details
          return Container(
            color: Colors.grey.shade900,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image,
                    size: 56,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _videoInitError ?? 'فشل تحميل الفيديو',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            color: Colors.grey.shade900,
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 80,
                color: Colors.white54,
              ),
            ),
          );
        }
        return Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _ReelIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ReelIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color ?? Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// Small helper cache for publisher documents. Keeps a single listener per
// publisherId and exposes a ValueNotifier with the latest document data.
// Publisher cache moved to `lib/services/publisher_cache.dart`.
