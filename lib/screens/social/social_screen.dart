import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/social_post.dart';
import '../../models/social_reply.dart';
import '../../services/social_firestore_service.dart';

const Color _primaryPurple = Color(0xFFA77CCB);
const Color _deepPurple = Color(0xFF722E85);
const Color _black = Color(0xFF1A1A1A);
const Color _backgroundWhite = Color(0xFFF9F9F8);
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

String _cleanPublicAuthorName(String userName) {
  final trimmed = userName.trim();
  if (trimmed.isEmpty) return 'Anonymous';
  if (trimmed.toLowerCase() == 'you') return 'Anonymous';
  return trimmed;
}

String _postAuthorName(SocialPost post) {
  if (!post.isSeededDemo && _isCurrentUserOwner(post.ownerId)) {
    return 'YOU';
  }

  return _cleanPublicAuthorName(post.userName);
}

String _replyAuthorName(SocialReply reply) {
  if (!reply.isSeededDemo && _isCurrentUserOwner(reply.ownerId)) {
    return 'YOU';
  }

  return _cleanPublicAuthorName(reply.userName);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to seed demo posts: $error'),
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

      final matchesDepartment =
          _selectedDepartment == 'All' ||
          post.department == _selectedDepartment;

      final matchesSearch =
          query.isEmpty ||
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

  @override
  Widget build(BuildContext context) {
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
                    _buildTopHeader(),
                    const SizedBox(height: 10),
                    _buildSearchBar(),
                    _buildFilterChips(),
                    Expanded(
                      child: StreamBuilder<List<SocialPost>>(
                        stream: _socialService.watchPosts(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildErrorState(snapshot.error.toString());
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
                            return _buildEmptyState();
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                            itemBuilder: (context, index) =>
                                _buildPostCard(posts[index]),
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
        ],
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(8, 5),
        child: FloatingActionButton(
          onPressed: _showCreatePostSheet,
          backgroundColor: _deepPurple,
          foregroundColor: Colors.white,
          elevation: 10,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Social',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -1.35,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Campus Community',
                  style: TextStyle(
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
                onPressed: _showSavedPostsSheet,
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

  Widget _buildSearchBar() {
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
            const Positioned(
              left: 52,
              child: IgnorePointer(child: _TypingSearchHint()),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final department = _departments[index];
          final selected = department == _selectedDepartment;

          return ChoiceChip(
            label: Text(department.toUpperCase()),
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
              letterSpacing: 0.8,
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

  Widget _buildPostCard(SocialPost post) {
    final isSaved = _savedPostIds.contains(post.id);
    final isMine = _isMyPost(post);

    return InkWell(
      onTap: () => _showPostDetailSheet(post),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
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
                            _postAuthorName(post).toUpperCase(),
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
                            const Text(
                              'YOUR FORUM',
                              style: TextStyle(
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
                  onPressed: () => _showPostOptionsSheet(post),
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
                  '${post.replyCount} replies',
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

  Widget _buildEmptyState() {
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
            const Text(
              'No discussions found',
              style: TextStyle(
                color: _black,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search or department filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
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

  Widget _buildErrorState(String message) {
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
            const Text(
              'Could not load discussions',
              style: TextStyle(
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

  void _showPostOptionsSheet(SocialPost post) {
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
                      title: isSaved ? 'Remove from saved' : 'Save post',
                      subtitle: isSaved
                          ? 'Remove this post from your saved list.'
                          : 'Keep this post for later.',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleSavePost(post);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (isMine) ...[
                      _PostOptionTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete forum',
                        subtitle:
                            'Delete this forum and all replies inside it.',
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeletePost(post);
                        },
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      _PostOptionTile(
                        icon: Icons.visibility_off_outlined,
                        title: 'Not interested',
                        subtitle: 'Hide this discussion from your feed.',
                        destructive: true,
                        onTap: () {
                          Navigator.pop(context);
                          _hidePost(post);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    _PostOptionTile(
                      icon: Icons.close_rounded,
                      title: 'Cancel',
                      subtitle: 'Close this menu.',
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

  void _toggleSavePost(SocialPost post) {
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
        content: Text(wasSaved ? 'Removed from saved.' : 'Post saved.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _hidePost(SocialPost post) {
    setState(() {
      _hiddenPostIds.add(post.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Post hidden.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _deepPurple,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 92),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
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

  Future<void> _confirmDeletePost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete forum?',
            style: TextStyle(
              color: _black,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will delete your forum and all replies inside it. This action cannot be undone in this prototype.',
            style: TextStyle(
              color: _mainTextGrey,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _mainTextGrey,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE05A5A),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _deletePost(post);
  }

  Future<void> _deletePost(SocialPost post) async {
    if (!_isMyPost(post)) return;

    try {
      await _socialService.deletePost(post.id);

      if (!mounted) return;
      setState(() {
        _savedPostIds.remove(post.id);
        _hiddenPostIds.remove(post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Forum deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete forum: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteReply(SocialPost post, SocialReply reply) async {
    if (!_isMyReply(reply)) return;

    try {
      await _socialService.deleteReply(postId: post.id, replyId: reply.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply deleted.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete reply: $error'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSavedPostsSheet() {
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
                    children: [
                      const Icon(
                        Icons.bookmark_rounded,
                        color: _deepPurple,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Saved Posts',
                          style: TextStyle(
                            color: _black,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _mainTextGrey,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: savedPosts.isEmpty
                        ? const _SavedEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemBuilder: (context, index) {
                              final post = savedPosts[index];

                              return _SavedPostTile(
                                post: post,
                                onOpen: () {
                                  Navigator.pop(context);
                                  _showPostDetailSheet(post);
                                },
                                onRemove: () {
                                  setState(() {
                                    _savedPostIds.remove(post.id);
                                  });
                                  Navigator.pop(context);
                                  _showSavedPostsSheet();
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

  void _showCreatePostSheet() {
    _titleController.clear();
    _contentController.clear();
    _showTitleError = false;
    _showContentError = false;
    _createDepartment = _selectedDepartment == 'All'
        ? 'General'
        : _selectedDepartment;

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
              child: _SheetShell(
                title: 'New Forum',
                subtitle: 'Share with the community',
                leadingIcon: Icons.mode_comment_outlined,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: "What's on your mind?",
                      showError: _showTitleError,
                      errorText: 'Title is required',
                      onChanged: (_) {
                        if (!_showTitleError) return;
                        setSheetState(() {
                          _showTitleError = false;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    const _SheetLabel('Department'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _createDepartment,
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
                              child: Text(department),
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
                      label: 'Content',
                      hint: 'Share your thoughts with the community...',
                      maxLines: 5,
                      showError: _showContentError,
                      errorText: 'Content is required',
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
                        onPressed: () => _validateAndCreatePost(setSheetState),
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
                        child: const Text('POST'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostDetailSheet(SocialPost post) {
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
                    onDeletePost: () {
                      Navigator.pop(context);
                      _confirmDeletePost(post);
                    },
                    onDeleteReply: (reply) {
                      unawaited(_deleteReply(post, reply));
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
          textInputAction: maxLines == 1
              ? TextInputAction.next
              : TextInputAction.newline,
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

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and content cannot be empty.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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
          content: Text('Failed to create forum: $error'),
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
      _replyController.text = content;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reply: $error'),
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColors[colorIndex],
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? _AvatarInitials(initials: initials, size: size)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _AvatarInitials(initials: initials, size: size);
              },
            ),
    );
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
  });

  final SocialPost post;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

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
          border: Border.all(color: _cardBorder),
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
                    '${_postAuthorName(post).toUpperCase()} • ${post.department.toUpperCase()}',
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
  const _SavedEmptyState();

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
            const Text(
              'No saved posts yet',
              style: TextStyle(
                color: _black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the three-dot menu on any discussion and save it for later.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
  const _TypingSearchHint();

  @override
  State<_TypingSearchHint> createState() => _TypingSearchHintState();
}

class _TypingSearchHintState extends State<_TypingSearchHint> {
  static const String _fullText = 'Search discussions...';

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
          child: _BlurBlob(size: 190, opacity: 0.13),
        ),
        Positioned(
          top: 360,
          right: -90,
          child: _BlurBlob(size: 220, opacity: 0.12),
        ),
        Positioned(
          bottom: 80,
          left: 30,
          child: _BlurBlob(size: 160, opacity: 0.10),
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
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: _deepPurple, size: 27),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _black,
                          fontSize: 22,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: _backgroundWhite,
                        foregroundColor: _mainTextGrey,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!.toUpperCase(),
                    style: const TextStyle(
                      color: _smallTextLightGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
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
      style: const TextStyle(
        color: _smallTextLightGrey,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
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
  });

  final SocialPost post;
  final List<SocialReply> replies;
  final TextEditingController replyController;
  final VoidCallback onSendReply;
  final void Function(SocialReply reply) onDeleteReply;
  final bool canDeletePost;
  final VoidCallback onDeletePost;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 18),
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
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF6F6F8),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 110),
                itemCount: replies.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      'REPLIES (${replies.length})',
                      style: const TextStyle(
                        color: Color(0xFF9AA0B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    );
                  }

                  final reply = replies[index - 1];

                  return _ThreadReplyBubble(
                    reply: reply,
                    canDelete:
                        !reply.isSeededDemo &&
                        _isCurrentUserOwner(reply.ownerId),
                    onDelete: () => onDeleteReply(reply),
                  );
                },
              ),
            ),
          ),
          _ThreadReplyInput(controller: replyController, onSend: onSendReply),
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
  });

  final SocialPost post;
  final bool canDeletePost;
  final VoidCallback onDeletePost;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                initials: post.initials,
                imageUrl: post.avatarUrl,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101427),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _postAuthorName(post).toUpperCase(),
                          style: const TextStyle(
                            color: _deepPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const _SmallDot(),
                        Text(
                          post.department.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF9AA0B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (canDeletePost) ...[
                          const _SmallDot(),
                          const Text(
                            'YOUR FORUM',
                            style: TextStyle(
                              color: _deepPurple,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canDeletePost)
                IconButton(
                  onPressed: onDeletePost,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF2F2),
                    foregroundColor: const Color(0xFFE05A5A),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F7FA),
                  foregroundColor: const Color(0xFF9AA0B8),
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            post.content,
            style: const TextStyle(
              color: Color(0xFF34384A),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w500,
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
  });

  final SocialReply reply;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isMine = !reply.isSeededDemo && _isCurrentUserOwner(reply.ownerId);

    final avatar = _Avatar(
      initials: reply.initials,
      imageUrl: reply.avatarUrl,
      size: 44,
    );

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: EdgeInsets.fromLTRB(18, 14, canDelete ? 8 : 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  _replyAuthorName(reply),
                  textAlign: isMine ? TextAlign.right : TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101427),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete reply',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE05A5A),
                    size: 19,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            reply.content,
            textAlign: isMine ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF34384A),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[avatar, const SizedBox(width: 14)],
            Flexible(
              child: Align(
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: bubble,
              ),
            ),
            if (isMine) ...[const SizedBox(width: 14), avatar],
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.only(
            left: isMine ? 0 : 58,
            right: isMine ? 58 : 0,
          ),
          child: Text(
            reply.time.toUpperCase(),
            textAlign: isMine ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              color: Color(0xFF9AA0B8),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadReplyInput extends StatelessWidget {
  const _ThreadReplyInput({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      color: Colors.white.withValues(alpha: 0.96),
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
                hintText: 'Write a reply...',
                hintStyle: const TextStyle(
                  color: Color(0xFFCDD1DC),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                filled: true,
                fillColor: const Color(0xFFFBFBFD),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE9E7EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: _primaryPurple,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            height: 58,
            child: FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                backgroundColor: _deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Icon(Icons.send_rounded, size: 24),
            ),
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
