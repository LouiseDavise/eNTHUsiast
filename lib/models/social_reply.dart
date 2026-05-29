import 'package:cloud_firestore/cloud_firestore.dart';

class SocialReply {
  const SocialReply({
    required this.id,
    required this.ownerId,
    required this.content,
    required this.userName,
    required this.userInitials,
    required this.createdAt,
    this.avatarUrl,
    this.isSeededDemo = false,
  });

  final String id;
  final String ownerId;
  final String content;
  final String userName;
  final String userInitials;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isSeededDemo;

  String get user => userName;
  String get initials => userInitials;
  String get time => displayTime;

  factory SocialReply.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return SocialReply(
      id: doc.id,
      ownerId: _readString(data['ownerId'], fallback: ''),
      content: _readString(data['content'], fallback: ''),
      userName: _readString(data['userName'], fallback: 'Unknown'),
      userInitials: _readString(data['userInitials'], fallback: 'UN'),
      avatarUrl: data['avatarUrl'] as String?,
      createdAt: _readDateTime(data['createdAt']),
      isSeededDemo: data['isSeededDemo'] == true,
    );
  }

  String get displayTime {
    final created = createdAt;
    if (created == null) return 'Just now';

    final now = DateTime.now();
    final diff = now.difference(created);

    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[created.month - 1]} ${created.day}';
  }

  static String _readString(dynamic value, {required String fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
