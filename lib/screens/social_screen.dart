import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

const Color _primaryPurple = Color(0xFFA77CCB);
const Color _deepPurple = Color(0xFF722E85);
const Color _black = Color(0xFF1A1A1A);
const Color _backgroundWhite = Color(0xFFF9F9F8);
const Color _mainTextGrey = Color(0xFF767993);
const Color _darkGreyText = Color(0xFF34384A);
const Color _hintTextGrey = Color(0xFFB3B7C8);
const Color _smallTextLightGrey = Color(0xFFD1D5DC);
const Color _cardBorder = Color(0xFFE8E1EF);

String _avatarUrl(String seed) {
  return 'https://api.dicebear.com/7.x/avataaars/png?seed=$seed';
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

  late final List<_SocialPost> _posts;
  String _selectedDepartment = 'All';
  String _createDepartment = 'General';

  @override
  void initState() {
    super.initState();

    _posts = [
      _SocialPost(
        id: 'post-1',
        title: 'Looking for a Lab Partner',
        user: 'Sarah M.',
        department: 'Design',
        content:
            'Any design student interested in partnering up for the DES 115 final project? I focus on prototyping.',
        time: '2m ago',
        initials: 'SM',
        avatarUrl: _avatarUrl('Sarah'),
        replyCountOverride: 4,
        replies: [
          _SocialReply(
            user: 'User7',
            initials: 'U7',
            avatarUrl: _avatarUrl('User7'),
            content: 'Thanks for sharing this!',
            time: '1h ago',
          ),
          _SocialReply(
            user: 'User13',
            initials: 'U13',
            avatarUrl: _avatarUrl('User13'),
            content: 'I might be interested, check your DMs.',
            time: '30m ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-2',
        title: 'DES 102 Study Session',
        user: 'Alex Chen',
        department: 'Design',
        content:
            'Room 402, 3PM today. Reviewing color theory and composition fundamentals. All welcome!',
        time: '1h ago',
        initials: 'AC',
        avatarUrl: _avatarUrl('Alex'),
        replyCountOverride: 12,
        replies: [
          _SocialReply(
            user: 'User14',
            initials: 'U14',
            avatarUrl: _avatarUrl('User14'),
            content: 'I will join after class.',
            time: '45m ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-3',
        title: 'Summer Internship Forum',
        user: 'Prototyping Club',
        department: 'General',
        content:
            'Sharing resources and tips for student portfolios. Check out the pinned thread for links.',
        time: '3h ago',
        initials: 'PC',
        avatarUrl: _avatarUrl('Club'),
        replyCountOverride: 28,
        replies: [
          _SocialReply(
            user: 'User21',
            initials: 'U21',
            avatarUrl: _avatarUrl('User21'),
            content: 'Can someone share the portfolio template?',
            time: '2h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-4',
        title: 'Weekly Q&A Thread',
        user: 'Prof. Miller',
        department: 'HSS',
        content:
            "Post your questions regarding this week's lecture on Visual Systems Theory below.",
        time: '5h ago',
        initials: 'PM',
        avatarUrl: _avatarUrl('Professor'),
        replyCountOverride: 45,
        replies: [
          _SocialReply(
            user: 'Student A',
            initials: 'SA',
            avatarUrl: _avatarUrl('StudentA'),
            content: 'Could you explain the reading again?',
            time: '3h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-5',
        title: 'Algorithms Homework Help',
        user: 'Kevin L.',
        department: 'CS',
        content:
            'Struggling with the dynamic programming section. Anyone want to review together?',
        time: '10m ago',
        initials: 'KL',
        avatarUrl: _avatarUrl('Kevin'),
        replyCountOverride: 3,
        replies: [
          _SocialReply(
            user: 'Nathan',
            initials: 'NT',
            avatarUrl: _avatarUrl('Nathan'),
            content: 'I can review recurrence relation with you.',
            time: '5m ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-6',
        title: 'Circuit Design Tips',
        user: 'Li Wang',
        department: 'EE',
        content:
            'Sharing some techniques for low-power CMOS design. Check the doc.',
        time: '2h ago',
        initials: 'LW',
        avatarUrl: _avatarUrl('LiWang'),
        replyCountOverride: 22,
        replies: [
          _SocialReply(
            user: 'Chen Yu',
            initials: 'CY',
            avatarUrl: _avatarUrl('ChenYu'),
            content: 'Can you share the CMOS checklist?',
            time: '1h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-7',
        title: 'Embedded Systems Hackathon',
        user: 'Michael T.',
        department: 'EE',
        content:
            "Looking for teammates who know C and ARM architecture. Let's build something cool.",
        time: '1d ago',
        initials: 'MT',
        avatarUrl: _avatarUrl('Michael'),
        replyCountOverride: 8,
        replies: [
          _SocialReply(
            user: 'Ray Huang',
            initials: 'RH',
            avatarUrl: _avatarUrl('Ray'),
            content: 'I know basic ARM. Interested.',
            time: '12h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-8',
        title: 'Math Olympiad Prep',
        user: 'Emma W.',
        department: 'Math',
        content:
            'Practicing number theory problems tonight. Join us on Discord!',
        time: '4h ago',
        initials: 'EW',
        avatarUrl: _avatarUrl('Emma'),
        replyCountOverride: 10,
        replies: [
          _SocialReply(
            user: 'Tom H.',
            initials: 'TH',
            avatarUrl: _avatarUrl('Tom'),
            content: 'Can you send the Discord link?',
            time: '3h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-9',
        title: 'Ethics in AI Discussion',
        user: 'Marcus G.',
        department: 'CS',
        content:
            'Exploring the social implications of automated decision-making. Very relevant today.',
        time: '6h ago',
        initials: 'MG',
        avatarUrl: _avatarUrl('Marcus'),
        replyCountOverride: 35,
        replies: [
          _SocialReply(
            user: 'Sofia R.',
            initials: 'SR',
            avatarUrl: _avatarUrl('Sofia'),
            content: 'This is relevant for our AI policy class too.',
            time: '5h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-10',
        title: 'Business Case Competition',
        user: 'Alice W.',
        department: 'Business',
        content:
            'Looking for 2 more members to join our team for the upcoming case competition. Finance background preferred.',
        time: '2d ago',
        initials: 'AW',
        avatarUrl: _avatarUrl('Alice'),
        replyCountOverride: 12,
        replies: [
          _SocialReply(
            user: 'Brian T.',
            initials: 'BT',
            avatarUrl: _avatarUrl('Brian'),
            content: 'I can help with market sizing and deck structure.',
            time: '1d ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-11',
        title: 'Quantum Mechanics Review Group',
        user: 'Nina Huang',
        department: 'Physics',
        content:
            'Reviewing wave functions, operators, and measurement problems before next week’s quiz. Everyone is welcome.',
        time: '4h ago',
        initials: 'NH',
        avatarUrl: _avatarUrl('Nina'),
        replyCountOverride: 16,
        replies: [
          _SocialReply(
            user: 'Oscar Lin',
            initials: 'OL',
            avatarUrl: _avatarUrl('Oscar'),
            content: 'Can we also cover uncertainty principle problems?',
            time: '3h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-12',
        title: 'Campus Sketch Walk',
        user: 'Art Club',
        department: 'Arts',
        content:
            'We are meeting near the lake to sketch architecture and campus scenes this Saturday morning.',
        time: '6h ago',
        initials: 'AC',
        avatarUrl: _avatarUrl('ArtClub'),
        replyCountOverride: 9,
        replies: [
          _SocialReply(
            user: 'Maya Chen',
            initials: 'MC',
            avatarUrl: _avatarUrl('Maya'),
            content: 'Do beginners need to bring their own materials?',
            time: '5h ago',
          ),
        ],
      ),
      _SocialPost(
        id: 'post-13',
        title: 'Biology Lab Notes Exchange',
        user: 'Grace Lee',
        department: 'Life Science',
        content:
            'Looking for classmates who want to exchange lab notes and prepare for the cell biology practical together.',
        time: '7h ago',
        initials: 'GL',
        avatarUrl: _avatarUrl('Grace'),
        replyCountOverride: 14,
        replies: [
          _SocialReply(
            user: 'Henry Kao',
            initials: 'HK',
            avatarUrl: _avatarUrl('Henry'),
            content: 'I can share my microscopy notes.',
            time: '6h ago',
          ),
        ],
      ),
    ];

    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  List<_SocialPost> get _filteredPosts {
    final query = _searchController.text.trim().toLowerCase();

    return _posts.where((post) {
      final notHidden = !_hiddenPostIds.contains(post.id);

      final matchesDepartment =
          _selectedDepartment == 'All' ||
          post.department == _selectedDepartment;

      final matchesSearch =
          query.isEmpty ||
          post.title.toLowerCase().contains(query) ||
          post.content.toLowerCase().contains(query) ||
          post.user.toLowerCase().contains(query);

      return notHidden && matchesDepartment && matchesSearch;
    }).toList();
  }

  List<_SocialPost> get _savedPosts {
    return _posts.where((post) => _savedPostIds.contains(post.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts;

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
                    const SizedBox(height: 18),
                    _buildTopActions(),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    _buildFilterChips(),
                    Expanded(
                      child: posts.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                100,
                              ),
                              itemBuilder: (context, index) =>
                                  _buildPostCard(posts[index]),
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemCount: posts.length,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
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

  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          const Spacer(),
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
                  fixedSize: const Size(44, 44),
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
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
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

  Widget _buildPostCard(_SocialPost post) {
    final isSaved = _savedPostIds.contains(post.id);

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
                            post.user.toUpperCase(),
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

  void _showPostOptionsSheet(_SocialPost post) {
    final isSaved = _savedPostIds.contains(post.id);

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

  void _toggleSavePost(_SocialPost post) {
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

  void _hidePost(_SocialPost post) {
    setState(() {
      _hiddenPostIds.add(post.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post hidden.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _hiddenPostIds.remove(post.id);
            });
          },
        ),
      ),
    );
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
                    ),
                    const SizedBox(height: 18),
                    const _SheetLabel('Department'),
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
                      label: 'Body',
                      hint: 'Describe your thoughts...',
                      maxLines: 5,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _addMockPost,
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

  void _showPostDetailSheet(_SocialPost post) {
    _replyController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: _ThreadDetailPanel(
                    post: post,
                    replyController: _replyController,
                    onSendReply: () {
                      _addMockReply(post);
                      setSheetState(() {});
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryPurple, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  void _addMockPost() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      return;
    }

    setState(() {
      _posts.insert(
        0,
        _SocialPost(
          id: 'post-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          user: 'You',
          department: _createDepartment,
          content: content,
          time: 'Just now',
          initials: 'YO',
          avatarUrl: _avatarUrl('You'),
          replies: [],
        ),
      );
      _selectedDepartment = 'All';
      _searchController.clear();
    });

    Navigator.pop(context);
  }

  void _addMockReply(_SocialPost post) {
    final content = _replyController.text.trim();

    if (content.isEmpty) {
      return;
    }

    setState(() {
      post.replies.add(
        _SocialReply(
          user: 'You',
          initials: 'YO',
          avatarUrl: _avatarUrl('You'),
          content: content,
          time: 'Just now',
        ),
      );

      post.replyCountOverride = post.replyCount + 1;
      _replyController.clear();
    });
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

  final _SocialPost post;
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
                    '${post.user.toUpperCase()} • ${post.department.toUpperCase()}',
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
    required this.replyController,
    required this.onSendReply,
  });

  final _SocialPost post;
  final TextEditingController replyController;
  final VoidCallback onSendReply;

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
          _ThreadHeader(post: post),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF6F6F8),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 110),
                itemCount: post.replies.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Text(
                      'REPLIES (${post.replyCount})',
                      style: const TextStyle(
                        color: Color(0xFF9AA0B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    );
                  }

                  final reply = post.replies[index - 1];
                  return _ThreadReplyBubble(reply: reply);
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
  const _ThreadHeader({required this.post});

  final _SocialPost post;

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
                          post.user.toUpperCase(),
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
                      ],
                    ),
                  ],
                ),
              ),
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
  const _ThreadReplyBubble({required this.reply});

  final _SocialReply reply;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(initials: reply.initials, imageUrl: reply.avatarUrl, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reply.user,
                      style: const TextStyle(
                        color: Color(0xFF101427),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reply.content,
                      style: const TextStyle(
                        color: Color(0xFF34384A),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reply.time.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF9AA0B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ],
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
                backgroundColor: const Color(0xFFA7A7A7),
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Icon(Icons.add_rounded, size: 30),
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

class _SocialPost {
  _SocialPost({
    required this.id,
    required this.title,
    required this.user,
    required this.department,
    required this.content,
    required this.time,
    required this.initials,
    required this.replies,
    this.avatarUrl,
    this.replyCountOverride,
  });

  final String id;
  final String title;
  final String user;
  final String department;
  final String content;
  final String time;
  final String initials;
  final String? avatarUrl;
  final List<_SocialReply> replies;
  int? replyCountOverride;

  int get replyCount => replyCountOverride ?? replies.length;
}

class _SocialReply {
  const _SocialReply({
    required this.user,
    required this.initials,
    required this.content,
    required this.time,
    this.avatarUrl,
  });

  final String user;
  final String initials;
  final String content;
  final String time;
  final String? avatarUrl;
}
