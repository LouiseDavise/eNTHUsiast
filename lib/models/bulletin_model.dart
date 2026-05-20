import 'package:cloud_firestore/cloud_firestore.dart';

class BulletinItem {
  final String id;
  final String sender;
  final String title;
  final String snippet;
  final String fullText;
  final DateTime? updatedAt;

  const BulletinItem({
    required this.id,
    required this.sender,
    required this.title,
    required this.snippet,
    required this.fullText,
    required this.updatedAt,
  });

  factory BulletinItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return BulletinItem(
      id: data['id']?.toString() ?? doc.id,
      sender: data['sender']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Untitled Bulletin',
      snippet: data['snippet']?.toString() ?? '',
      fullText: data['fullText']?.toString() ?? '',
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}