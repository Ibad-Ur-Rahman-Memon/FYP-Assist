import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/services/firestore_service.dart';

class InviteSupervisorDialog extends ConsumerStatefulWidget {
  final String projectId;
  const InviteSupervisorDialog({super.key, required this.projectId});

  @override
  ConsumerState<InviteSupervisorDialog> createState() =>
      _InviteSupervisorDialogState();
}

class _InviteSupervisorDialogState extends ConsumerState<InviteSupervisorDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _submitInvite() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await ref.read(firestoreServiceProvider).addSupervisorToProject(
        projectId: widget.projectId,
        supervisorEmail: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
        setState(() {
          _isLoading = false;
        });
        if (result == "Supervisor added successfully!") {
          Navigator.of(context).pop(); // Close dialog on success
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Supervisor'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your supervisor's email. They must have a 'Supervisor' account."),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Supervisor Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || !value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _submitInvite,
          child: const Text('Invite'),
        ),
      ],
    );
  }
}