import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppLanguage {
  AppLanguage._();
  static final AppLanguage instance = AppLanguage._();

  final ValueNotifier<String> lang = ValueNotifier<String>('ar');

  TextDirection get direction =>
      lang.value == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  Future<void> set(String value) async {
    lang.value = value;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'language': value}, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}