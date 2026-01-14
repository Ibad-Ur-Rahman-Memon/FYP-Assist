import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/models/chat_message_model.dart';
import 'package:fyp_assist/models/task_model.dart';
import 'package:fyp_assist/models/user_model.dart';
import 'package:fyp_assist/services/auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- USER FUNCTIONS ---
  Future<UserModel> getUserData(String uid) async {
    final DocumentSnapshot doc =
        await _firestore.collection('users').doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception(
          'No user data found in Firestore. Please sign out and sign up again.');
    }
    return UserModel.fromFirestore(doc);
  }

  // --- NEW: Save FCM Token ---
  Future<void> saveUserToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  // --- PROJECT FUNCTIONS ---
  Stream<QuerySnapshot> getStudentProjects(String uid) {
    return _firestore
        .collection('projects')
        .where('team', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getSupervisorProjects(String uid) {
    return _firestore
        .collection('projects')
        .where('supervisorId', isEqualTo: uid)
        .snapshots();
  }

  Future<String> createProject({
    required String projectName,
    required String uid,
    required String userName,
  }) async {
    try {
      String inviteCode =
          (100000 + DateTime.now().millisecond % 900000).toString();
      Map<String, String> teamNames = {uid: userName};

      await _firestore.collection('projects').add({
        'projectName': projectName,
        'supervisorId': null,
        'supervisorName': null,
        'team': [uid],
        'teamNames': teamNames,
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return "Project created successfully!";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> joinProject({
    required String inviteCode,
    required String uid,
    required String userName,
  }) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('projects')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "Invalid invite code";
      }

      DocumentReference projectRef = querySnapshot.docs.first.reference;
      await projectRef.update({
        'team': FieldValue.arrayUnion([uid]),
        'teamNames.$uid': userName,
      });

      return "Joined project successfully!";
    } catch (e) {
      return e.toString();
    }
  }

  // --- TASK FUNCTIONS ---
  Stream<List<Task>> getTasksStream(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  Future<void> addTask({
    required String projectId,
    required String title,
    required String description,
    String priority = 'Medium',
    DateTime? dueDate,
    String? assigneeId,
    String? assigneeName,
  }) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .add({
      'title': title,
      'description': description,
      'status': 'To-Do',
      'priority': priority,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTaskStatus(
      String projectId, String taskId, String newStatus) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update({'status': newStatus});
  }

  // --- CHAT FUNCTIONS ---
  Stream<List<ChatMessage>> getChatStream(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  Future<void> sendChatMessage({
    required String projectId,
    required String text,
    required String senderId,
    required String senderName,
  }) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('chat')
        .add({
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- TEAM/SUPERVISOR FUNCTIONS ---
  Stream<DocumentSnapshot> getProjectDetailsStream(String projectId) {
    return _firestore.collection('projects').doc(projectId).snapshots();
  }

  Future<String> addSupervisorToProject({
    required String projectId,
    required String supervisorEmail,
  }) async {
    try {
      // 1. Find the supervisor by email
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: supervisorEmail)
          .where('role', isEqualTo: 'Supervisor')
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return "No supervisor found with that email.";
      }

      // 2. Get supervisor details
      final supervisor = userQuery.docs.first;
      final supervisorId = supervisor.id;
      final supervisorName = supervisor['name'];

      // 3. Update the project
      await _firestore.collection('projects').doc(projectId).update({
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
      });

      return "Supervisor added successfully!";
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateProjectField(
      String projectId, String field, dynamic value) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .update({field: value});
  }
}

// --- Riverpod Providers ---

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final userDataProvider = FutureProvider<UserModel>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw Exception("User not logged in");
  }
  return ref.read(firestoreServiceProvider).getUserData(user.uid);
});

final studentProjectsProvider = StreamProvider<QuerySnapshot>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw Exception("User not logged in");
  }
  return ref.read(firestoreServiceProvider).getStudentProjects(user.uid);
});

final supervisorProjectsProvider = StreamProvider<QuerySnapshot>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw Exception("User not logged in");
  }
  return ref.read(firestoreServiceProvider).getSupervisorProjects(user.uid);
});

final tasksStreamProvider =
    StreamProvider.autoDispose.family<List<Task>, String>((ref, projectId) {
  return ref.read(firestoreServiceProvider).getTasksStream(projectId);
});

final chatStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, projectId) {
  return ref.read(firestoreServiceProvider).getChatStream(projectId);
});

final projectDetailsProvider = StreamProvider.autoDispose
    .family<DocumentSnapshot, String>((ref, projectId) {
  return ref.read(firestoreServiceProvider).getProjectDetailsStream(projectId);
});
