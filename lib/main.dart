import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'pages/onboarding_page.dart';
import 'services/app_language.dart';
import 'pages/auth_page.dart';
import 'pages/reels_home_page.dart';
import 'pages/profile_onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DukkanApp());
}

class DukkanApp extends StatelessWidget {
  const DukkanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dukkan Reels',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.white,
        ),
      ),
      // نحافظ على اتجاه الواجهة ثابتاً، ونغيّر اتجاه حقول الإدخال في الصفحات المحددة فقط
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _showAuth = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final data = userSnap.data?.data() ?? <String, dynamic>{};
              final lang = (data['language'] as String?) ?? 'ar';
              AppLanguage.instance.lang.value = lang;
              final completed = (data['profileCompleted'] as bool?) == true;
              if (!completed) {
                return const ProfileOnboardingPage();
              }
              return const ReelsHomePage();
            },
          );
        }
        if (_showAuth) {
          return AuthPage(
            onBack: () {
              setState(() {
                _showAuth = false;
              });
            },
          );
        }
        return OnboardingPage(
          onGetStarted: () {
            setState(() {
              _showAuth = true;
            });
          },
          onSkip: () {
            setState(() {
              _showAuth = true;
            });
          },
        );
      },
    );
  }
}
