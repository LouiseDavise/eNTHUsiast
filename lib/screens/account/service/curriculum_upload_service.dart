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

  DocumentReference<Map<String, dynamic>> get _ccxpUserRef {
    return _firestore.collection('ccxpUsers').doc(_uid);
  }

  DocumentReference<Map<String, dynamic>> get _curriculumRef {
    return _ccxpUserRef.collection('curriculum').doc('current');
  }

  String? _studentIdFromEmail(String? email) {
    if (email == null) return null;

    final prefix = email.split('@').first.trim();
    final looksLikeStudentId = RegExp(r'^\d{6,12}$').hasMatch(prefix);

    return looksLikeStudentId ? prefix : null;
  }

  Future<String> _getCurrentStudentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final doc = await _ccxpUserRef.get();
    final data = doc.data();

    final savedStudentId =
        data?['studentId']?.toString() ??
        data?['accountStudentId']?.toString();

    if (savedStudentId != null && savedStudentId.trim().isNotEmpty) {
      return savedStudentId.trim();
    }

    // Fallback for the new Firebase Auth flow:
    // user.email should look like 113006203@school.edu.
    // If ccxpUsers/{uid} does not have studentId yet, rebuild it from email.
    final emailStudentId = _studentIdFromEmail(user.email);

    if (emailStudentId != null && emailStudentId.isNotEmpty) {
      await _ccxpUserRef.set({
        'studentId': emailStudentId,
        'accountStudentId': emailStudentId,
        'authUid': user.uid,
        'loginSource': 'ccxp',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return emailStudentId;
    }

    throw Exception(
      'Cannot find student ID in ccxpUsers for current Firebase user. '
      'Please log out, log in with CCXP again, then upload curriculum.',
    );
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

    await _curriculumRef.set({
      'studentId': studentId,
      'authUid': _uid,
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
      'studentId': studentId,
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
    await _getCurrentStudentId();
    yield* _curriculumRef.snapshots();
  }

  Future<Map<String, dynamic>?> fetchCurriculumForBaoBao() async {
    await _getCurrentStudentId();

    final doc = await _curriculumRef.get();
    final data = doc.data();

    if (data == null) return null;
    if (data['status'] != 'ready') return null;

    final curriculum = data['curriculum'];

    if (curriculum is Map<String, dynamic>) {
      return curriculum;
    }

    return null;
  }
}