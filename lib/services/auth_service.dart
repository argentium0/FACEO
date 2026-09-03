import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Structured result object returned by [AuthService] operations.
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? errorCode;
  final String errorMessage;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.errorCode,
    required this.errorMessage,
  });

  factory AuthResult.success(User? user) {
    return AuthResult._(isSuccess: true, user: user, errorMessage: 'Success');
  }

  factory AuthResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return AuthResult._(
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

/// Core authentication service managing Firebase Auth, Google Sign-In,
/// and Firestore user profile persistence with bulletproof Web JS-interop exception wrapping.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Stream of current user state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current signed-in Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Register a new user with Email and Password.
  /// Dispatches a verification email immediately upon creation.
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          try {
            await user.updateDisplayName(displayName.trim());
          } catch (_) {}
        }

        // Send verification email
        try {
          await user.sendEmailVerification();
        } catch (_) {}

        return AuthResult.failure(
          errorCode: 'email-not-verified',
          errorMessage:
              'Account created! A verification link has been sent to $email. Please verify your email before logging in.',
        );
      }

      return AuthResult.failure(
        errorCode: 'user-creation-failed',
        errorMessage: 'Failed to create user session.',
      );
    } catch (e, stack) {
      return _handleAuthException(e, stack);
    }
  }

  /// Sign in with Email and Password.
  /// Enforces email verification check before granting access and writing profile to Firestore.
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? user = credential.user;
      if (user == null) {
        return AuthResult.failure(
          errorCode: 'user-not-found',
          errorMessage: 'No user account found for the given credentials.',
        );
      }

      // Reload to ensure fresh emailVerified state
      try {
        await user.reload();
      } catch (_) {}
      
      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser != null && !refreshedUser.emailVerified) {
        return AuthResult.failure(
          errorCode: 'email-not-verified',
          errorMessage:
              'Email is not verified. Please check your inbox and verify your email.',
        );
      }

      // Save or update verified user profile in Firestore
      if (refreshedUser != null) {
        await syncUserProfileToFirestore(refreshedUser);
      }

      return AuthResult.success(refreshedUser);
    } catch (e, stack) {
      return _handleAuthException(e, stack);
    }
  }

  /// Sign in using Google OAuth.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure(
          errorCode: 'google-sign-in-cancelled',
          errorMessage: 'Google Sign-In was cancelled by the user.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        return AuthResult.failure(
          errorCode: 'missing-google-tokens',
          errorMessage: 'Failed to retrieve authentication tokens from Google.',
        );
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        await syncUserProfileToFirestore(user);
        return AuthResult.success(user);
      }

      return AuthResult.failure(
        errorCode: 'google-sign-in-failed',
        errorMessage: 'Could not complete Google Sign-In with Firebase.',
      );
    } catch (e, stack) {
      return _handleAuthException(e, stack);
    }
  }

  /// Resends email verification link to current unverified user.
  Future<AuthResult> sendEmailVerification() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure(
          errorCode: 'no-current-user',
          errorMessage: 'No authenticated user found.',
        );
      }
      await user.sendEmailVerification();
      return AuthResult.success(user);
    } catch (e, stack) {
      return _handleAuthException(e, stack);
    }
  }

  /// Triggers password reset email.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } catch (e, stack) {
      return _handleAuthException(e, stack);
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (_) {}
  }

  /// Persists/syncs verified user profile strictly to Firestore `users/{userId}` collection.
  Future<void> syncUserProfileToFirestore(User user) async {
    try {
      final DocumentReference userRef = _firestore
          .collection('users')
          .doc(user.uid);

      final Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'emailVerified': user.emailVerified,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final DocumentSnapshot doc = await userRef.get();
      if (!doc.exists) {
        userData['createdAt'] = FieldValue.serverTimestamp();
      }

      await userRef.set(userData, SetOptions(merge: true));
    } catch (e) {
      // Quietly log Firestore sync error on web without breaking main auth flow
      // Prevent permission-denied / network error from crashing the Web JS interop layer
    }
  }

  /// Safely handles all Firebase and generic Dart/JS errors without throwing
  /// unhandled subtype exceptions across JS-interop boundaries.
  AuthResult _handleAuthException(Object e, StackTrace stack) {
    if (e is FirebaseAuthException) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } else if (e is FirebaseException) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } else {
      final String str = e.toString();
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: str.contains('invalid-credential')
            ? 'Invalid email or password.'
            : (str.contains('user-not-found')
                ? 'No account found matching this email.'
                : 'Authentication failed. Please check your network and try again.'),
      );
    }
  }

  /// Translates raw Firebase error codes into user-friendly messages.
  String _mapFirebaseErrorCode(String code, String? fallbackMessage) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is improperly formatted.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found matching this email.';
      case 'wrong-password':
        return 'Incorrect password entered.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'operation-not-allowed':
        return 'This authentication method is disabled.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid credentials provided. Check your email and password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return fallbackMessage ??
            'An error occurred. Please try again (Error code: $code).';
    }
  }
}
