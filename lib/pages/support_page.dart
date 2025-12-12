import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/floating_top_bar.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> _email() async {
    final uri = Uri.parse(
      'mailto:support@dukkan.example?subject=دعم&body=اكتب رسالتك هنا',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نحن هنا للمساعدة. اختر الطريقة الأنسب للتواصل معنا:',
                  style: TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Colors.black54,
                  ),
                  title: const Text(
                    'البريد الإلكتروني',
                    style: TextStyle(color: Colors.black),
                  ),
                  subtitle: const Text(
                    'support@dukkan.example',
                    style: TextStyle(color: Colors.black),
                  ),
                  onTap: _email,
                ),
              ],
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(
              title: 'الدعم',
              showNotifications: false,
              showProfile: false,
              showBack: true,
            ),
          ),
        ],
      ),
    );
  }
}
