import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectFile {
  final String id;
  final String fileName;
  final String downloadUrl;
  final String uploaderName;
  final Timestamp uploadedAt;

  ProjectFile({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    required this.uploaderName,
    required this.uploadedAt,
  });

  factory ProjectFile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ProjectFile(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      uploaderName: data['uploaderName'] ?? 'Unknown',
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
    );
  }
}