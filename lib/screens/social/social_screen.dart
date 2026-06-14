import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/social_post.dart';
import '../../models/social_reply.dart';
import '../../services/social_firestore_service.dart';
import '../../providers/language_provider.dart';

const Color _primaryPurple = Color(0xFFA77CCB);
const Color _deepPurple = Color(0xFF722E85);
const Color _black = Color(0xFF1A1A1A);
const Color _backgroundWhite = Color(0xFFFFFFFF);
const Color _mainTextGrey = Color(0xFF767993);
const Color _darkGreyText = Color(0xFF34384A);
const Color _hintTextGrey = Color(0xFFB3B7C8);
const Color _smallTextLightGrey = Color(0xFFD1D5DC);
const Color _cardBorder = Color(0xFFE8E1EF);

const Color _errorRed = Color(0xFFE05A5A);

bool _isCurrentUserOwner(String ownerId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return uid != null && ownerId == uid;
}

String _cleanPublicAuthorName(String userName, {bool isChinese = false}) {
  final trimmed = userName.trim();
  if (trimmed.isEmpty) return isChinese ? '匿名' : 'Anonymous';
  if (trimmed.toLowerCase() == 'you') return isChinese ? '匿名' : 'Anonymous';
  return trimmed;
}

String _postAuthorName(SocialPost post, {bool isChinese = false}) {
  if (!post.isSeededDemo && _isCurrentUserOwner(post.ownerId)) {
    return isChinese ? '我' : 'YOU';
  }

  return _cleanPublicAuthorName(post.userName, isChinese: isChinese);
}

