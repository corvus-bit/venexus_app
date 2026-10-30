import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class ForumScreen extends StatelessWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = appState.posts;
    return VenexusShell(
      title: appState.t('forum.title'),
      currentIndex: 2,
      floatingActionButton: appState.isLoggedIn
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/forum/new'),
              child: const Icon(Icons.add, size: 32),
            )
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const BackAction(),
          PageIntro(
            title: appState.t('forum.title'),
            description: appState.t('forum.description'),
            accentColor: AppColors.yellow,
          ),
          const SizedBox(height: 20),
          if (posts.isEmpty)
            SectionCard(child: Text(appState.t('forum.noPosts')))
          else
            ...posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PostCard(post: post),
                )),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/forum/${post.id}'),
      child: SectionCard(
        accentColor: AppColors.yellow,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.yellow))),
                  child: const Icon(Icons.forum_outlined, color: AppColors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.purple, height: 1.25))),
                          if (post.authorRole == UserRole.admin) ...[const SizedBox(width: 8), const AdminBadge()],
                          if (canDeletePost(appState.currentUser, post)) DeleteIconButton(onPressed: () => deletePostWithConfirmation(context, post)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(post.authorName, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gray600, fontSize: 14, height: 1.65)),
          ],
        ),
      ),
    );
  }
}
/// Pede confirmação, apaga e avisa o resultado. Retorna true quando a publicação foi apagada.
Future<bool> deletePostWithConfirmation(BuildContext context, Post post) async {
  final confirmed = await confirmDelete(context, title: appState.t('forum.deleteTitle'), message: appState.t('forum.deleteMessage'));
  if (!confirmed || !context.mounted) return false;
  final error = await appState.deletePost(post);
  if (!context.mounted) return error == null;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? appState.t('forum.deleted'))));
  return error == null;
}
