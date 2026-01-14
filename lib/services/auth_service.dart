import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to check auth state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up with Email, Password, and Role (Production-Ready)
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
    required String role, // "Student" or "Supervisor"
  }) async {
    User? user;
    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;

      if (user != null) {
        // 2. Create a user document in Firestore
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': name,
            'email': email,
            'role': role,
          });

          // --- THIS IS THE CRITICAL FIX ---
          // 3. Force sign out. This prevents the "auto-login"
          await _auth.signOut();

          return "Success";

        } catch (e) {
          // Firestore write failed! Roll back the auth user.
          await user.delete();
          return "Error: Failed to save user data. Please try again.";
        }
      }
      return "An error occurred (User object was null)";
    } on FirebaseAuthException catch (e) {
      // Auth creation failed.
      if (e.code == 'email-already-in-use') {
        return 'This email is already in use. Please log in or use a different email.';
      } else if (e.code == 'weak-password') {
        return 'The password is too weak.';
      }
      return e.message ?? "Authentication Error";
    } catch (e) {
      // Handle all other errors
      if (user != null) {
        await user.delete();
      }
      return e.toString();
    }
  }

  // Sign In with Email and Password
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print("DEBUG: Attempting to sign in with email: $email");
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("DEBUG: Sign in successful for user: ${userCredential.user?.email}");
      return "Success";
    } on FirebaseAuthException catch (e) {
      print("DEBUG: FirebaseAuthException during sign in: ${e.code} - ${e.message}");
      return e.message ?? "An error occurred";
    } catch (e) {
      print("DEBUG: Unexpected error during sign in: $e");
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Create a Riverpod provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Create a stream provider to listen to auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});