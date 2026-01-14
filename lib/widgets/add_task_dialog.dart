import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/services/firestore_service.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  final String projectId;
  const AddTaskDialog({super.key, required this.projectId});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _priority = 'Medium';
  DateTime? _dueDate;
  String? _assigneeId;
  String? _assigneeName;

  void _submitTask() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Store context-dependent objects before async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      try {
        await ref.read(firestoreServiceProvider).addTask(
              projectId: widget.projectId,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              priority: _priority,
              dueDate: _dueDate,
              assigneeId: _assigneeId,
              assigneeName: _assigneeName,
            );
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog on success
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to add task: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectDetails = ref.watch(projectDetailsProvider(widget.projectId));
    final teamNames = projectDetails.maybeWhen(
      data: (doc) =>
          (doc.data() as Map<String, dynamic>)['teamNames']
              as Map<String, dynamic>? ??
          {},
      orElse: () => <String, dynamic>{},
    );

    return AlertDialog(
      title: const Text('Add New Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['Low', 'Medium', 'High'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _priority = newValue!;
                  });
                },
              ),
              ListTile(
                title: Text(_dueDate == null
                    ? 'Select Due Date'
                    : 'Due Date: ${_dueDate!.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDueDate(context),
              ),
              DropdownButtonFormField<String>(
                value: _assigneeId,
                decoration: const InputDecoration(labelText: 'Assign To'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Unassigned'),
                  ),
                  ...teamNames.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _assigneeId = newValue;
                    _assigneeName =
                        newValue != null ? teamNames[newValue] : null;
                  });
                },
              ),
            ],
          ),
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
                onPressed: _submitTask,
                child: const Text('Add Task'),
              ),
      ],
    );
  }
}
