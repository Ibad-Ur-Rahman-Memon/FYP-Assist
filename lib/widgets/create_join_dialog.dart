import 'package:flutter/material.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/models/user_model.dart';
import 'package:fyp_assist/services/firestore_service.dart';

class CreateJoinDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const CreateJoinDialog({super.key, required this.user});

  @override
  ConsumerState<CreateJoinDialog> createState() => _CreateJoinDialogState();
}

class _CreateJoinDialogState extends ConsumerState<CreateJoinDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _projectNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _createProject() async {
    if (_projectNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a project name")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String result = await ref.read(firestoreServiceProvider).createProject(
      projectName: _projectNameController.text.trim(),
      uid: widget.user.uid,
      userName: widget.user.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
      setState(() {
        _isLoading = false;
      });
      if (result == "Project created successfully!") {
        Navigator.of(context).pop();
      }
    }
  }

  void _joinProject() async {
    if (_inviteCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an invite code")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String result = await ref.read(firestoreServiceProvider).joinProject(
      inviteCode: _inviteCodeController.text.trim(),
      uid: widget.user.uid,
      userName: widget.user.name,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
      setState(() {
        _isLoading = false;
      });
      if (result == "Joined project successfully!") {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Projects"),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Create"),
                Tab(text: "Join"),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                controller: _tabController,
                children: [
                  // Create Tab
                  Column(
                    children: [
                      TextFormField(
                        controller: _projectNameController,
                        decoration: const InputDecoration(
                          labelText: "Project Name",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _createProject,
                        child: const Text("Create Project"),
                      ),
                    ],
                  ),
                  // Join Tab
                  Column(
                    children: [
                      TextFormField(
                        controller: _inviteCodeController,
                        decoration: const InputDecoration(
                          labelText: "Invite Code",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _joinProject,
                        child: const Text("Join Project"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}