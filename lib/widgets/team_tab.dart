import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/screens/video_conference_screen.dart';
import 'package:fyp_assist/services/firestore_service.dart';
import 'package:fyp_assist/services/storage_service.dart';
import 'package:fyp_assist/widgets/invite_supervisor_dialog.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TeamTab extends ConsumerStatefulWidget {
  final String projectId;
  const TeamTab({super.key, required this.projectId});

  @override
  ConsumerState<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends ConsumerState<TeamTab> {
  bool _isUploading = false;
  final TextEditingController _githubController = TextEditingController();

  void _uploadFile() async {
    final currentUser = ref.read(userDataProvider).value;
    if (currentUser == null) return;

    setState(() {
      _isUploading = true;
    });

// Store context-dependent objects before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(storageServiceProvider).pickAndUploadFile(
            projectId: widget.projectId,
            uploaderId: currentUser.uid,
            uploaderName: currentUser.name,
          );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _launchFileUrl(String url) async {
    // Store context-dependent objects before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Could not open file: $url')),
      );
    }
  }

  void _setGithubRepo() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(firestoreServiceProvider).updateProjectField(
            widget.projectId,
            'githubRepo',
            _githubController.text.trim(),
          );
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('GitHub repo updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  @override
  void dispose() {
    _githubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsyncValue =
        ref.watch(projectDetailsProvider(widget.projectId));
    final filesAsyncValue = ref.watch(filesStreamProvider(widget.projectId));
    final currentUser = ref.watch(userDataProvider);

    return projectAsyncValue.when(
      data: (projectData) {
        if (!projectData.exists) {
          return const Center(child: Text("Project not found."));
        }

        final project = projectData.data() as Map<String, dynamic>;
        final supervisorName = project['supervisorName'];
        final teamNames = (project['teamNames'] as Map<String, dynamic>?) ?? {};
        final githubRepo = project['githubRepo'] as String?;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
// --- SUPERVISOR SECTION ---
              Text(
                "Supervisor",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              if (supervisorName != null)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(supervisorName),
                )
              else
                ListTile(
                  title: const Text("No supervisor assigned yet."),
                  trailing: currentUser.maybeWhen(
                    data: (user) => user.role == "Student"
                        ? ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => InviteSupervisorDialog(
                                    projectId: widget.projectId),
                              );
                            },
                            child: const Text("Invite"),
                          )
                        : null,
                    orElse: () => null,
                  ),
                ),
              const SizedBox(height: 24),

// --- TEAM MEMBERS SECTION ---
              Text(
                "Team Members",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              SizedBox(
                height: 100, // Give team list a fixed height
                child: ListView.builder(
                  itemCount: teamNames.length,
                  itemBuilder: (ctx, index) {
                    final memberName = teamNames.values.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: Text(memberName),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

// --- FILE UPLOAD SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Project Files",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_isUploading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _uploadFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Upload File"),
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: filesAsyncValue.when(
                  data: (files) {
                    if (files.isEmpty) {
                      return const Center(
                          child: Text('No files uploaded yet.'));
                    }
                    return ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (ctx, index) {
                        final file = files[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.description),
                            title: Text(file.fileName),
                            subtitle: Text(
                                'Uploaded by ${file.uploaderName} on ${DateFormat.yMd().format(file.uploadedAt.toDate())}'),
                            onTap: () => _launchFileUrl(file.downloadUrl),
                          ),
                        );
                      },
                    );
                  },
                  error: (e, s) =>
                      const Center(child: Text('Could not load files.')),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 24),

              // --- VIDEO CONFERENCE SECTION ---
              Text(
                "Video Conference",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final currentUser = ref.read(userDataProvider).value;
                    if (currentUser != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => VideoConferenceScreen(
                            roomName: widget.projectId,
                            displayName: currentUser.name,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.video_call),
                  label: const Text("Start Video Meeting"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- GITHUB INTEGRATION SECTION ---
              Text(
                "GitHub Integration",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              if (githubRepo != null && githubRepo.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(githubRepo),
                  subtitle: const Text('Tap to open in browser'),
                  onTap: () => _launchFileUrl(githubRepo!),
                )
              else
                ListTile(
                  title: const Text("No GitHub repo linked yet."),
                  trailing: ElevatedButton(
                    onPressed: () {
                      _githubController.clear();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Link GitHub Repository'),
                          content: TextField(
                            controller: _githubController,
                            decoration: const InputDecoration(
                              labelText: 'GitHub Repo URL',
                              hintText: 'https://github.com/user/repo',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _setGithubRepo,
                              child: const Text('Link'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text("Link Repo"),
                  ),
                ),
            ],
          ),
        );
      },
      error: (err, stack) => Center(child: Text('Error: ${err.toString()}')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
