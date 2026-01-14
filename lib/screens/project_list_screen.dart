import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/models/user_model.dart';
import 'package:fyp_assist/services/auth_service.dart';
import 'package:fyp_assist/services/firestore_service.dart';
import 'package:fyp_assist/services/notification_service.dart'; // Import this
import 'package:fyp_assist/widgets/create_join_dialog.dart';
import 'package:fyp_assist/screens/project_detail_screen.dart';
import 'package:fyp_assist/main.dart'; // Import for theme provider

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  @override
  void initState() {
    super.initState();
    // Save the notification token when the screen loads
    _saveNotificationToken();
  }

  void _saveNotificationToken() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final token =
          await ref.read(notificationServiceProvider).getDeviceToken();
      if (token != null) {
        print("FCM Token: $token"); // Debug print
        ref.read(firestoreServiceProvider).saveUserToken(user.uid, token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Projects"),
        actions: [
          IconButton(
            icon: Icon(themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: userData.when(
        data: (user) => _buildProjectList(context, ref, user),
        error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: userData.maybeWhen(
        data: (user) => user.role == "Student"
            ? FloatingActionButton(
                onPressed: () {
                  _showCreateOrJoinDialog(context, user);
                },
                child: const Icon(Icons.add),
              )
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildProjectList(
      BuildContext context, WidgetRef ref, UserModel user) {
    final projectsProvider = user.role == "Student"
        ? studentProjectsProvider
        : supervisorProjectsProvider;

    final projectsStream = ref.watch(projectsProvider);

    return projectsStream.when(
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const Center(
            child: Text("You are not part of any projects yet."),
          );
        }

        return ListView.builder(
          itemCount: snapshot.docs.length,
          itemBuilder: (ctx, index) {
            final project = snapshot.docs[index];
            final projectName = project['projectName'] ?? 'No Name';

            return ListTile(
              title: Text(projectName),
              subtitle: const Text('Tap to view details'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ProjectDetailScreen(
                      projectId: project.id,
                      projectName: projectName,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      error: (err, stack) => Center(child: Text("Error: ${err.toString()}")),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showCreateOrJoinDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return CreateJoinDialog(user: user);
      },
    );
  }
}
