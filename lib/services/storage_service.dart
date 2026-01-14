import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/models/file_model.dart'; // We'll create this

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get a stream of files for a project
  Stream<List<ProjectFile>> getFilesStream(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('files')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ProjectFile.fromFirestore(doc))
        .toList());
  }

  // Pick and upload a file
  Future<void> pickAndUploadFile({
    required String projectId,
    required String uploaderId,
    required String uploaderName,
  }) async {
    // 1. Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      try {
        // 2. Create a storage reference
        Reference storageRef = _storage
            .ref()
            .child('project_files')
            .child(projectId)
            .child(fileName);

        // 3. Upload the file
        UploadTask uploadTask = storageRef.putFile(file);

        // 4. Get the download URL
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // 5. Save file metadata to Firestore
        await _firestore
            .collection('projects')
            .doc(projectId)
            .collection('files')
            .add({
          'fileName': fileName,
          'downloadUrl': downloadUrl,
          'uploaderId': uploaderId,
          'uploaderName': uploaderName,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        throw Exception('File upload failed: $e');
      }
    } else {
      // User canceled the picker
      return;
    }
  }
}

// --- Riverpod Providers ---
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final filesStreamProvider =
StreamProvider.autoDispose.family<List<ProjectFile>, String>((ref, projectId) {
  return ref.read(storageServiceProvider).getFilesStream(projectId);
});