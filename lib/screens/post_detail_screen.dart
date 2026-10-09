import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_comment.text.trim().isEmpty) return;
    final error = await appState.addComment(postId: widget.postId, text: _comment.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _comment.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final post = appState.db.getPostById(widget.postId);
    final comments = appState.db.getCommentsByPostId(widget.postId);

    if (post == null) {
      return VenexusShell(
        title: appState.t('forum.title'),
        currentIndex: 2,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const [BackAction(route: '/forum'), SectionCard(child: Text('Publicação não encontrada.'))],
        ),
      );
    }

    return VenexusShell(
      title: appState.t('forum.title'),
      currentIndex: 2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BackAction(route: '/forum'),
          SectionCard(
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
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Text(post.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.purple, height: 1.25))),
                            if (post.authorRole == UserRole.admin) ...[const SizedBox(width: 8), const AdminBadge()],
                          ]),
                          const SizedBox(height: 4),
                          Text(post.authorName, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(post.body, style: const TextStyle(color: AppColors.gray600, height: 1.65)),
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.images
                        .map((value) => Container(
                              width: 116,
                              height: 116,
                              decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide(color: AppColors.gray200))),
                              clipBehavior: Clip.hardEdge,
                              child: StoredImage(value: value, height: 116, width: 116),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          PageIntro(title: 'Comentários', description: 'Participe da conversa com respeito e clareza.', accentColor: AppColors.blue),
          const SizedBox(height: 12),
          ...comments.map((comment) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  accentColor: comment.authorRole == UserRole.admin ? AppColors.blue : AppColors.gray200,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple))), if (comment.authorRole == UserRole.admin) const AdminBadge()]),
                    const SizedBox(height: 8),
                    Text(comment.text, style: const TextStyle(color: AppColors.gray600, height: 1.55)),
                  ]),
                ),
              )),
          const SizedBox(height: 6),
          SectionCard(
            accentColor: AppColors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _comment, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: appState.t('forum.comment'))),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _send, child: Text(appState.t('forum.comment').toUpperCase())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
