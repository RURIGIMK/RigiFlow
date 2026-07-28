import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw AuthException('Missing Google authentication tokens.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw AuthException(e is AuthException ? e.message : 'Google sign-in failed: $e');
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (appleCredential.identityToken == null) {
        throw AuthException('Missing Apple identity token.');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } catch (e) {
      throw AuthException(e is AuthException ? e.message : 'Apple sign-in failed: $e');
    }
  }

  /// Sign up a brand-new user with email/password. Fails clearly if the
  /// email is already registered — the UI uses that to nudge toward
  /// "Log In" instead.
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyEmailError(e));
    } catch (e) {
      throw AuthException('Sign up failed: $e');
    }
  }

  /// Logs in an existing email/password user. Fails clearly if there's
  /// no account with that email — the UI uses that to nudge toward
  /// "Sign Up" instead.
  Future<UserCredential?> logInWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyEmailError(e));
    } catch (e) {
      throw AuthException('Login failed: $e');
    }
  }

  String _friendlyEmailError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-alreaxdy-in-use':
        return 'An account with that email already exists — try Log In instead.';
      case 'user-not-found':
        return 'No account found with that email — try Sign Up instead.';
      case 'wrong-password':
        return 'Incorrect password for that account.';
      case 'invalid-credential':
      // Only reached if enumeration protection is still on somewhere —
      // Firebase Console > Authentication > Settings > User actions.
        return 'Incorrect email or password.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      // Sign out failed
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}