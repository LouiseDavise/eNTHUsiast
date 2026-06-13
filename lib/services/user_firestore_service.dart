import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

class UserFirestoreService {
  UserFirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String demoUid = 'demo_user_nathan';

  // =========================
  // REFERENCES
  // =========================

  DocumentReference<Map<String, dynamic>> userDoc([String? uid]) {
    return _firestore.collection('users').doc(uid ?? demoUid);
  }

  CollectionReference<Map<String, dynamic>> emailsCollection([String? uid]) {
    return userDoc(uid).collection('emails');
  }

  CollectionReference<Map<String, dynamic>> schedulesCollection([String? uid]) {
    return userDoc(uid).collection('schedules');
  }

  CollectionReference<Map<String, dynamic>> tasksCollection([String? uid]) {
    return userDoc(uid).collection('tasks');
  }

  CollectionReference<Map<String, dynamic>> graduationDataCollection([
    String? uid,
  ]) {
    return userDoc(uid).collection('graduationData');
  }

  CollectionReference<Map<String, dynamic>> transcriptsCollection([
    String? uid,
  ]) {
    return userDoc(uid).collection('transcripts');
  }

  CollectionReference<Map<String, dynamic>> savedPostsCollection([
    String? uid,
  ]) {
    return userDoc(uid).collection('savedPosts');
  }

  // =========================
  // USER PROFILE
  // users/{uid}
  // =========================

