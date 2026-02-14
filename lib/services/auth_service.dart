import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for handling authentication with Google Sign-In and Firebase Auth
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn =
          googleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']);

  /// Get the current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Get the current user's UID
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  /// Check if user is signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Stream of user token changes
  Stream<User?> get idTokenChanges => _firebaseAuth.idTokenChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('Google Sign-In cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      // Save user to Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
      }

      debugPrint('Successfully signed in: ${userCredential.user?.email}');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
      debugPrint('Successfully signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  /// Disconnect Google account (revokes access)
  Future<void> disconnectGoogle() async {
    try {
      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
      debugPrint('Successfully disconnected Google account');
    } catch (e) {
      debugPrint('Error disconnecting Google: $e');
      rethrow;
    }
  }

  /// Get the current user's display name
  String? get displayName => _firebaseAuth.currentUser?.displayName;

  /// Get the current user's email
  String? get email => _firebaseAuth.currentUser?.email;

  /// Get the current user's photo URL
  String? get photoUrl => _firebaseAuth.currentUser?.photoURL;

  /// Get ID token for API calls
  Future<String?> getIdToken() async {
    return _firebaseAuth.currentUser?.getIdToken();
  }

  /// Delete the user account and all data
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Note: Data deletion (Firestore) should be handled by caller before this
      await user.delete();
      debugPrint('Successfully deleted account');
    } on FirebaseAuthException catch (e) {
      debugPrint('Error deleting account: ${e.code}');
      if (e.code == 'requires-recent-login') {
        // Prompt user to re-login
        await disconnectGoogle();
        throw Exception(
          'Please sign out and sign in again to delete your account.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  /// Save user details to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await userRef.get();

      if (doc.exists) {
        // Update existing user
        await userRef.update({
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
          'last_login': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new user
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'last_login': FieldValue.serverTimestamp(),
          'role': 'user', // Default role
          'is_active': true,
        });
      }
    } catch (e) {
      debugPrint('Error saving user to Firestore: $e');
    }
  }
}
