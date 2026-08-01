import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const guestUserId = 'guest_user_local';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
      : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;
  bool get isGuest => currentUser == null;
  String get currentUserId => currentUser?.uid ?? guestUserId;

  /// Strong password validator helper method
  static String? validateStrongPassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp(r'(?=.*[a-z])').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(password)) {
      return 'Password must contain at least one number.';
    }
    if (!RegExp(r'(?=.*[!@#$%^&*(),.?":{}|<>])').hasMatch(password)) {
      return 'Password must contain at least one special character.';
    }
    return null;
  }

  Future<UserCredential?> signUpWithEmail(
      String email,
      String password, {
        String? displayName,
      }) async {
    final passwordError = validateStrongPassword(password);
    if (passwordError != null) {
      throw AuthException(passwordError);
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final trimmedName = displayName?.trim();
      if (trimmedName != null && trimmedName.isNotEmpty) {
        await credential.user?.updateDisplayName(trimmedName);
        await credential.user?.reload();
        notifyListeners();
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Disconnect previous session to allow fresh account selection
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled sign-in

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } catch (e) {
      debugPrint("Google Sign-In Exception: $e");
      throw AuthException('Google Sign-In failed or was canceled.');
    }
  }

  /// Require password confirmation before signing out for password-authenticated users
  Future<void> signOutWithPasswordVerification(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      await _googleSignIn.signOut();
      await _auth.signOut();
      return;
    }

    // Check if current user signed in via Password provider
    final isPasswordUser = user.providerData.any(
          (info) => info.providerId == 'password',
    );

    if (isPasswordUser && user.email != null) {
      if (password.trim().isEmpty) {
        throw const AuthException('Password is required to sign out.');
      }

      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        // Re-authenticate user before allowing sign out
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        throw AuthException(_messageFor(e));
      }
    }

    // Proceed with sign-out
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Standard sign out (for Google users or direct sign-out flows)
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'That email address is invalid.';
      case 'weak-password':
        return 'The password is too weak. Must meet strong password requirements.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'requires-recent-login':
        return 'Please re-authenticate and try signing out again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}