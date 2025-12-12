import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:dukkan/widgets/floating_top_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../services/upload_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:dukkan/services/strings.dart';

class PublishProductPage extends StatefulWidget {
  const PublishProductPage({super.key});

  @override
  State<PublishProductPage> createState() => _PublishProductPageState();
}

class _PublishProductPageState extends State<PublishProductPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedMedia;
  String? _pickedMediaType; // image أو video

  bool _isSaving = false;

  // الأقسام المتاحة
  final List<String> _categories = [
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
  String? _selectedCategory;
  final List<_Variant> _variants = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(String type) async {
    try {
      XFile? file;
      if (type == 'image') {
        file = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        file = await _picker.pickVideo(source: ImageSource.gallery);
      }

      if (file != null) {
        setState(() {
          _pickedMedia = file;
          _pickedMediaType = type;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الوسائط: $e')),
      );
    }
  }

  Future<void> _saveProduct() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final String priceText = _priceController.text.trim();
    final String imageUrl = _imageUrlController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        priceText.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال جميع الحقول المطلوبة واختيار القسم'),
        ),
      );
      return;
    }

    final double price = double.tryParse(priceText) ?? 0;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String finalMediaType = _pickedMediaType ?? 'image';
      // Prepare base product data (without imageUrl yet)
      final Map<String, dynamic> productData = {
        'title': title,
        'description': description,
        'price': price,
        'category': _selectedCategory,
        'publisherName':
            user?.displayName ?? user?.phoneNumber ?? user?.email ?? 'مستخدم',
        'publisherId': user?.uid,
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_pickedMedia != null) {
        // Start background upload using UploadManager and immediately return to home
        final file = File(_pickedMedia!.path);
        final uid = user?.uid ?? 'anonymous';
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
        final storagePath = 'products/$uid/$filename';

        // Start upload in background
        UploadManager.instance
            .uploadProductFile(
              file: file,
              storagePath: storagePath,
              productData: productData,
              mediaType: finalMediaType,
              metadata: SettableMetadata(
                contentType: finalMediaType == 'video'
                    ? 'video/mp4'
                    : 'image/jpeg',
              ),
            )
            .catchError((e) {
              // Log but don't crash the app; home page will stop showing progress
              // ignore: avoid_print
              print('Background upload failed: $e');
            });

        // Pop back to previous (home) immediately so user sees the top progress
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // If user provided image URL instead of picking a file, publish immediately
      String finalMediaUrl = imageUrl;
      if (finalMediaUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'الرجاء اختيار صورة/فيديو أو إدخال رابط صورة للمنتج',
              ),
            ),
          );
          setState(() {
            _isSaving = false;
          });
        }
        return;
      }

      productData['imageUrl'] = finalMediaUrl;
      productData['mediaType'] = finalMediaType;
      if (finalMediaType == 'video') {
        try {
          File? localVideo;
          if (finalMediaUrl.startsWith('http')) {
            final resp = await http.get(Uri.parse(finalMediaUrl));
            final dir = await getTemporaryDirectory();
            final tmpPath = p.join(
              dir.path,
              'vid_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            localVideo = File(tmpPath);
            await localVideo.writeAsBytes(resp.bodyBytes);
          }
          final bytes = await VideoThumbnail.thumbnailData(
            video: localVideo?.path ?? finalMediaUrl,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 480,
            quality: 75,
          );
          if (bytes != null && bytes.isNotEmpty) {
            final uid = user?.uid ?? 'anonymous';
            final thumbName = '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
            final thumbRef = FirebaseStorage.instance
                .ref()
                .child('products/$uid/$thumbName');
            final snap = await thumbRef.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final thumbUrl = await snap.ref.getDownloadURL();
            productData['thumbnailUrl'] = thumbUrl;
          }
          try {
            await localVideo?.delete();
          } catch (_) {}
        } catch (_) {}
      }

      final docRef = await FirebaseFirestore.instance.collection('products').add(productData);
      if (_variants.isNotEmpty) {
        final col = docRef.collection('variants');
        for (final v in _variants) {
          await col.add({
            'name': v.name,
            'priceDelta': v.priceDelta,
            'stock': v.stock,
          });
        }
      }

      // update postsCount for the user
      if (user != null && user.uid.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'postsCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المنتج في Firestore')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء حفظ المنتج: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 110, horizontal: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    style: TextStyle(color: Colors.black54),
                    controller: _titleController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      labelText: Strings.t('product_name'),
                      labelStyle: TextStyle(color: Colors.black45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: Colors.black54),
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      labelText: Strings.t('product_desc'),
                      labelStyle: TextStyle(color: Colors.black45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: TextStyle(color: Colors.black54),
                    controller: _priceController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      labelText: Strings.t('product_price'),
                      labelStyle: TextStyle(color: Colors.black45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // اختيار القسم
                  DropdownButtonFormField<String>(
                    borderRadius: BorderRadius.circular(20),
                    isDense: true,

                    dropdownColor: Colors.white,
                    style: TextStyle(color: Colors.black54),
                    value: _selectedCategory,
                    items: _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(Strings.category(cat))),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (val) => setState(() => _selectedCategory = val),

                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black12,
                      labelText: Strings.t('category_label'),
                      labelStyle: TextStyle(color: Colors.black45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // اختيار صورة أو فيديو من الجهاز
                  Text(
                    Strings.t('media_pick'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _pickMedia('image'),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            _pickedMediaType == 'image' && _pickedMedia != null
                                ? Strings.t('image_selected')
                                : Strings.t('choose_image'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () => _pickMedia('video'),
                          icon: const Icon(Icons.videocam_outlined),
                          label: Text(
                            _pickedMediaType == 'video' && _pickedMedia != null
                                ? Strings.t('video_selected')
                                : Strings.t('choose_video'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_pickedMedia != null)
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black12,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _pickedMediaType == 'image'
                          ? Image.file(
                              File(_pickedMedia!.path),
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.videocam_outlined, size: 48),
                                const SizedBox(height: 8),
                                Text(
                                  Strings.t('video_upload_info'),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    Strings.t('options'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      ..._variants.asMap().entries.map((e) {
                        final idx = e.key;
                        final v = e.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: TextEditingController(text: v.name),
                                    decoration: const InputDecoration(hintText: 'اسم الخيار'),
                                    onChanged: (t) => setState(() => _variants[idx] = v.copyWith(name: t)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: TextEditingController(text: v.priceDelta.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: 'فرق السعر'),
                                    onChanged: (t) => setState(() => _variants[idx] = v.copyWith(priceDelta: double.tryParse(t) ?? 0.0)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: TextField(
                                    controller: TextEditingController(text: v.stock.toString()),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: 'المخزون'),
                                    onChanged: (t) => setState(() => _variants[idx] = v.copyWith(stock: int.tryParse(t) ?? 0)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => setState(() => _variants.removeAt(idx)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _variants.add(const _Variant(name: '', priceDelta: 0.0, stock: 0))),
                          icon: const Icon(Icons.add),
                          label: Text(Strings.t('add_option')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProduct,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(Strings.t('publish_product')),
                  ),
                ],
              ),
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

class _Variant {
  final String name;
  final double priceDelta;
  final int stock;
  const _Variant({required this.name, required this.priceDelta, required this.stock});
  _Variant copyWith({String? name, double? priceDelta, int? stock}) {
    return _Variant(
      name: name ?? this.name,
      priceDelta: priceDelta ?? this.priceDelta,
      stock: stock ?? this.stock,
    );
  }
}