  Future<void> upsertUserProfile({
    String? uid,
    required String name,
    required String email,
    required String studentId,
    required String department,
    required String studyLevel,
    String photoUrl = '',
    String language = 'en',
    String theme = 'light',
    Map<String, dynamic> preferences = const {},
  }) async {
    final targetUid = uid ?? demoUid;
    final doc = userDoc(targetUid);
    final snapshot = await doc.get();

    final data = <String, dynamic>{
      'uid': targetUid,
      'name': name,
      'email': email,
      'studentId': studentId,
      'department': department,
      'studyLevel': studyLevel,
      'photoUrl': photoUrl,
      'language': language,
      'theme': theme,
      'preferences': preferences,
      'settings': {
        'language': language,
        'theme': theme,
        'notificationsEnabled': true,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await doc.set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile({String? uid}) async {
    final snapshot = await userDoc(uid).get();
    return snapshot.data();
  }

  Stream<Map<String, dynamic>?> watchUserProfile({String? uid}) {
    return userDoc(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<void> updateUserSettings({
    String? uid,
    String? language,
    String? theme,
    bool? notificationsEnabled,
  }) async {
    final settings = <String, dynamic>{};

    if (language != null) settings['language'] = language;
    if (theme != null) settings['theme'] = theme;
    if (notificationsEnabled != null) {
      settings['notificationsEnabled'] = notificationsEnabled;
    }

    if (settings.isEmpty) return;

    final updateData = <String, dynamic>{
      'settings': settings,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (language != null) updateData['language'] = language;
    if (theme != null) updateData['theme'] = theme;

    await userDoc(uid).set(updateData, SetOptions(merge: true));
  }

  // =========================
  // SEED ALL USER ASSETS
  // Creates:
  // users/demo_user_nathan
  // users/demo_user_nathan/emails
  // users/demo_user_nathan/schedules
  // users/demo_user_nathan/tasks
  // users/demo_user_nathan/graduationData
  // users/demo_user_nathan/transcripts
  // =========================

  Future<void> seedUserAssets({String uid = demoUid}) async {
    await _seedUserProfile(uid);
    await _seedEmails(uid);
    await _seedSchedules(uid);
    await _seedUpcomingTasks(uid);
    await _seedGraduationData(uid);
  }

  Future<void> _seedUserProfile(String uid) async {
    await upsertUserProfile(
      uid: uid,
      name: 'Nathan',
      email: 'nathan@example.com',
      studentId: '112000001',
      department: 'CS',
      studyLevel: 'BS',
      language: 'en',
      theme: 'light',
      preferences: {
        'major': 'Computer Science',
        'minor': 'Finance',
        'careerInterest': ['AI', 'Data Science', 'Blockchain'],
      },
    );
  }

  Future<void> _seedEmails(String uid) async {
    final jsonString = await rootBundle.loadString('assets/email.json');
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw StateError('assets/email.json must be a JSON array.');
    }

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      final id = (item['id'] ?? '').toString().trim();
      final docId = id.isEmpty ? _safeId(item['title'] ?? 'email') : id;

      await emailsCollection(uid).doc(docId).set({
        'id': docId,
        'sender': item['sender'] ?? '',
        'title': item['title'] ?? '',
        'snippet': item['snippet'] ?? '',
        'fullText': item['fullText'] ?? '',
        'source': 'assets/email.json',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _seedSchedules(String uid) async {
    final jsonString = await rootBundle.loadString('assets/schedule.json');
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw StateError('assets/schedule.json must be a JSON array.');
    }

    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) continue;

      final code = (item['code'] ?? 'schedule_$i').toString();
      final title = (item['title'] ?? '').toString();
      final docId = '${i}_${_safeId(code)}';

      await schedulesCollection(uid).doc(docId).set({
        'id': docId,
        'title': title,
        'courseCode': code,
        'day': item['day'],
        'startSlot': item['startSlot'],
        'duration': item['duration'],
        'bg': item['bg'],
        'border': item['border'],
        'text': item['text'],
        'source': 'assets/schedule.json',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _seedUpcomingTasks(String uid) async {
    final jsonString = await rootBundle.loadString('assets/upcoming_task.json');
    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      throw StateError('assets/upcoming_task.json must be a JSON array.');
    }

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;

      final id = (item['id'] ?? '').toString().trim();
      final docId = id.isEmpty ? _safeId(item['title'] ?? 'task') : id;

      final dueDate = (item['dueDate'] ?? '').toString();
      final time = (item['time'] ?? '00:00').toString();
      final dueAt = DateTime.tryParse('${dueDate}T$time:00');

      await tasksCollection(uid).doc(docId).set({
        'id': docId,
        'title': item['title'] ?? '',
        'courseCode': item['code'] ?? '',
        'time': time,
        'type': item['type'] ?? '',
        'dueDate': dueDate,
        'deadline': dueAt == null ? null : Timestamp.fromDate(dueAt),
        'status': item['status'] ?? 'Incomplete',
        'location': item['location'] ?? '',
        'source': 'assets/upcoming_task.json',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _seedGraduationData(String uid) async {
    final jsonString = await rootBundle.loadString(
      'assets/graduation_data.json',
    );
    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw StateError('assets/graduation_data.json must be a JSON object.');
    }

    final summary = decoded['summary'];

    if (summary is Map<String, dynamic>) {
      await graduationDataCollection(uid).doc('summary').set({
        ...summary,
        'source': 'assets/graduation_data.json',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final categories = decoded['categories'];

    if (categories is! List) return;

    for (final category in categories) {
      if (category is! Map<String, dynamic>) continue;

      final categoryTitle = (category['title'] ?? 'unknown').toString();
      final categoryDocId = 'category_${_safeId(categoryTitle)}';

      await graduationDataCollection(uid).doc(categoryDocId).set({
        'title': categoryTitle,
        'earnedCredits': category['earnedCredits'] ?? 0,
        'requiredCredits': category['requiredCredits'] ?? 0,
        'records': category['records'] ?? [],
        'source': 'assets/graduation_data.json',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final records = category['records'];
      if (records is! List) continue;

      for (var i = 0; i < records.length; i++) {
        final record = records[i];
        if (record is! Map<String, dynamic>) continue;

        final title = (record['title'] ?? 'course_$i').toString();
        final transcriptDocId =
            '${_safeId(categoryTitle)}_${i}_${_safeId(title)}';

        await transcriptsCollection(uid).doc(transcriptDocId).set({
          'id': transcriptDocId,
          'title': title,
          'courseName': title,
          'credits': record['credits'] ?? 0,
          'grade': record['grade'] ?? '',
          'status': record['status'] ?? '',
          'category': categoryTitle,
          'source': 'assets/graduation_data.json',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  // =========================
  // READ HELPERS
  // =========================

  Stream<List<Map<String, dynamic>>> watchEmails({String? uid}) {
    return emailsCollection(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchSchedules({String? uid}) {
    return schedulesCollection(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchTasks({String? uid}) {
    return tasksCollection(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchGraduationData({String? uid}) {
    return graduationDataCollection(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> watchTranscripts({String? uid}) {
    return transcriptsCollection(uid).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  Future<List<Map<String, dynamic>>> getEmails({String? uid}) async {
    final snapshot = await emailsCollection(uid).get();
    return snapshot.docs.map(_docWithId).toList();
  }

  Future<List<Map<String, dynamic>>> getSchedules({String? uid}) async {
    final snapshot = await schedulesCollection(uid).get();
    return snapshot.docs.map(_docWithId).toList();
  }

  Future<List<Map<String, dynamic>>> getTasks({String? uid}) async {
    final snapshot = await tasksCollection(uid).get();
    return snapshot.docs.map(_docWithId).toList();
  }

  Future<List<Map<String, dynamic>>> getGraduationData({String? uid}) async {
    final snapshot = await graduationDataCollection(uid).get();
    return snapshot.docs.map(_docWithId).toList();
  }

  Future<List<Map<String, dynamic>>> getTranscripts({String? uid}) async {
    final snapshot = await transcriptsCollection(uid).get();
    return snapshot.docs.map(_docWithId).toList();
  }

  // =========================
  // SAVED SOCIAL POSTS
  // users/{uid}/savedPosts/{discussionId}
  // =========================

  Future<void> saveDiscussionPost({
    String? uid,
    required String discussionId,
  }) async {
    await savedPostsCollection(uid).doc(discussionId).set({
      'discussionId': discussionId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsaveDiscussionPost({
    String? uid,
    required String discussionId,
  }) async {
    await savedPostsCollection(uid).doc(discussionId).delete();
  }

  Future<bool> isDiscussionSaved({
    String? uid,
    required String discussionId,
  }) async {
    final snapshot = await savedPostsCollection(uid).doc(discussionId).get();
    return snapshot.exists;
  }

  Stream<List<Map<String, dynamic>>> watchSavedPosts({String? uid}) {
    return savedPostsCollection(
      uid,
    ).orderBy('savedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map(_docWithId).toList();
    });
  }

  // =========================
  // INTERNAL HELPERS
  // =========================

  Map<String, dynamic> _docWithId(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {'id': doc.id, ...doc.data()};
  }

  String _safeId(Object? value) {
    final raw = value.toString().trim().toLowerCase();

    final normalized = raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (normalized.isEmpty) {
      return 'item_${DateTime.now().millisecondsSinceEpoch}';
    }

    return normalized;
  }
}
