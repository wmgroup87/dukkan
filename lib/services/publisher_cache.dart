import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shared publisher document cache.
///
/// Keeps a single Firestore subscription per publisherId and exposes a
/// `ValueNotifier<Map<String,dynamic>?>` containing the latest document
/// data (or null if none). Idle entries are evicted after 5 minutes.
class PublisherCache {
  PublisherCache._() {
    _evictTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _evictOld(),
    );
  }

  static final PublisherCache instance = PublisherCache._();

  final Map<String, ValueNotifier<Map<String, dynamic>?>> _notifiers = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _subs = {};
  final Map<String, DateTime> _lastAccess = {};
  Timer? _evictTimer;

  ValueNotifier<Map<String, dynamic>?> getNotifier(String publisherId) {
    _lastAccess[publisherId] = DateTime.now();
    return _notifiers.putIfAbsent(publisherId, () => ValueNotifier(null));
  }

  void ensureListening(String publisherId) {
    if (publisherId.isEmpty) return;
    if (_subs.containsKey(publisherId)) {
      _lastAccess[publisherId] = DateTime.now();
      return;
    }

    final notifier = getNotifier(publisherId);
    final sub = FirebaseFirestore.instance
        .collection('users')
        .doc(publisherId)
        .snapshots()
        .listen(
          (snap) {
            notifier.value = snap.exists
                ? (snap.data() ?? <String, dynamic>{})
                : null;
            _lastAccess[publisherId] = DateTime.now();
          },
          onError: (e) {
            // ignore errors; keep notifier as-is
          },
        );

    _subs[publisherId] = sub;
  }

  void disposePublisher(String publisherId) {
    _subs.remove(publisherId)?.cancel();
    _notifiers.remove(publisherId)?.dispose();
    _lastAccess.remove(publisherId);
  }

  void _evictOld() {
    final now = DateTime.now();
    final expired = <String>[];
    _lastAccess.forEach((id, ts) {
      if (now.difference(ts) > const Duration(minutes: 5)) expired.add(id);
    });
    for (final id in expired) {
      disposePublisher(id);
    }
  }

  /// Optional: call on app shutdown to cancel timer and subscriptions.
  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
    for (final n in _notifiers.values) {
      n.dispose();
    }
    _notifiers.clear();
    _evictTimer?.cancel();
  }
}
