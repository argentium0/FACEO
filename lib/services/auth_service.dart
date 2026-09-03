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
/// and Firestore user profile persistence.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Stream of current user state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current signed-in Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Register a new user with Email and Password.
  /// Dispatches a verification email immediately upon creation.
  /// Profile is persisted to Firestore only after verification.
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final User? user = credential.user;
      if (user != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          await user.updateDisplayName(displayName.trim());
        }

        // Send verification email
        await user.sendEmailVerification();

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
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: 'An unexpected error occurred during sign up.',
      );
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
      await user.reload();
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
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: 'An unexpected error occurred during sign in.',
      );
    }
  }

  /// Sign in using Google OAuth.
  /// Correctly retrieves idToken & accessToken, wraps into [GoogleAuthProvider.credential],
  /// and updates Firestore user document.
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
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: 'Google Sign-In failed: ${e.toString()}',
      );
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
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: 'Failed to send verification email.',
      );
    }
  }

  /// Triggers password reset email.
  Future<AuthResult> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(
        errorCode: e.code,
        errorMessage: _mapFirebaseErrorCode(e.code, e.message),
      );
    } catch (e) {
      return AuthResult.failure(
        errorCode: 'unknown-error',
        errorMessage: 'Failed to send password reset email.',
      );
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Persists/syncs verified user profile strictly to Firestore `users/{userId}` collection.
  Future<void> syncUserProfileToFirestore(User user) async {
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
