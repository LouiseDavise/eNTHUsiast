import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/profile_header.dart';
import 'widgets/curriculum_upload_sheet.dart';
import '../preference/preference_screen.dart';
import 'profile_screen.dart';
import 'transcript_screen.dart';
import 'language_screen.dart';
import 'settings/settings_screen.dart';
import 'package:enthusiast/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // ── Navigation helpers (preserved from original SettingsMenuWidget) ─────────

  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

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

  void _openCurriculumSheet() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login again before uploading curriculum.'),
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

  void _onLogout() {
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
              'Log Out',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to log out of your NTHU account?',
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
                      'Cancel',
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
                    // Original commented-out FirebaseAuth.signOut preserved below:
                    // await FirebaseAuth.instance.signOut();
                    // if (context.mounted) {
                    //   Navigator.pop(ctx);
                    //   Navigator.pushNamedAndRemoveUntil(
                    //     context, '/login', (route) => false,
                    //   );
                    // }
                    onPressed: () async {
                      deleteCcxpAccount();
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
                      'Log Out',
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
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileHeaderWidget(),
          const SizedBox(height: 36),
          _buildSettingsMenu(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
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
              _buildSettingsMenu(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Settings menu — all original sections + new Preferences tile ────────────
  Widget _buildSettingsMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ACCOUNT ─────────────────────────────────────────────────────────
        const _SectionLabel('Account'),
        _SettingsTile(
          icon: Icons.manage_accounts_rounded,
          iconColor: const Color(0xFF7B2F8E),
          iconBg: const Color(0xFFF3E8FF),
          title: 'Account',
          subtitle: 'CCXP & Gmail login',
          onTap: _openProfileScreen,
        ),

        const SizedBox(height: 28),

        // ── ACADEMIC ────────────────────────────────────────────────────────
        const _SectionLabel('Academic'),
        _SettingsTile(
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF7B2F8E),
          iconBg: const Color(0xFFF3E8FF),
          title: 'Transcript',
          subtitle: 'View your academic records',
          onTap: _openTranscriptScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.tune_rounded,
          iconColor: const Color(0xFF0EA5E9),
          iconBg: const Color(0xFFE0F2FE),
          title: 'Preferences',
          subtitle: 'Course schedule & career settings',
          onTap: _openPreferenceScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.upload_file_rounded,
          iconColor: const Color(0xFF059669),
          iconBg: const Color(0xFFD1FAE5),
          title: 'Curriculum Upload',
          subtitle: 'Upload your degree plan',
          onTap: _openCurriculumSheet,
        ),

        const SizedBox(height: 28),

        // ── APP ─────────────────────────────────────────────────────────────
        const _SectionLabel('App'),
        _SettingsTile(
          icon: Icons.language_rounded,
          iconColor: const Color(0xFF0891B2),
          iconBg: const Color(0xFFCFFAFE),
          title: 'Language',
          subtitle: 'English / 繁體中文',
          onTap: _openLanguageScreen,
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          iconColor: const Color(0xFF64748B),
          iconBg: const Color(0xFFF1F5F9),
          title: 'Settings',
          subtitle: 'About us & more',
          onTap: _openSettingsScreen,
        ),

        const SizedBox(height: 28),

        // ── DANGER ──────────────────────────────────────────────────────────
        const _SectionLabel('Session'),
        _SettingsTile(
          icon: Icons.logout_rounded,
          iconColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFFEE2E2),
          title: 'Log Out',
          subtitle: 'Sign out of your NTHU account',
          isDanger: true,
          onTap: _onLogout,
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
