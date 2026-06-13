import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:enthusiast/providers/ccxp_data_provider.dart';
import 'package:enthusiast/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileHeaderWidget extends StatefulWidget {
  const ProfileHeaderWidget({super.key});

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  static const String _fallbackAvatarUrl =
      'https://images.pexels.com/photos/8617741/pexels-photo-8617741.jpeg';

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  Map<String, String> _buildAcademicStats(Map<String, dynamic>? data) {
    if (data == null) {
      return {'gpa': '-', 'current': '-', 'total': '-'};
    }

    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final categories = data['categories'] as List<dynamic>? ?? [];

    final gpa = summary['cumulativeGpa']?.toString() ?? '0.00';
    var totalEarned = 0;
    var currentCredits = 0;

    for (final cat in categories) {
      if (cat is! Map<String, dynamic>) continue;

      totalEarned += _toInt(cat['earnedCredits']);
      final records = cat['records'] as List<dynamic>? ?? [];

      for (final rec in records) {
        if (rec is! Map<String, dynamic>) continue;
        if (rec['status'] == 'inProgress') {
          currentCredits += _toInt(rec['credits']);
        }
      }
    }

    return {
      'gpa': gpa,
      'current': currentCredits.toString(),
      'total': totalEarned.toString(),
    };
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _textValue(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Future<void> _pickAndSaveProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar('Please log in to CCXP first.');
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 72,
      );

      if (image == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      final bytes = await image.readAsBytes();

      if (bytes.length > 900000) {
        _showSnackBar('Image is too large. Please choose a smaller photo.');
        return;
      }

      final lowerName = image.name.toLowerCase();
      final mimeType = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final photoUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      final updateData = <String, dynamic>{
        'photoUrl': photoUrl,
        'profilePhotoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      await _syncSocialAvatarSnapshots(uid: user.uid, photoUrl: photoUrl);

      if (!mounted) return;
      _showSnackBar('Profile picture updated.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to update profile picture: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _syncSocialAvatarSnapshots({
    required String uid,
    required String photoUrl,
  }) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final postsSnapshot = await firestore
          .collection('socialPosts')
          .where('ownerId', isEqualTo: uid)
          .get();

      if (postsSnapshot.docs.isNotEmpty) {
        final postBatch = firestore.batch();

        for (final postDoc in postsSnapshot.docs) {
          postBatch.update(postDoc.reference, {
            'avatarUrl': photoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await postBatch.commit();
      }

      final repliesSnapshot = await firestore
          .collectionGroup('replies')
          .where('ownerId', isEqualTo: uid)
          .get();

      if (repliesSnapshot.docs.isNotEmpty) {
        final replyBatch = firestore.batch();

        for (final replyDoc in repliesSnapshot.docs) {
          replyBatch.update(replyDoc.reference, {'avatarUrl': photoUrl});
        }

        await replyBatch.commit();
      }
    } catch (error) {
      debugPrint('Failed to sync profile photo to Social: $error');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graduationData = context.watch<CcxpDataProvider>().graduationData;
    final academicStats = _buildAcademicStats(graduationData);
    final studentInfo = graduationData?['studentInfo'] as Map<String, dynamic>?;

    final studentName = _textValue(studentInfo?['studentName'], 'Anonymous');
    final studentId = _textValue(studentInfo?['studentId'], 'Anonymous');
    final department = _textValue(
      studentInfo?['studentDepartment'],
      'Anonymous',
    );

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),
            Positioned(bottom: 0, child: _buildProfileAvatar()),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          studentName,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              studentId,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFD1D5DB),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                department,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7E22CE),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          studentId == 'Anonymous'
              ? 'nthu_student@nthu.edu.tw'
              : '$studentId@nthu.edu.tw',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn(
                  'CUM. GPA',
                  academicStats['gpa']!,
                  const Color(0xFF7E22CE),
                ),
                const VerticalDivider(
                  color: Color(0xFFF3F4F6),
                  thickness: 2,
                  width: 32,
                ),
                _buildStatColumn(
                  'CURRENT CR.',
                  academicStats['current']!,
                  const Color(0xFF3B82F6),
                ),
                const VerticalDivider(
                  color: Color(0xFFF3F4F6),
                  thickness: 2,
                  width: 32,
                ),
                _buildStatColumn(
                  'TOTAL CR.',
                  academicStats['total']!,
                  const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _AvatarFrame(
        photoUrl: _fallbackAvatarUrl,
        isUploading: _isUploadingPhoto,
        onPickPhoto: _pickAndSaveProfilePhoto,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('ccxpUsers')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final photoUrl = _textValue(data?['photoUrl'], _fallbackAvatarUrl);

        return _AvatarFrame(
          photoUrl: photoUrl,
          isUploading: _isUploadingPhoto,
          onPickPhoto: _pickAndSaveProfilePhoto,
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AvatarFrame extends StatelessWidget {
  const _AvatarFrame({
    required this.photoUrl,
    required this.isUploading,
    required this.onPickPhoto,
  });

  final String photoUrl;
  final bool isUploading;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: _ProfilePhotoImage(
              photoUrl: photoUrl,
              width: 120,
              height: 120,
            ),
          ),
        ),
        if (isUploading)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.6,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 4,
          left: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isUploading ? null : onPickPhoto,
              customBorder: const CircleBorder(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF7E22CE),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePhotoImage extends StatelessWidget {
  const _ProfilePhotoImage({
    required this.photoUrl,
    required this.width,
    required this.height,
  });

  final String photoUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final memoryBytes = _tryDecodeDataImage(photoUrl);

    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return Image.network(
      photoUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF3E8FF),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF7E22CE),
            size: 48,
          ),
        );
      },
    );
  }

  Uint8List? _tryDecodeDataImage(String value) {
    if (!value.startsWith('data:image')) return null;

    final commaIndex = value.indexOf(',');
    if (commaIndex == -1 || commaIndex == value.length - 1) return null;

    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}
