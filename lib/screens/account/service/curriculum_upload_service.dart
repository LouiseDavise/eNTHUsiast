import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CurriculumUploadService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  Future<String> _getCurrentStudentId() async {
    final uid = _uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data();

    final studentId =
        data?['studentId']?.toString() ??
        data?['accountStudentId']?.toString();

    if (studentId == null || studentId.isEmpty) {
      throw Exception('Cannot find student ID for current user.');
    }

    return studentId;
  }

  Future<bool> pickAndUploadCurriculumPdf() async {
    final studentId = await _getCurrentStudentId();

    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return false;
    }

    final PlatformFile pickedFile = result.files.single;
    final bytes = pickedFile.bytes;

    if (bytes == null) {
      throw Exception('Cannot read selected PDF data.');
    }

    final fileName = pickedFile.name;

    if (!fileName.toLowerCase().endsWith('.pdf')) {
      throw Exception('Please upload a PDF file.');
    }

    final curriculumRef = _firestore
        .collection('ccxpUsers')
        .doc(studentId)
        .collection('curriculum')
        .doc('current');

    await curriculumRef.set({
      'studentId': studentId,
      'status': 'uploading',
      'fileName': fileName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final pdfBase64 = base64Encode(bytes);

    final callable = _functions.httpsCallable(
      'parseCurriculumPdfFromBytes',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 300),
      ),
    );

    final resultData = await callable.call({
      'fileName': fileName,
      'pdfBase64': pdfBase64,
    });

    final data = resultData.data;

    if (data is Map && data['ok'] == true) {
      return true;
    }

    throw Exception('Curriculum parser did not return success.');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurriculumStatus() async* {
    final studentId = await _getCurrentStudentId();

    yield* _firestore
        .collection('ccxpUsers')
        .doc(studentId)
        .collection('curriculum')
        .doc('current')
        .snapshots();
  }

  Future<Map<String, dynamic>?> fetchCurriculum() async {
    final studentId = await _getCurrentStudentId();

    final doc = await _firestore
        .collection('ccxpUsers')
        .doc(studentId)
        .collection('curriculum')
        .doc('current')
        .get();

    final data = doc.data();

    if (data == null) return null;

    final curriculum = data['curriculum'];

    if (curriculum is Map<String, dynamic>) {
      return curriculum;
    }

    return null;
  }
}