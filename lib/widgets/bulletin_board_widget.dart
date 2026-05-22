import 'package:flutter/material.dart';

import '../../models/bulletin_model.dart';
import 'package:enthusiast/screens/home/services/bulletin_firestore_service.dart';

class BulletinBoardScreen extends StatelessWidget {
  const BulletinBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = BulletinFirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Bulletin Board',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<BulletinItem>>(
        stream: service.watchBulletins(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7E3291),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load bulletins:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final bulletins = snapshot.data ?? [];

          if (bulletins.isEmpty) {
            return const Center(
              child: Text(
                'No bulletins found.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
            itemCount: bulletins.length,
            itemBuilder: (context, index) {
              final bulletin = bulletins[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BulletinCard(
                  bulletin: bulletin,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) {
                        return _BulletinDetailSheet(bulletin: bulletin);
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BulletinCard extends StatelessWidget {
  final BulletinItem bulletin;
  final VoidCallback onTap;

  const _BulletinCard({
    required this.bulletin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFF7E3291),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bulletin.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bulletin.snippet.isNotEmpty
                        ? bulletin.snippet
                        : bulletin.sender,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletinDetailSheet extends StatelessWidget {
  final BulletinItem bulletin;

  const _BulletinDetailSheet({
    required this.bulletin,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFF7E3291),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'BULLETIN DETAIL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                bulletin.title,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                bulletin.sender,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                bulletin.fullText,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}