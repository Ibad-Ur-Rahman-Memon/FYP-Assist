import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/services/firestore_service.dart';
import 'package:fyp_assist/widgets/add_task_dialog.dart';
import 'package:intl/intl.dart';

class TasksTab extends ConsumerWidget {
  final String projectId;
  const TasksTab({super.key, required this.projectId});

  // Helper to get the next status
  String _getNextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'To-Do':
        return 'In-Progress';
      case 'In-Progress':
        return 'Done';
      case 'Done':
        return 'To-Do'; // Allows cycling back
      default:
        return 'To-Do';
    }
  }

  // Helper to get color for a status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'To-Do':
        return Colors.grey.shade400;
      case 'In-Progress':
        return Colors.blue.shade600;
      case 'Done':
        return Colors.green.shade600;
      default:
        return Colors.black;
    }
  }

  // Helper to get color for priority
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade400;
      case 'Medium':
        return Colors.orange.shade400;
      case 'Low':
        return Colors.green.shade400;
      default:
        return Colors.grey;
    }
  }

  // Helper to format due date
  String _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return 'No due date';
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    if (difference < 0) return 'Overdue';
    if (difference == 0) return 'Due today';
    if (difference == 1) return 'Due tomorrow';
    return 'Due in $difference days';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the task stream for this project
    final tasksAsyncValue = ref.watch(tasksStreamProvider(projectId));
    // Watch the user's data to know if they are a student
    final userData = ref.watch(userDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Since it's a stream, refresh by invalidating and refetching
          ref.invalidate(tasksStreamProvider(projectId));
        },
        child: tasksAsyncValue.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return const Center(
                child: Text('No tasks created yet. Add one to get started!'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: tasks.length,
              itemBuilder: (ctx, index) {
                final task = tasks[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(task.priority),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                task.priority,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (task.assigneeName != null) ...[
                              Icon(Icons.person,
                                  size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                task.assigneeName!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 14),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDueDate(task.dueDate),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () {
                              // Only allow Students to update status
                              if (userData.value?.role == 'Student') {
                                String nextStatus = _getNextStatus(task.status);
                                ref
                                    .read(firestoreServiceProvider)
                                    .updateTaskStatus(
                                        projectId, task.id, nextStatus);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(task.status),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                task.status,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          error: (err, stack) =>
              Center(child: Text('Error: ${err.toString()}')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),

      // Show FAB only if the user is a Student
      floatingActionButton: userData.maybeWhen(
        data: (user) {
          if (user.role == 'Student') {
            return FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddTaskDialog(projectId: projectId),
                );
              },
              child: const Icon(Icons.add),
            );
          }
          return null; // No FAB for Supervisors
        },
        orElse: () => null, // No FAB while loading
      ),
    );
  }
}
