import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import '../../theme/app_theme.dart';
import '../../widgets/profile_header.dart';
import 'widgets/curriculum_upload_sheet.dart';
import '../preference/preference_screen.dart';
import 'transcript_screen.dart';
import 'language_screen.dart';
import 'settings_screen.dart';
import 'package:enthusiast/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/ccxp_data_provider.dart';
import '../../providers/language_provider.dart';
import 'package:enthusiast/screens/account/account_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hover-aware settings row tile — matches home_screen hover-pop aesthetic
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDanger
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF5F3FF))
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? (widget.isDanger
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFDDD6FE))
                    : Colors.grey.shade100,
                width: 1.2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.isDanger
                            ? Colors.red.withOpacity(0.08)
                            : const Color(0xFF7E22CE).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Icon badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? widget.iconColor.withOpacity(0.18)
                        : widget.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: widget.isDanger
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing or animated chevron
                widget.trailing ??
                    AnimatedSlide(
                      offset: _isHovered ? const Offset(0.15, 0) : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _isHovered
                            ? (widget.isDanger
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF7E22CE))
                            : Colors.grey.shade300,
                        size: 22,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey.shade400,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AccountScreen
// ─────────────────────────────────────────────────────────────────────────────
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // ── Google Sign-In (dipindahkan dari ProfileScreen) ─────────────────────────
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com'
        : null,
    serverClientId: kIsWeb
        ? null
        : '2500792168-i7vvalt33atk3v1c513felvoe2p6dstl.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
  );

  // Cek apakah platform adalah iOS atau Android (bukan web)
  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  // Ambil studentId dari CcxpDataProvider; tampilkan SnackBar jika null
  String? _getStudentId(bool isChinese) {
    final ccxpData = Provider.of<CcxpDataProvider>(context, listen: false);
    final studentId =
        ccxpData.graduationData?["studentInfo"]?["studentId"]?.toString();
    if (studentId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isChinese
                ? '錯誤：找不到學號。請先登入 CCXP 系統。'
                : 'Error: Could not find Student ID. Please log in to CCXP first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return studentId;
  }

  // Panggil Cloud Function linkGmailAccount dengan payload yang diberikan
  Future<void> _callLinkFunction(
      Map<String, dynamic> payload, bool isChinese) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? '錯誤：未登入 Firebase。請先登入 CCXP 系統。'
                : 'Error: Not logged in to Firebase. Please log in to CCXP first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Gabungkan payload dengan uid sebelum dikirim ke Cloud Function
    final fullPayload = {...payload, 'uid': uid};

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('linkGmailAccount')
          .call(fullPayload);

      if (!mounted) return;

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? '帳號連動與保護成功！'
                : 'Account successfully linked and secured!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? '警告：連動已完成，但請檢查主控台訊息。'
                : 'Warning: Linking completed but check the console.'),
          ),
        );
      }
    } catch (e) {
      print("Cloud Function Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isChinese ? '連線至伺服器失敗。' : 'Failed to connect to server.')),
        );
      }
    }
  }

  // Alur login Gmail untuk platform mobile: gunakan serverAuthCode
  Future<void> _handleEmailLoginMobile(bool isChinese) async {
    try {
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return;

      final GoogleSignInAuthentication auth = await account.authentication;

      // serverAuthCode diperlukan agar server bisa memperbarui token
      final String? serverAuthCode = account.serverAuthCode;
      if (serverAuthCode == null) {
        print("Failed to get server auth code.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isChinese
                  ? '無法取得伺服器驗證碼。請檢查伺服器用戶端識別碼設定。'
                  : 'Failed to get server auth code. Check serverClientId configuration.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? 'Gmail 授權成功！正在連動...'
                : 'Successfully authorized Gmail! Linking...'),
          ),
        );
      }

      final studentId = _getStudentId(isChinese);
      if (studentId == null) return;

      // Kirim serverAuthCode, email, studentId, dan platform ke Cloud Function
      await _callLinkFunction({
        'serverAuthCode': serverAuthCode,
        'email': account.email,
        'studentId': studentId,
        'platform': 'mobile',
      }, isChinese);
    } catch (error) {
      print("Google Sign In Error (mobile): $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(isChinese ? '登入失敗：$error' : 'Login failed: $error')),
        );
      }
    }
  }

  // Alur login Gmail untuk web: gunakan accessToken
  Future<void> _handleEmailLoginWeb(bool isChinese) async {
    try {
      GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return;

      // Minta izin scope Gmail secara eksplisit di web
      final bool granted =
          await _googleSignIn.requestScopes(_googleSignIn.scopes.toList());
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  isChinese ? '未授予 Gmail 存取權限。' : 'Gmail scope not granted.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Gunakan signInSilently untuk memperbarui token tanpa popup ulang
      account = await _googleSignIn.signInSilently() ?? account;
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;

      if (accessToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(isChinese ? '無法取得存取權杖。' : 'Failed to get access token.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isChinese
                ? 'Gmail 授權成功！正在連動...'
                : 'Successfully authorized Gmail! Linking...'),
          ),
        );
      }

      final studentId = _getStudentId(isChinese);
      if (studentId == null) return;

      // Kirim accessToken, email, studentId, dan platform ke Cloud Function
      await _callLinkFunction({
        'accessToken': accessToken,
        'email': account.email,
        'studentId': studentId,
        'platform': 'web',
      }, isChinese);
    } catch (e) {
      print("Web Google Sign In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(isChinese ? '授權失敗：$e' : 'Authorization failed: $e')),
        );
      }
    }
  }

  // Dispatcher: pilih mobile atau web berdasarkan platform
  Future<void> _handleEmailLogin(bool isChinese) async {
    if (_isMobilePlatform) {
      await _handleEmailLoginMobile(isChinese);
    } else {
      await _handleEmailLoginWeb(isChinese);
    }
  }

  // ── Navigation helpers ──────────────────────────────────────────────────────

  void _openTranscriptScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TranscriptScreen()),
    );
  }

  void _openPreferenceScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PreferenceScreen(returnToPrevious: true),
      ),
    );
  }

  void _openCurriculumSheet(bool isChinese) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese
              ? '在上傳課程表前，請重新登入。'
              : 'Please login again before uploading curriculum.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CurriculumUploadSheet(),
    );
  }

  void _openLanguageScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LanguageScreen()),
    );
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _onLogout(bool isChinese) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: AppTheme.critical,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isChinese ? '登出' : 'Log Out',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isChinese
                  ? '確定要登出您的清華大學帳號嗎？'
                  : 'Are you sure you want to log out of your NTHU account?',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isChinese ? '取消' : 'Cancel',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      FirebaseAuth.instance.signOut();
                      // deleteCcxpAccount();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GatekeeperScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.critical,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isChinese ? '登出' : 'Log Out',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onDelete(bool isChinese) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: AppTheme.critical,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isChinese ? '刪除' : 'Delete',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isChinese
                  ? '您確定要刪除此帳號嗎？此操作無法復原'
                  : 'Do you want to delete your firebase account?',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isChinese ? '取消' : 'Cancel',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await deleteCcxpAccount();
                      Navigator.pop(ctx);
                      // deleteCcxpAccount();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GatekeeperScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.critical,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isChinese ? '刪除' : 'Delete',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isTablet
            ? _buildTabletLayout(isChinese)
            : _buildPhoneLayout(isChinese),
      ),
    );
  }

  Widget _buildPhoneLayout(bool isChinese) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileHeaderWidget(),
          const SizedBox(height: 36),
          _buildSettingsMenu(isChinese),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(bool isChinese) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileHeaderWidget(),
              const SizedBox(height: 36),
              _buildSettingsMenu(isChinese),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings menu ────────────────────────────────────────────────────────────
  Widget _buildSettingsMenu(bool isChinese) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ACCOUNT ─────────────────────────────────────────────────────────
        _SectionLabel(isChinese ? '帳號' : 'Account'),
        _SettingsTile(
          icon: Icons.email_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEE2E2),
          title: isChinese ? '電子郵件登入' : 'Email Login',
          subtitle: isChinese ? '連結您的 Gmail 帳號' : 'Link your Gmail account',
          onTap: () => _handleEmailLogin(isChinese),
        ),

        const SizedBox(height: 28),

        // ── ACADEMIC ────────────────────────────────────────────────────────
        _SectionLabel(isChinese ? '學業' : 'Academic'),
        _SettingsTile(
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF7B2F8E),
          iconBg: const Color(0xFFF3E8FF),
          title: isChinese ? '成績單' : 'Transcript',
          subtitle: isChinese ? '查看您的學業成績' : 'View your academic records',
          onTap: _openTranscriptScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF0EA5E9),
          iconBg: const Color(0xFFE0F2FE),
          title: isChinese ? '偏好設定' : 'Preferences',
          subtitle: isChinese ? '課程與職涯設定' : 'Course schedule & career settings',
          onTap: _openPreferenceScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.upload_file_rounded,
          iconColor: const Color(0xFF059669),
          iconBg: const Color(0xFFD1FAE5),
          title: isChinese ? '上傳課程表' : 'Curriculum Upload',
          subtitle: isChinese ? '上傳您的學位計畫' : 'Upload your degree plan',
          onTap: () => _openCurriculumSheet(isChinese),
        ),

        const SizedBox(height: 28),

        // ── APP ─────────────────────────────────────────────────────────────
        _SectionLabel(isChinese ? '應用程式' : 'App'),
        _SettingsTile(
          icon: Icons.language_rounded,
          iconColor: const Color(0xFF0891B2),
          iconBg: const Color(0xFFCFFAFE),
          title: isChinese ? '語言' : 'Language',
          subtitle: 'English / 繁體中文',
          onTap: _openLanguageScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF64748B),
          iconBg: const Color(0xFFF1F5F9),
          title: isChinese ? '設定' : 'Settings',
          subtitle: isChinese ? '關於我們及更多' : 'About us & more',
          onTap: _openSettingsScreen,
        ),

        const SizedBox(height: 28),

        // ── DANGER ──────────────────────────────────────────────────────────
        _SectionLabel(isChinese ? '工作階段' : 'Session'),
        _SettingsTile(
          icon: Icons.logout_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEE2E2),
          title: isChinese ? '登出' : 'Log Out',
          subtitle: isChinese ? '登出您的清華大學帳號' : 'Sign out of your NTHU account',
          isDanger: true,
          onTap: () => _onLogout(isChinese),
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.delete_forever_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEE2E2),
          title: isChinese ? '刪除' : 'Delete Data',
          subtitle: isChinese
              ? '永久刪除您在 Firebase 中的帳號與資料'
              : 'Permanently remove your account and data from Firebase',
          isDanger: true,
          onTap: () => _onDelete(isChinese),
        ),
        const SizedBox(height: 70),
      ],
    );
  }

  // ── Preserved from original ─────────────────────────────────────────────────
  Future<void> deleteCcxpAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Delete Firestore data
    await FirebaseFirestore.instance.collection('ccxpUsers').doc(uid).delete();

    // Delete Firebase Auth account
    await user.delete();

    // Sign out
    await FirebaseAuth.instance.signOut();
  }
}
