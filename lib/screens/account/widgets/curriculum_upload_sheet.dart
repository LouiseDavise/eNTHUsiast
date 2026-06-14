import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../providers/language_provider.dart';
import '../service/curriculum_upload_service.dart';

class CurriculumUploadSheet extends StatefulWidget {
  const CurriculumUploadSheet({
    super.key,
  });

  @override
  State<CurriculumUploadSheet> createState() => _CurriculumUploadSheetState();
}

class _CurriculumUploadSheetState extends State<CurriculumUploadSheet> {
  final CurriculumUploadService _service = CurriculumUploadService();

  bool isUploading = false;

  Future<void> uploadPdf() async {
    if (isUploading) return;

    setState(() {
      isUploading = true;
    });

    try {
      final uploaded = await _service.pickAndUploadCurriculumPdf();

      if (!mounted) return;

      if (!uploaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No PDF selected. Upload canceled.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Curriculum parsed. Bao-Bao can use it now 🐼'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  String _statusText(String? status, bool isChinese) {
    if (isChinese) {
      switch (status) {
        case 'uploading':
          return '正在將您的課程表 PDF 傳送給寶寶...';
        case 'processing':
          return '寶寶正在讀取您的課程表...';
        case 'ready':
          return '課程表已就緒，寶寶現在可以使用了。';
        case 'error':
          return '寶寶無法解析此 PDF。';
        default:
          return '請上傳您的課程表 PDF，讓寶寶能更精確地規劃。';
      }
    }
    switch (status) {
      case 'uploading':
        return 'Sending your curriculum PDF to Bao-Bao...';
      case 'processing':
        return 'Bao-Bao is reading your curriculum...';
      case 'ready':
        return 'Curriculum is ready. Bao-Bao can use it now.';
      case 'error':
        return 'Bao-Bao could not parse this PDF.';
      default:
        return 'Upload your curriculum PDF so Bao-Bao can plan more accurately.';
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'uploading':
      case 'processing':
        return Icons.hourglass_top_rounded;
      case 'ready':
        return Icons.check_circle_rounded;
      case 'error':
        return Icons.error_rounded;
      default:
        return Icons.upload_file_rounded;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'ready':
        return const Color(0xFF22C55E);
      case 'error':
        return const Color(0xFFFF2D55);
      default:
        return const Color(0xFF7E3291);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildNotLoggedInSheet(isChinese);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.watchCurriculumStatus(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();

        final status = data?['status']?.toString();
        final fileName = data?['fileName']?.toString();
        final errorMessage = data?['errorMessage']?.toString();

        final color = _statusColor(status);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _statusIcon(status),
                        color: color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        isChinese ? '課程表 PDF' : 'Curriculum PDF',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _statusText(status, isChinese),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),

                      if (fileName != null && fileName.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          fileName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],

                      if (errorMessage != null && errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF2D55),
                          ),
                        ),
                      ],

                      if (isUploading ||
                          status == 'uploading' ||
                          status == 'processing') ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          color: Color(0xFF7E3291),
                          backgroundColor: Color(0xFFE9D5FF),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : uploadPdf,
                    icon: isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(
                      isUploading
                          ? (isChinese ? '解析中...' : 'Parsing...')
                          : status == 'ready'
                              ? (isChinese ? '替換課程表 PDF' : 'Replace Curriculum PDF')
                              : (isChinese ? '上傳課程表 PDF' : 'Upload Curriculum PDF'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7E3291),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD8B4FE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  isChinese
                      ? 'PDF 本身不會被儲存，僅會保留解析後的課程表 JSON。'
                      : 'The PDF itself will not be saved. Only the parsed curriculum JSON will be stored.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotLoggedInSheet(bool isChinese) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.lock_rounded,
              color: Color(0xFFFF2D55),
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              isChinese ? '尚未登入' : 'Not logged in',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isChinese
                  ? '請在上傳課程表 PDF 前重新登入。'
                  : 'Please login again before uploading your curriculum PDF.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}