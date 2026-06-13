import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/social_post.dart';
import '../models/social_reply.dart';

class SocialFirestoreService {
  SocialFirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String postsCollection = 'socialPosts';
  static const String demoSeedBatchId = 'social-demo-v1';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _postsRef {
    return _firestore.collection(postsCollection);
  }

  Future<User> _ensureSignedIn() async {
    final existingUser = _auth.currentUser;
    if (existingUser != null) {
      return existingUser;
    }

    final credential = await _auth.signInAnonymously();
    final user = credential.user;

    if (user == null) {
      throw StateError('Could not sign in anonymously.');
    }

    return user;
  }

  Stream<List<SocialPost>> watchPosts() {
    return Stream.fromFuture(_ensureSignedIn()).asyncExpand((_) {
      return _postsRef.orderBy('createdAt', descending: true).snapshots().map((
        snapshot,
      ) {
        return snapshot.docs.map(SocialPost.fromDoc).toList();
      });
    });
  }

  Stream<List<SocialReply>> watchReplies(String postId) {
    return Stream.fromFuture(_ensureSignedIn()).asyncExpand((_) {
      return _postsRef
          .doc(postId)
          .collection('replies')
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map(SocialReply.fromDoc).toList();
          });
    });
  }

  Future<void> createPost({
    required String title,
    required String content,
    required String department,
  }) async {
    final user = await _ensureSignedIn();
    final userName = _displayNameFor(user);
    final userInitials = _initialsFor(userName);
    final avatarUrl = await _profilePhotoUrlFor(user);

    await _postsRef.doc().set({
      'ownerId': user.uid,
      'title': title.trim(),
      'content': content.trim(),
      'department': department.trim().isEmpty ? 'General' : department.trim(),
      'userName': userName,
      'userInitials': userInitials,
      'avatarUrl': avatarUrl,
      'replyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSeededDemo': false,
    });
  }

  Future<void> createReply({
    required String postId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) return;

    final user = await _ensureSignedIn();
    final userName = _displayNameFor(user);
    final userInitials = _initialsFor(userName);
    final avatarUrl = await _profilePhotoUrlFor(user);

    final postRef = _postsRef.doc(postId);
    final replyRef = postRef.collection('replies').doc();

    final batch = _firestore.batch();

    batch.set(replyRef, {
      'ownerId': user.uid,
      'content': trimmedContent,
      'userName': userName,
      'userInitials': userInitials,
      'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isSeededDemo': false,
    });

    batch.update(postRef, {
      'replyCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteReply({
    required String postId,
    required String replyId,
  }) async {
    await _ensureSignedIn();

    final postRef = _postsRef.doc(postId);
    final replyRef = postRef.collection('replies').doc(replyId);

    final batch = _firestore.batch();

    batch.delete(replyRef);
    batch.update(postRef, {
      'replyCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deletePost(String postId) async {
    await _ensureSignedIn();

    final postRef = _postsRef.doc(postId);
    final repliesSnapshot = await postRef.collection('replies').get();

    final batch = _firestore.batch();

    for (final replyDoc in repliesSnapshot.docs) {
      batch.delete(replyDoc.reference);
    }

    batch.delete(postRef);

    await batch.commit();
  }

  Future<void> seedDemoPostsIfNeeded() async {
    final user = await _ensureSignedIn();

    final existingSeed = await _postsRef
        .where('seedBatchId', isEqualTo: demoSeedBatchId)
        .limit(1)
        .get();

    if (existingSeed.docs.isNotEmpty) return;

    final now = DateTime.now();
    final batch = _firestore.batch();

    for (final seed in _demoPosts) {
      final postRef = _postsRef.doc(seed.id);
      final postCreatedAt = now.subtract(seed.age);

      batch.set(postRef, {
        'ownerId': user.uid,
        'title': seed.title,
        'content': seed.content,
        'department': seed.department,
        'userName': seed.userName,
        'userInitials': seed.userInitials,
        'avatarUrl': _avatarUrl(seed.avatarSeed),
        'replyCount': seed.replies.length,
        'createdAt': Timestamp.fromDate(postCreatedAt),
        'updatedAt': Timestamp.fromDate(postCreatedAt),
        'isSeededDemo': true,
        'seedBatchId': demoSeedBatchId,
      });

      for (final reply in seed.replies) {
        final replyRef = postRef.collection('replies').doc(reply.id);
        final replyCreatedAt = now.subtract(reply.age);

        batch.set(replyRef, {
          'ownerId': user.uid,
          'content': reply.content,
          'userName': reply.userName,
          'userInitials': reply.userInitials,
          'avatarUrl': _avatarUrl(reply.avatarSeed),
          'createdAt': Timestamp.fromDate(replyCreatedAt),
          'isSeededDemo': true,
          'seedBatchId': demoSeedBatchId,
        });
      }
    }

    await batch.commit();
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Anonymous';
  }

  String _initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'AN';

    if (words.length == 1) {
      final word = words.first;
      return word.length == 1
          ? word.toUpperCase()
          : word.substring(0, 2).toUpperCase();
    }

    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Future<String> _profilePhotoUrlFor(User user) async {
    final ccxpPhoto = await _photoUrlFromCollection('ccxpUsers', user.uid);
    if (ccxpPhoto != null) return ccxpPhoto;

    final userProfilePhoto = await _photoUrlFromCollection('users', user.uid);
    if (userProfilePhoto != null) return userProfilePhoto;

    return _avatarUrl(user.uid);
  }

  Future<String?> _photoUrlFromCollection(String collection, String uid) async {
    final snapshot = await _firestore.collection(collection).doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    return _cleanPhotoUrl(data['photoUrl']);
  }

  String? _cleanPhotoUrl(Object? value) {
    final photoUrl = value?.toString().trim() ?? '';
    if (photoUrl.isEmpty) return null;
    return photoUrl;
  }

  String _avatarUrl(String seed) {
    return 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(seed)}';
  }
}

class _DemoPostSeed {
  const _DemoPostSeed({
    required this.id,
    required this.title,
    required this.userName,
    required this.userInitials,
    required this.department,
    required this.content,
    required this.avatarSeed,
    required this.age,
    required this.replies,
  });

  final String id;
  final String title;
  final String userName;
  final String userInitials;
  final String department;
  final String content;
  final String avatarSeed;
  final Duration age;
  final List<_DemoReplySeed> replies;
}

class _DemoReplySeed {
  const _DemoReplySeed({
    required this.id,
    required this.userName,
    required this.userInitials,
    required this.content,
    required this.avatarSeed,
    required this.age,
  });

  final String id;
  final String userName;
  final String userInitials;
  final String content;
  final String avatarSeed;
  final Duration age;
}

const List<_DemoPostSeed> _demoPosts = [
  _DemoPostSeed(
    id: 'seed-post-1',
    title: 'Looking for a Lab Partner',
    userName: 'Sarah M.',
    userInitials: 'SM',
    department: 'Design',
    content:
        'Any design student interested in partnering up for the DES 115 final project? I focus on prototyping.',
    avatarSeed: 'Sarah',
    age: Duration(hours: 2),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-1-1',
        userName: 'User7',
        userInitials: 'U7',
        content: 'Thanks for sharing this!',
        avatarSeed: 'User7',
        age: Duration(hours: 1),
      ),
      _DemoReplySeed(
        id: 'seed-reply-1-2',
        userName: 'User13',
        userInitials: 'U13',
        content: 'I might be interested, check your DMs.',
        avatarSeed: 'User13',
        age: Duration(minutes: 30),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-2',
    title: 'DES 102 Study Session',
    userName: 'Alex Chen',
    userInitials: 'AC',
    department: 'Design',
    content:
        'Room 402, 3PM today. Reviewing color theory and composition fundamentals. All welcome!',
    avatarSeed: 'Alex',
    age: Duration(hours: 3),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-2-1',
        userName: 'User14',
        userInitials: 'U14',
        content: 'I will join after class.',
        avatarSeed: 'User14',
        age: Duration(hours: 2, minutes: 30),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-3',
    title: 'Summer Internship Forum',
    userName: 'Prototyping Club',
    userInitials: 'PC',
    department: 'General',
    content:
        'Sharing resources and tips for student portfolios. Check out the pinned thread for links.',
    avatarSeed: 'Club',
    age: Duration(hours: 6),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-3-1',
        userName: 'User21',
        userInitials: 'U21',
        content: 'Can someone share the portfolio template?',
        avatarSeed: 'User21',
        age: Duration(hours: 5),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-4',
    title: 'Weekly Q&A Thread',
    userName: 'Prof. Miller',
    userInitials: 'PM',
    department: 'HSS',
    content:
        "Post your questions regarding this week's lecture on Visual Systems Theory below.",
    avatarSeed: 'Professor',
    age: Duration(hours: 8),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-4-1',
        userName: 'Student A',
        userInitials: 'SA',
        content: 'Could you explain the reading again?',
        avatarSeed: 'StudentA',
        age: Duration(hours: 7),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-5',
    title: 'Algorithms Homework Help',
    userName: 'Kevin L.',
    userInitials: 'KL',
    department: 'CS',
    content:
        'Struggling with the dynamic programming section. Anyone want to review together?',
    avatarSeed: 'Kevin',
    age: Duration(minutes: 20),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-5-1',
        userName: 'Nathan',
        userInitials: 'NT',
        content: 'I can review recurrence relation with you.',
        avatarSeed: 'Nathan',
        age: Duration(minutes: 5),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-6',
    title: 'Circuit Design Tips',
    userName: 'Li Wang',
    userInitials: 'LW',
    department: 'EE',
    content:
        'Sharing some techniques for low-power CMOS design. Check the doc.',
    avatarSeed: 'LiWang',
    age: Duration(hours: 5),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-6-1',
        userName: 'Chen Yu',
        userInitials: 'CY',
        content: 'Can you share the CMOS checklist?',
        avatarSeed: 'ChenYu',
        age: Duration(hours: 4),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-7',
    title: 'Embedded Systems Hackathon',
    userName: 'Michael T.',
    userInitials: 'MT',
    department: 'EE',
    content:
        "Looking for teammates who know C and ARM architecture. Let's build something cool.",
    avatarSeed: 'Michael',
    age: Duration(days: 1),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-7-1',
        userName: 'Ray Huang',
        userInitials: 'RH',
        content: 'I know basic ARM. Interested.',
        avatarSeed: 'Ray',
        age: Duration(hours: 12),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-8',
    title: 'Math Olympiad Prep',
    userName: 'Emma W.',
    userInitials: 'EW',
    department: 'Math',
    content: 'Practicing number theory problems tonight. Join us on Discord!',
    avatarSeed: 'Emma',
    age: Duration(hours: 7),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-8-1',
        userName: 'Tom H.',
        userInitials: 'TH',
        content: 'Can you send the Discord link?',
        avatarSeed: 'Tom',
        age: Duration(hours: 6),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-9',
    title: 'Ethics in AI Discussion',
    userName: 'Marcus G.',
    userInitials: 'MG',
    department: 'CS',
    content:
        'Exploring the social implications of automated decision-making. Very relevant today.',
    avatarSeed: 'Marcus',
    age: Duration(hours: 9),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-9-1',
        userName: 'Sofia R.',
        userInitials: 'SR',
        content: 'This is relevant for our AI policy class too.',
        avatarSeed: 'Sofia',
        age: Duration(hours: 8),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-10',
    title: 'Business Case Competition',
    userName: 'Alice W.',
    userInitials: 'AW',
    department: 'Business',
    content:
        'Looking for 2 more members to join our team for the upcoming case competition. Finance background preferred.',
    avatarSeed: 'Alice',
    age: Duration(days: 2),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-10-1',
        userName: 'Brian T.',
        userInitials: 'BT',
        content: 'I can help with market sizing and deck structure.',
        avatarSeed: 'Brian',
        age: Duration(days: 1),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-11',
    title: 'Quantum Mechanics Review Group',
    userName: 'Nina Huang',
    userInitials: 'NH',
    department: 'Physics',
    content:
        'Reviewing wave functions, operators, and measurement problems before next week’s quiz. Everyone is welcome.',
    avatarSeed: 'Nina',
    age: Duration(hours: 10),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-11-1',
        userName: 'Oscar Lin',
        userInitials: 'OL',
        content: 'Can we also cover uncertainty principle problems?',
        avatarSeed: 'Oscar',
        age: Duration(hours: 9),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-12',
    title: 'Campus Sketch Walk',
    userName: 'Art Club',
    userInitials: 'AC',
    department: 'Arts',
    content:
        'We are meeting near the lake to sketch architecture and campus scenes this Saturday morning.',
    avatarSeed: 'ArtClub',
    age: Duration(hours: 11),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-12-1',
        userName: 'Maya Chen',
        userInitials: 'MC',
        content: 'Do beginners need to bring their own materials?',
        avatarSeed: 'Maya',
        age: Duration(hours: 10),
      ),
    ],
  ),
  _DemoPostSeed(
    id: 'seed-post-13',
    title: 'Biology Lab Notes Exchange',
    userName: 'Grace Lee',
    userInitials: 'GL',
    department: 'Life Science',
    content:
        'Looking for classmates who want to exchange lab notes and prepare for the cell biology practical together.',
    avatarSeed: 'Grace',
    age: Duration(hours: 12),
    replies: [
      _DemoReplySeed(
        id: 'seed-reply-13-1',
        userName: 'Henry Kao',
        userInitials: 'HK',
        content: 'I can share my microscopy notes.',
        avatarSeed: 'Henry',
        age: Duration(hours: 11),
      ),
    ],
  ),
];