String _replyAuthorName(SocialReply reply, {bool isChinese = false}) {
  if (!reply.isSeededDemo && _isCurrentUserOwner(reply.ownerId)) {
    return isChinese ? '我' : 'YOU';
  }

  return _cleanPublicAuthorName(reply.userName, isChinese: isChinese);
}

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  bool _showTitleError = false;
  bool _showContentError = false;

  final Set<String> _savedPostIds = {};
  final Set<String> _hiddenPostIds = {};

  final List<String> _departments = const [
    'All',
    'CS',
    'EE',
    'Design',
    'Math',
    'Physics',
    'Arts',
    'HSS',
    'General',
    'Business',
    'Life Science',
  ];

  final SocialFirestoreService _socialService = SocialFirestoreService();

  List<SocialPost> _latestPosts = [];
  String _selectedDepartment = 'All';
  String _createDepartment = 'General';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {});
    });

    unawaited(_seedDemoPostsIfNeeded());
  }

  Future<void> _seedDemoPostsIfNeeded() async {
    try {
      await _socialService.seedDemoPostsIfNeeded();
    } catch (error) {
      if (!mounted) return;
      final isChinese = LanguageScope.watch(context).isChinese;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '載入示範貼文失敗：$error' : 'Failed to seed demo posts: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  List<SocialPost> _filteredPosts(List<SocialPost> source) {
    final query = _searchController.text.trim().toLowerCase();

    return source.where((post) {
      final notHidden = !_hiddenPostIds.contains(post.id);

      final matchesDepartment = _selectedDepartment == 'All' ||
          post.department == _selectedDepartment;

      final matchesSearch = query.isEmpty ||
          post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query) ||
          post.userName.toLowerCase().contains(query);

      return notHidden && matchesDepartment && matchesSearch;
    }).toList();
  }

  List<SocialPost> get _savedPosts {
    return _latestPosts
        .where((post) => _savedPostIds.contains(post.id))
        .toList();
  }

  bool _isMyPost(SocialPost post) {
    return !post.isSeededDemo && _isCurrentUserOwner(post.ownerId);
  }

  bool _isMyReply(SocialReply reply) {
    return !reply.isSeededDemo && _isCurrentUserOwner(reply.ownerId);
  }

  static String _chineseDeptLabel(String dept) {
    const map = <String, String>{
      'CS': '資工',
      'EE': '電機',
      'Design': '設計',
      'Math': '數學',
      'Physics': '物理',
      'Arts': '藝術',
      'HSS': '人社',
      'General': '一般',
      'Business': '商管',
      'Life Science': '生科',
    };
    return map[dept] ?? dept;
  }

  @override
  Widget build(BuildContext context) {
    final isChinese = LanguageScope.watch(context).isChinese;
    return Scaffold(
      backgroundColor: _backgroundWhite,
      body: Stack(
        children: [
          const _SocialWallpaper(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildTopHeader(isChinese),
                    const SizedBox(height: 10),
                    _buildSearchBar(isChinese),
                    _buildFilterChips(isChinese),
                    Expanded(
                      child: StreamBuilder<List<SocialPost>>(
                        stream: _socialService.watchPosts(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error.toString(), isChinese);
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: _deepPurple,
                              ),
                            );
                          }

                          final allPosts =
                              snapshot.data ?? const <SocialPost>[];
                          _latestPosts = allPosts;
                          final posts = _filteredPosts(allPosts);

                          if (posts.isEmpty) {
                            return _buildEmptyState(isChinese);
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                            itemBuilder: (context, index) =>
                                _buildPostCard(posts[index], isChinese),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 14),
                            itemCount: posts.length,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 131,
            right: 32,
            child: SizedBox(
              width: 56,
              height: 56,
              child: _SocialFabHover(onPressed: () => _showCreatePostSheet(isChinese)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isChinese) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChinese ? '社群' : 'Social',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isChinese ? '校園討論區' : 'Campus Community',
                  style: const TextStyle(
                    color: _mainTextGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => _showSavedPostsSheet(isChinese),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: _deepPurple,
                  shadowColor: Colors.black.withValues(alpha: 0.10),
                  elevation: 4,
                  fixedSize: const Size(46, 46),
                ),
                icon: Icon(
                  _savedPostIds.isEmpty
                      ? Icons.bookmark_border_rounded
                      : Icons.bookmark_rounded,
                  size: 24,
                ),
              ),
              if (_savedPostIds.isNotEmpty)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: _deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _savedPostIds.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isChinese) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: _darkGreyText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _mainTextGrey,
                size: 22,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _mainTextGrey,
                        size: 20,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: _cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: _primaryPurple, width: 1.4),
              ),
            ),
          ),
          if (_searchController.text.isEmpty)
            Positioned(
              left: 52,
              child: IgnorePointer(child: _TypingSearchHint(isChinese: isChinese)),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isChinese) {
    // Chinese labels for each department chip
    const chineseLabels = <String, String>{
      'All': '全部',
      'CS': '資工',
      'EE': '電機',
      'Design': '設計',
      'Math': '數學',
      'Physics': '物理',
      'Arts': '藝術',
      'HSS': '人社',
      'General': '一般',
      'Business': '商管',
      'Life Science': '生科',
    };

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final department = _departments[index];
          final selected = department == _selectedDepartment;
          final label = isChinese
              ? (chineseLabels[department] ?? department)
              : department.toUpperCase();

          return ChoiceChip(
            label: Text(isChinese ? label : label),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _selectedDepartment = department;
              });
            },
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _mainTextGrey,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: isChinese ? 0.5 : 0.8,
            ),
            selectedColor: _deepPurple,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _deepPurple : Colors.transparent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemCount: _departments.length,
      ),
    );
  }

  Widget _buildPostCard(SocialPost post, bool isChinese) {
    final isSaved = _savedPostIds.contains(post.id);
    final isMine = _isMyPost(post);

    return InkWell(
      onTap: () => _showPostDetailSheet(post, isChinese),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  initials: post.initials,
                  imageUrl: post.avatarUrl,
                  size: 46,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          color: _black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          Text(
                            _postAuthorName(post, isChinese: isChinese).toUpperCase(),
                            style: const TextStyle(
                              color: _deepPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const _SmallDot(),
                          Text(
                            post.department.toUpperCase(),
                            style: const TextStyle(
                              color: _mainTextGrey,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (isMine) ...[
                            const _SmallDot(),
                            Text(
                              isChinese ? '我的討論' : 'YOUR FORUM',
                              style: const TextStyle(
                                color: _deepPurple,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
                          if (isSaved) ...[
                            const _SmallDot(),
                            const Icon(
                              Icons.bookmark_rounded,
                              color: _deepPurple,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showPostOptionsSheet(post, isChinese),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: _smallTextLightGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mainTextGrey,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: _backgroundWhite),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.mode_comment_outlined,
                  color: _mainTextGrey,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  isChinese
                      ? '${post.replyCount} 則回覆'
                      : '${post.replyCount} replies',
                  style: const TextStyle(
                    color: _mainTextGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  post.time.toUpperCase(),
                  style: const TextStyle(
                    color: _smallTextLightGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isChinese) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _primaryPurple.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _deepPurple,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isChinese ? '找不到討論' : 'No discussions found',
              style: const TextStyle(
                color: _black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isChinese ? '請嘗試其他搜尋關鍵字或系所篩選。' : 'Try another search or department filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mainTextGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, bool isChinese) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: const Color(0xFFE05A5A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE05A5A),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isChinese ? '無法載入討論' : 'Could not load discussions',
              style: const TextStyle(
                color: _black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mainTextGrey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptionsSheet(SocialPost post, bool isChinese) {
    final isSaved = _savedPostIds.contains(post.id);
    final isMine = _isMyPost(post);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: _smallTextLightGrey,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    _PostOptionTile(
                      icon: isSaved
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_add_outlined,
                      title: isSaved
                          ? (isChinese ? '取消儲存' : 'Remove from saved')
                          : (isChinese ? '儲存貼文' : 'Save post'),
                      subtitle: isSaved
                          ? (isChinese ? '從儲存清單中移除此貼文。' : 'Remove this post from your saved list.')
                          : (isChinese ? '稍後再讀。' : 'Keep this post for later.'),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleSavePost(post, isChinese);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (isMine) ...[
                      _PostOptionTile(
                        icon: Icons.delete_outline_rounded,
                        title: isChinese ? '刪除討論' : 'Delete forum',
                        subtitle: isChinese
                            ? '刪除此討論及其所有回覆。'
                            : 'Delete this forum and all replies inside it.',
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeletePost(post, isChinese);
                        },
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      _PostOptionTile(
                        icon: Icons.visibility_off_outlined,
                        title: isChinese ? '不感興趣' : 'Not interested',
                        subtitle: isChinese ? '從您的動態隱藏此討論。' : 'Hide this discussion from your feed.',
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _hidePost(post, isChinese);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    _PostOptionTile(
                      icon: Icons.close_rounded,
                      title: isChinese ? '取消' : 'Cancel',
                      subtitle: isChinese ? '關閉此選單。' : 'Close this menu.',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSavePost(SocialPost post, bool isChinese) {
    final wasSaved = _savedPostIds.contains(post.id);

    setState(() {
      if (wasSaved) {
        _savedPostIds.remove(post.id);
      } else {
        _savedPostIds.add(post.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasSaved
            ? (isChinese ? '已取消儲存。' : 'Removed from saved.')
            : (isChinese ? '已儲存貼文。' : 'Post saved.')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _hidePost(SocialPost post, bool isChinese) {
    setState(() {
      _hiddenPostIds.add(post.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isChinese ? '貼文已隱藏。' : 'Post hidden.',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _deepPurple,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 92),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: isChinese ? '復原' : 'UNDO',
          textColor: const Color(0xFFFFF2A8),
          onPressed: () {
            setState(() {
              _hiddenPostIds.remove(post.id);
            });
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(SocialPost post, bool isChinese) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                          color: _smallTextLightGrey,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05A5A).withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE05A5A),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isChinese ? '刪除討論？' : 'Delete forum?',
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isChinese
                          ? '此操作將刪除您的討論及所有回覆，且在此原型中無法復原。'
                          : 'This will delete your forum and all replies inside it. This action cannot be undone in this prototype.',
                      style: const TextStyle(
                        color: _mainTextGrey,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogContext, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  isChinese ? '取消' : 'Cancel',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _mainTextGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(dialogContext, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE05A5A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  isChinese ? '刪除' : 'Delete',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    _deletePost(post, isChinese);
  }

  Future<void> _deletePost(SocialPost post, bool isChinese) async {
    if (!_isMyPost(post)) return;

    try {
      await _socialService.deletePost(post.id);

      if (!mounted) return;
      setState(() {
        _savedPostIds.remove(post.id);
        _hiddenPostIds.remove(post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '討論已刪除。' : 'Forum deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '刪除討論失敗：$error' : 'Failed to delete forum: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteReply(SocialPost post, SocialReply reply, bool isChinese) async {
    if (!_isMyReply(reply)) return;

    try {
      await _socialService.deleteReply(postId: post.id, replyId: reply.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '回覆已刪除。' : 'Reply deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '刪除回覆失敗：$error' : 'Failed to delete reply: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSavedPostsSheet(bool isChinese) {
    final savedPosts = _savedPosts;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: _backgroundWhite,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isChinese ? '已儲存' : 'SAVED',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF8A56AC),
                                letterSpacing: 2.4,
                              ),
                            ),
                            Text(
                              isChinese ? '儲存的貼文' : 'Saved Posts',
                              style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F1F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: savedPosts.isEmpty
                        ? _SavedEmptyState(isChinese: isChinese)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemBuilder: (context, index) {
                              final post = savedPosts[index];

                              return _SavedPostTile(
                                post: post,
                                isChinese: isChinese,
                                onOpen: () {
                                  Navigator.pop(context);
                                  _showPostDetailSheet(post, isChinese);
                                },
                                onRemove: () {
                                  setState(() {
                                    _savedPostIds.remove(post.id);
                                  });
                                  Navigator.pop(context);
                                  _showSavedPostsSheet(isChinese);
                                },
                              );
                            },
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemCount: savedPosts.length,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePostSheet(bool isChinese) {
    _titleController.clear();
    _contentController.clear();
    _showTitleError = false;
    _showContentError = false;
    _createDepartment =
        _selectedDepartment == 'All' ? 'General' : _selectedDepartment;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 24),
                      child: child,
                    ),
                  );
                },
                child: _SheetShell(
                  title: isChinese ? '新增討論' : 'New Forum',
                  subtitle: isChinese ? '與校園社群分享' : 'Share with the community',
                  leadingIcon: Icons.mode_comment_outlined,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetTextField(
                        controller: _titleController,
                        label: isChinese ? '標題' : 'Title',
                        hint: isChinese ? '您有什麼想法？' : "What's on your mind?",
                        showError: _showTitleError,
                        errorText: isChinese ? '請輸入標題' : 'Title is required',
                        onChanged: (_) {
                          if (!_showTitleError) return;
                          setSheetState(() {
                            _showTitleError = false;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _SheetLabel(isChinese ? '系所' : 'Department'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _createDepartment,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _mainTextGrey,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFBFBFD),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: _primaryPurple,
                              width: 1.4,
                            ),
                          ),
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        style: const TextStyle(
                          color: _darkGreyText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        items: _departments
                            .where((department) => department != 'All')
                            .map(
                              (department) => DropdownMenuItem<String>(
                                value: department,
                                child: Text(isChinese
                                    ? _chineseDeptLabel(department)
                                    : department),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            _createDepartment = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildSheetTextField(
                        controller: _contentController,
                        label: isChinese ? '內容' : 'Content',
                        hint: isChinese ? '與社群分享您的想法...' : 'Share your thoughts with the community...',
                        maxLines: 5,
                        showError: _showContentError,
                        errorText: isChinese ? '請輸入內容' : 'Content is required',
                        onChanged: (_) {
                          if (!_showContentError) return;
                          setSheetState(() {
                            _showContentError = false;
                          });
                        },
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              _validateAndCreatePost(setSheetState),
                          style: FilledButton.styleFrom(
                            backgroundColor: _deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          child: Text(isChinese ? '發佈' : 'POST'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostDetailSheet(SocialPost post, bool isChinese) {
    _replyController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (context) {
        return StreamBuilder<List<SocialReply>>(
          stream: _socialService.watchReplies(post.id),
          builder: (context, snapshot) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final replies = snapshot.data ?? const <SocialReply>[];

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: _ThreadDetailPanel(
                    post: post,
                    replies: replies,
                    replyController: _replyController,
                    canDeletePost: _isMyPost(post),
                    isChinese: isChinese,
                    onDeletePost: () {
                      Navigator.pop(context);
                      _confirmDeletePost(post, isChinese);
                    },
                    onDeleteReply: (reply) {
                      unawaited(_deleteReply(post, reply, isChinese));
                    },
                    onSendReply: () {
                      unawaited(_sendReply(post));
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool showError = false,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          textInputAction:
              maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
          style: const TextStyle(
            color: _darkGreyText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _hintTextGrey,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: const Color(0xFFFBFBFD),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            errorText: showError ? errorText : null,
            errorStyle: const TextStyle(
              color: _errorRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: showError ? _errorRed : _cardBorder,
                width: showError ? 1.4 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: showError ? _errorRed : _primaryPurple,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _errorRed, width: 1.4),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _errorRed, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  void _validateAndCreatePost(StateSetter setSheetState) {
    final titleIsEmpty = _titleController.text.trim().isEmpty;
    final contentIsEmpty = _contentController.text.trim().isEmpty;

    setSheetState(() {
      _showTitleError = titleIsEmpty;
      _showContentError = contentIsEmpty;
    });

    if (titleIsEmpty || contentIsEmpty) return;

    unawaited(_createPost());
  }

  Future<void> _createPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final isChinese = LanguageScope.watch(context).isChinese;

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '標題與內容不能為空。' : 'Title and content cannot be empty.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await _socialService.createPost(
        title: title,
        content: content,
        department: _createDepartment,
      );

      if (!mounted) return;
      setState(() {
        _selectedDepartment = 'All';
        _searchController.clear();
      });

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '發佈討論失敗：$error' : 'Failed to create forum: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendReply(SocialPost post) async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    _replyController.clear();

    try {
      await _socialService.createReply(postId: post.id, content: content);
    } catch (error) {
      if (!mounted) return;
      final isChinese = LanguageScope.watch(context).isChinese;
      _replyController.text = content;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isChinese ? '發送回覆失敗：$error' : 'Failed to send reply: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.size, this.imageUrl});

  final String initials;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallbackColors = [
      const Color(0xFFE9D8FD),
      const Color(0xFFFFE4D6),
      const Color(0xFFD9F2FF),
      const Color(0xFFE6F7E9),
      const Color(0xFFFFE1E8),
    ];

    final colorIndex = initials.codeUnitAt(0) % fallbackColors.length;
    final normalizedImageUrl = imageUrl?.trim();
    final memoryBytes = _decodeDataImage(normalizedImageUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColors[colorIndex],
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedImageUrl == null || normalizedImageUrl.isEmpty
          ? _AvatarInitials(initials: initials, size: size)
          : memoryBytes != null
              ? Image.memory(memoryBytes,
                  fit: BoxFit.cover, gaplessPlayback: true)
              : Image.network(
                  normalizedImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _AvatarInitials(initials: initials, size: size);
                  },
                ),
    );
  }

  Uint8List? _decodeDataImage(String? value) {
    if (value == null || !value.startsWith('data:image')) return null;

    final commaIndex = value.indexOf(',');
    if (commaIndex == -1 || commaIndex == value.length - 1) return null;

    try {
      return base64Decode(value.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: _deepPurple,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PostOptionTile extends StatelessWidget {
  const _PostOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE05A5A) : _deepPurple;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFFFF2F2)
              : _primaryPurple.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? const Color(0xFFB43636) : _black,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _mainTextGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  const _SavedPostTile({
    required this.post,
    required this.onOpen,
    required this.onRemove,
    required this.isChinese,
  });

  final SocialPost post;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cardBorder, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              initials: post.initials,
              imageUrl: post.avatarUrl,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _black,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_postAuthorName(post, isChinese: isChinese).toUpperCase()} • ${post.department.toUpperCase()}',
                    style: const TextStyle(
                      color: _deepPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _mainTextGrey,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.bookmark_remove_rounded),
              color: _deepPurple,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState({required this.isChinese});

  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: _primaryPurple.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                color: _deepPurple,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isChinese ? '尚無儲存的貼文' : 'No saved posts yet',
              style: const TextStyle(
                color: _black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isChinese
                  ? '點擊任何討論的三點選單即可儲存以便稍後閱讀。'
                  : 'Tap the three-dot menu on any discussion and save it for later.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mainTextGrey,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingSearchHint extends StatefulWidget {
  const _TypingSearchHint({required this.isChinese});

  final bool isChinese;

  @override
  State<_TypingSearchHint> createState() => _TypingSearchHintState();
}

class _TypingSearchHintState extends State<_TypingSearchHint> {
  String get _fullText =>
      widget.isChinese ? '搜尋討論...' : 'Search discussions...';

  Timer? _timer;
  int _index = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) return;

      if (_index >= _fullText.length) {
        setState(() {
          _done = true;
        });
        timer.cancel();
        return;
      }

      setState(() {
        _index++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _done ? _fullText : _fullText.substring(0, _index);

    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9AA0B8),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SocialWallpaper extends StatelessWidget {
  const _SocialWallpaper();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: _backgroundWhite),
        Positioned(
          top: 90,
          left: -80,
          child: _BlurBlob(size: 190, opacity: 0.05),
        ),
        Positioned(
          top: 360,
          right: -90,
          child: _BlurBlob(size: 220, opacity: 0.045),
        ),
        Positioned(
          bottom: 80,
          left: 30,
          child: _BlurBlob(size: 160, opacity: 0.04),
        ),
      ],
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _deepPurple.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.child,
    this.subtitle,
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle != null)
                            Text(
                              subtitle!.toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF8A56AC),
                                letterSpacing: 2.4,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF8A56AC),
        letterSpacing: 2.0,
      ),
    );
  }
}

class _ThreadDetailPanel extends StatelessWidget {
  const _ThreadDetailPanel({
    required this.post,
    required this.replies,
    required this.replyController,
    required this.onSendReply,
    required this.onDeleteReply,
    required this.canDeletePost,
    required this.onDeletePost,
    required this.isChinese,
  });

  final SocialPost post;
  final List<SocialReply> replies;
  final TextEditingController replyController;
  final VoidCallback onSendReply;
  final void Function(SocialReply reply) onDeleteReply;
  final bool canDeletePost;
  final VoidCallback onDeletePost;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ThreadHeader(
            post: post,
            canDeletePost: canDeletePost,
            onDeletePost: onDeletePost,
            isChinese: isChinese,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: replies.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      isChinese
                          ? '回覆 (${replies.length})'
                          : 'REPLIES (${replies.length})',
                      style: const TextStyle(
                        color: Color(0xFF9AA0B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  );
                }

                final reply = replies[index - 1];
                return _ThreadReplyBubble(
                  reply: reply,
                  canDelete: !reply.isSeededDemo &&
                      _isCurrentUserOwner(reply.ownerId),
                  onDelete: () => onDeleteReply(reply),
                  isChinese: isChinese,
                );
              },
            ),
          ),
          _ThreadReplyInput(
            controller: replyController,
            onSend: onSendReply,
            isChinese: isChinese,
          ),
        ],
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.post,
    required this.canDeletePost,
    required this.onDeletePost,
    required this.isChinese,
  });

  final SocialPost post;
  final bool canDeletePost;
  final VoidCallback onDeletePost;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Radial glow accent — mirrors transcript_screen
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8A56AC).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(
                      initials: post.initials,
                      imageUrl: post.avatarUrl,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _postAuthorName(post, isChinese: isChinese).toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF8A56AC),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.department.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF9AA0B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F1F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                        ),
                        if (canDeletePost) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: onDeletePost,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE05A5A).withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFE05A5A),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFEFEFF4), width: 0.8),
                  ),
                  child: Text(
                    post.content,
                    style: const TextStyle(
                      color: Color(0xFF34384A),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadReplyBubble extends StatelessWidget {
  const _ThreadReplyBubble({
    required this.reply,
    required this.canDelete,
    required this.onDelete,
    required this.isChinese,
  });

  final SocialReply reply;
  final bool canDelete;
  final VoidCallback onDelete;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    final isMine = !reply.isSeededDemo && _isCurrentUserOwner(reply.ownerId);

    final avatar = _Avatar(
      initials: reply.initials,
      imageUrl: reply.avatarUrl,
      size: 36,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 10)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                    child: Text(
                      _replyAuthorName(reply, isChinese: isChinese),
                      style: const TextStyle(
                        color: Color(0xFF767993),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? _deepPurple : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMine ? 20 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    reply.content,
                    style: TextStyle(
                      color: isMine ? Colors.white : const Color(0xFF34384A),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reply.time.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF9AA0B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE05A5A).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 11,
                                  color: Color(0xFFE05A5A),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isChinese ? '刪除' : 'DELETE',
                                  style: const TextStyle(
                                    color: Color(0xFFE05A5A),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[const SizedBox(width: 10), avatar],
        ],
      ),
    );
  }
}

class _ThreadReplyInput extends StatelessWidget {
  const _ThreadReplyInput({
    required this.controller,
    required this.onSend,
    required this.isChinese,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(
                color: Color(0xFF34384A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: isChinese ? '輸入回覆...' : 'Write a reply...',
                hintStyle: const TextStyle(
                  color: Color(0xFFCDD1DC),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                filled: true,
                fillColor: const Color(0xFFF6F6FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFEFEFF4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: _primaryPurple,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onSend,
            style: IconButton.styleFrom(
              backgroundColor: _deepPurple,
              foregroundColor: Colors.white,
              fixedSize: const Size(44, 44),
              shape: const CircleBorder(),
              elevation: 2,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SmallDot extends StatelessWidget {
  const _SmallDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFD1D5DC),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SocialFabHover extends StatefulWidget {
  const _SocialFabHover({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SocialFabHover> createState() => _SocialFabHoverState();
}

class _SocialFabHoverState extends State<_SocialFabHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: _deepPurple,
          elevation: _isHovered ? 12 : 8,
          shape: const CircleBorder(),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}