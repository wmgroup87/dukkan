import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/floating_top_bar.dart';
import 'support_page.dart';
import '../services/strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
            final data = doc.data();
            final prefs = (data != null
                ? data['preferences'] as Map<String, dynamic>?
                : null);
            setState(() {
              _notificationsEnabled =
                  (prefs != null
                      ? prefs['notificationsEnabled'] as bool?
                      : null) ??
                  true;
            });
          })
          .catchError((_) {});
    }
  }

  Future<void> _saveNotifications(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'preferences': {'notificationsEnabled': enabled},
    }, SetOptions(merge: true));
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيتم حذف حسابك وجميع بياناته نهائياً. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      await user.delete();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الحساب')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حذف الحساب: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 110),
            children: [
              SwitchListTile(
                title: Text(
                  Strings.t('notifications_enable'),
                  style: const TextStyle(color: Colors.black),
                ),
                value: _notificationsEnabled,
                onChanged: (v) async {
                  setState(() => _notificationsEnabled = v);
                  await _saveNotifications(v);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.black54,
                ),
                title: Text(
                  Strings.t('privacy_policy'),
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () => _openLink('https://example.com/privacy'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.article_outlined,
                  color: Colors.black54,
                ),
                title: Text(
                  Strings.t('terms'),
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () => _openLink('https://example.com/terms'),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent, color: Colors.black54),
                title: Text(
                  Strings.t('support_contact'),
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  Strings.t('delete_account'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: _deleteAccount,
              ),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(
              showNotifications: false,
              showProfile: false,
              showBack: true,
              showLanguage: true,
            ),
          ),
        ],
      ),
    );
  }
}
