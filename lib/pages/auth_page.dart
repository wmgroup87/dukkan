import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:dukkan/widgets/floating_top_bar.dart';
import '../services/auth_service.dart';
import 'profile_onboarding_page.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onBack;

  const AuthPage({super.key, required this.onBack});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleSignIn(
    Future<UserCredential> Function() signInMethod,
  ) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await signInMethod();
      await _afterSignIn();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _afterSignIn() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(u.uid);
      final snap = await userRef.get();
      Map<String, dynamic> data = snap.data() ?? {};
      if (data.isEmpty) {
        data = {
          'uid': u.uid,
          'displayName': u.displayName ?? '',
          'photoUrl': u.photoURL ?? '',
          'email': u.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'profileCompleted': false,
        };
        await userRef.set(data, SetOptions(merge: true));
      }
      final completed = (data['profileCompleted'] as bool?) == true;
      if (!completed) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileOnboardingPage()),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF5F7FA), Color(0xFFE4ECF7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                const Text(
                                  'اختر طريقة تسجيل الدخول',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_error != null) ...[
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handleSignIn(
                                          AuthService.signInWithGoogle,
                                        ),
                                  icon: const Icon(Icons.g_mobiledata),
                                  label: const Text(
                                    'تسجيل الدخول باستخدام Google',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Color(0xFFE0E0E0),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handleSignIn(
                                          AuthService.signInWithApple,
                                        ),
                                  icon: const Icon(Icons.apple),
                                  label: const Text(
                                    'تسجيل الدخول باستخدام Apple',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                      ),
                                      child: Text(
                                        'أو',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'سجل الدخول برقم الهاتف',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                PhoneAuthSection(onSignedIn: _afterSignIn),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FloatingTopBar(
              showNotifications: false,
              showBack: false,
              showProfile: false,
            ),
          ),
        ],
      ),
    );
  }
}

class PhoneAuthSection extends StatefulWidget {
  final Future<void> Function() onSignedIn;
  const PhoneAuthSection({super.key, required this.onSignedIn});

  @override
  State<PhoneAuthSection> createState() => _PhoneAuthSectionState();
}

class _PhoneAuthSectionState extends State<PhoneAuthSection> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _fullPhone = '';

  String? _verificationId;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  String? _status;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSendingCode = true;
      _status = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhone.isNotEmpty
            ? _fullPhone
            : _phoneController.text.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await widget.onSignedIn();
          } on FirebaseAuthException catch (e) {
            setState(() {
              _status = e.message;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _status = e.message;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _status = 'تم إرسال رمز التحقق';
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) {
      return;
    }
    setState(() {
      _isVerifyingCode = true;
      _status = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await widget.onSignedIn();
      if (mounted) {
        setState(() {
          _status = 'تم تسجيل الدخول بنجاح';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntlPhoneField(
          controller: _phoneController,
          initialCountryCode: 'IQ',
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          dropdownTextStyle: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.black38),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.black38),
            ),
            hintText: 'رقم الهاتف',
            hintStyle: TextStyle(color: Colors.black54, fontSize: 12),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (phone) => _fullPhone = phone.completeNumber,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSendingCode ? null : _sendCode,
          child: _isSendingCode
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إرسال رمز التحقق'),
        ),
        const SizedBox(height: 8),
        if (_verificationId != null) ...[
          PinCodeTextField(
            appContext: context,
            controller: _codeController,
            length: 6,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            enableActiveFill: true,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(12),
              fieldHeight: 50,
              fieldWidth: 44,
              activeFillColor: Colors.white,
              inactiveFillColor: Colors.white,
              selectedFillColor: Colors.white,
              inactiveColor: Colors.black38,
              activeColor: Colors.blueAccent,
              selectedColor: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isVerifyingCode ? null : _verifyCode,
            child: _isVerifyingCode
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تأكيد الرمز'),
          ),
        ],
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(_status!, style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }
}
