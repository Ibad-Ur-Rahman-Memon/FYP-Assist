import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/screens/login_screen.dart';
import 'package:fyp_assist/screens/project_list_screen.dart';
import 'package:fyp_assist/services/auth_service.dart';
import 'package:fyp_assist/services/firestore_service.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Auth Error: $err'))),
      data: (user) {
        // 1. Agar user logged out hai, to Login Screen dikhao
        if (user == null) {
          return const LoginScreen();
        }

        // 2. Agar user logged in hai, to Database check karo
        final userDataProviderResult = ref.watch(userDataProvider);

        return userDataProviderResult.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),

          // 3. SUCCESS: Data mil gaya -> Project List dikhao
          data: (userModel) {
            return const ProjectListScreen();
          },

          // 4. ERROR: Data nahi mila (Yahi wo loop problem thi)
          // Ab hum Logout nahi karenge. Hum "Repair" button dikhayenge.
          error: (err, stack) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 50, color: Colors.orange),
                      const SizedBox(height: 10),
                      const Text(
                        "Account exists, but Profile Data is missing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Error: $err",
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          // --- MAGIC FIX LOGIC ---
                          // Ye button missing data ko create kar dega
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({
                              'uid': user.uid,
                              'name': "Recovered Student", // Default Name
                              'email': user.email,
                              'role': "Student", // Default Role
                            });
                            // Provider ko refresh karein taaki naya data dikhe
                            ref.refresh(userDataProvider);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Fail: $e")));
                          }
                        },
                        child: const Text("Create Default Profile (Repair)"),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () =>
                            ref.read(authServiceProvider).signOut(),
                        child: const Text("Log Out"),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
