import 'package:flutter/material.dart';
import 'package:dukkan/services/app_language.dart';

class OnboardingPage extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  const OnboardingPage({
    super.key,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: AppLanguage.instance.lang,
                          builder: (context, lang, _) {
                            final label = lang == 'ar' ? 'عربي' : 'English';
                            return PopupMenuButton<String>(
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'ar', child: Text('العربية')),
                                PopupMenuItem(value: 'en', child: Text('English')),
                              ],
                              onSelected: (v) => AppLanguage.instance.set(v),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Icon(
                        Icons.shopping_bag,
                        size: 80,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'مرحباً بك في Dukkan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تسوّق منتجاتك المفضّلة بأسلوب الريلز مثل تيك توك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: onGetStarted,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                      ),
                      child: const Text('ابدأ الآن'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('تخطي إلى تسجيل الدخول'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
