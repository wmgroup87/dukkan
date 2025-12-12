import 'dart:io';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

enum UploadStatus { idle, uploading, success, failed }

class UploadManager {
  UploadManager._private();
  static final UploadManager instance = UploadManager._private();

  // Progress: null = not uploading, 0..1 = progress
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
  final ValueNotifier<String?> label = ValueNotifier<String?>(null);
  final ValueNotifier<UploadStatus> status = ValueNotifier<UploadStatus>(
    UploadStatus.idle,
  );

  // Store last attempt for retry
  File? _lastFile;
  String? _lastStoragePath;
  Map<String, dynamic>? _lastProductData;
  String? _lastMediaType;
  SettableMetadata? _lastMetadata;

  /// Upload a product file to storage and create the Firestore product doc.
  /// This method runs in background and updates [progress] and [status].
  Future<void> uploadProductFile({
    required File file,
    required String storagePath,
    required Map<String, dynamic> productData,
    required String mediaType,
    SettableMetadata? metadata,
  }) async {
    // store for retry
    _lastFile = file;
    _lastStoragePath = storagePath;
    _lastProductData = Map<String, dynamic>.from(productData);
    _lastMediaType = mediaType;
    _lastMetadata = metadata;

    progress.value = 0.0;
    label.value = 'رفع المنتج';
    status.value = UploadStatus.uploading;
    // debug log
    // ignore: avoid_print
    print('UploadManager: start uploading to $storagePath');

    final ref = FirebaseStorage.instance.ref().child(storagePath);
    try {
      UploadTask uploadTask;
      bool usedFallbackPutData = false;

      // Try putFile(), fall back to putData() on FirebaseException or snapshot failure.
      try {
        uploadTask = ref.putFile(file, metadata);
      } on FirebaseException catch (e) {
        // ignore: avoid_print
        print('putFile start failed: code=${e.code} message=${e.message}');
        final bytes = await file.readAsBytes();
        // ignore: avoid_print
        print('Attempting fallback putData, bytes=${bytes.length}');
        uploadTask = ref.putData(bytes, metadata);
        usedFallbackPutData = true;
      }

      // Listen to snapshot events to update progress
      late StreamSubscription<TaskSnapshot> sub;
      sub = uploadTask.snapshotEvents.listen(
        (snapshot) {
          final bytes = snapshot.bytesTransferred;
          final total = snapshot.totalBytes;
          if (total > 0) {
            progress.value = bytes / total;
            // debug progress
            // ignore: avoid_print
            print(
              'UploadManager: progress=${(progress.value! * 100).toStringAsFixed(0)}%',
            );
          }
        },
        onError: (e) async {
          // Snapshot stream error — try fallback once if not already done
          // ignore: avoid_print
          print('upload snapshot error: $e');
          if (!usedFallbackPutData) {
            try {
              final bytes = await file.readAsBytes();
              // ignore: avoid_print
              print('Retrying with putData fallback after snapshot error');
              await sub.cancel();
              uploadTask = ref.putData(bytes, metadata);
              usedFallbackPutData = true;
              // reattach a listener to the new task
              uploadTask.snapshotEvents.listen((s) {
                final b = s.bytesTransferred;
                final t = s.totalBytes;
                if (t > 0) progress.value = b / t;
              });
            } catch (e2) {
              // ignore: avoid_print
              print('Fallback putData also failed: $e2');
            }
          }
        },
      );

      TaskSnapshot snapshot;
      try {
        snapshot = await uploadTask;
      } on FirebaseException catch (e) {
        // If task failed and we have not yet tried fallback, attempt putData once
        // ignore: avoid_print
        print('upload task failed: code=${e.code} message=${e.message}');
        if (!usedFallbackPutData) {
          try {
            final bytes = await file.readAsBytes();
            // ignore: avoid_print
            print('Attempting putData fallback after task failure');
            await sub.cancel();
            uploadTask = ref.putData(bytes, metadata);
            usedFallbackPutData = true;
            // reattach listener
            final sub2 = uploadTask.snapshotEvents.listen((s) {
              final b = s.bytesTransferred;
              final t = s.totalBytes;
              if (t > 0) progress.value = b / t;
            });
            snapshot = await uploadTask;
            await sub2.cancel();
          } catch (e2) {
            await sub.cancel();
            // ignore: avoid_print
            print('putData fallback failed too: $e2');
            status.value = UploadStatus.failed;
            rethrow;
          }
        } else {
          await sub.cancel();
          status.value = UploadStatus.failed;
          rethrow;
        }
      }

      await sub.cancel();

      final downloadUrl = await snapshot.ref.getDownloadURL();
      _lastProductData?['imageUrl'] = downloadUrl;
      _lastProductData?['mediaType'] = mediaType;

      if (mediaType == 'video') {
        try {
          final bytes = await VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 480,
            quality: 75,
          );
          if (bytes != null && bytes.isNotEmpty) {
            final thumbRef = FirebaseStorage.instance
                .ref()
                .child('$storagePath.thumb.jpg');
            final snapThumb = await thumbRef.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final thumbUrl = await snapThumb.ref.getDownloadURL();
            _lastProductData?['thumbnailUrl'] = thumbUrl;
          }
        } catch (e) {
          // ignore: avoid_print
          print('Generate/upload video thumbnail failed: $e');
        }
      }

      // Write product doc
      await FirebaseFirestore.instance
          .collection('products')
          .add(_lastProductData!);

      // Optionally update user's postsCount if publisherId provided
      final String? uid = _lastProductData?['publisherId'] as String?;
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'postsCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      progress.value = 1.0;
      status.value = UploadStatus.success;
      // debug
      // ignore: avoid_print
      print('UploadManager: upload success, downloadUrl=$downloadUrl');
      // keep success visible a bit longer so UI can pick it up
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (e, s) {
      // Log and surface clearer message for the caller
      // ignore: avoid_print
      print('UploadManager.uploadProductFile failed: $e');
      // ignore: avoid_print
      print(s);
      status.value = UploadStatus.failed;
      rethrow;
    } finally {
      // reset after short delay to allow UI to reflect final state
      await Future.delayed(const Duration(milliseconds: 600));
      progress.value = null;
      label.value = null;
      status.value = UploadStatus.idle;
      // debug
      // ignore: avoid_print
      print('UploadManager: reset to idle');
    }
  }

  Future<void> retry() async {
    if (_lastFile == null ||
        _lastStoragePath == null ||
        _lastProductData == null ||
        _lastMediaType == null) {
      throw Exception('No last upload to retry');
    }
    return uploadProductFile(
      file: _lastFile!,
      storagePath: _lastStoragePath!,
      productData: Map<String, dynamic>.from(_lastProductData!),
      mediaType: _lastMediaType!,
      metadata: _lastMetadata,
    );
  }
}
