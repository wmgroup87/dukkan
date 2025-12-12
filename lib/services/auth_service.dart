import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: const <String>['email']);
      final GoogleSignInAuthentication auth = account.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      return FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw Exception('فشل تسجيل الدخول باستخدام Google: ${e.code}');
    }
  }

  static Future<UserCredential> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw Exception('Apple Sign-In متاح فقط على أجهزة Apple');
    }
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return FirebaseAuth.instance.signInWithCredential(oauthCredential);
  }
}
