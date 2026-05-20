import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/bulletin_model.dart';

class BulletinFirestoreService {
  final CollectionReference<Map<String, dynamic>> _bulletinsRef =
      FirebaseFirestore.instance.collection('bulletins');

  Stream<List<BulletinItem>> watchBulletins() {
    return _bulletinsRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(BulletinItem.fromFirestore).toList();
    });
  }
}