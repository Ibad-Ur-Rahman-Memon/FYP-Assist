import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority; // 'Low', 'Medium', 'High'
  final DateTime? dueDate;
  final String? assigneeId;
  final String? assigneeName;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.priority = 'Medium',
    this.dueDate,
    this.assigneeId,
    this.assigneeName,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'To-Do',
      priority: data['priority'] ?? 'Medium',
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      assigneeId: data['assigneeId'],
      assigneeName: data['assigneeName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
    };
  }
}
