import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/models.dart';
import '../core/permissions.dart';
import '../main.dart';
import '../widgets/venexus_shell.dart';
import 'forum_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _comment = TextEditingController();
  final _inputFocus = FocusNode();
  final _expandedThreads = <String>{};
  Comment? _replyTo;
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _startReply(Comment? comment) {
    setState(() {
      _replyTo = comment;
      if (comment != null) _expandedThreads.add(comment.parentId ?? comment.id);
    });
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTo = null);

  Future<void> _send() async {
    if (_sending || _comment.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final error = await appState.addComment(postId: widget.postId, text: _comment.text, replyTo: _replyTo);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _comment.clear();
    setState(() => _replyTo = null);
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
          children: [const BackAction(route: '/forum'), SectionCard(child: Text(appState.t('forum.notFound')))],
        ),
      );
    }

    final roots = comments.where((comment) => !comment.isReply).toList();
    final rootIds = roots.map((comment) => comment.id).toSet();
    final repliesByRoot = <String, List<Comment>>{};
    for (final comment in comments) {
      // Resposta cujo comentário raiz não existe mais vira comentário normal.
      if (comment.isReply && rootIds.contains(comment.parentId)) {
        repliesByRoot.putIfAbsent(comment.parentId!, () => []).add(comment);
      } else if (comment.isReply) {
        roots.add(comment);
      }
    }

    return VenexusShell(
      title: appState.t('forum.title'),
      currentIndex: 2,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const BackAction(route: '/forum'),
                _PostContent(post: post, commentCount: comments.length, onReply: () => _startReply(null)),
                const SizedBox(height: 20),
                Text(
                  '${appState.t('forum.comments')} (${comments.length})',
                  style: const TextStyle(color: AppColors.purple, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (roots.isEmpty)
                  Text(appState.t('forum.noComments'), style: const TextStyle(color: AppColors.muted, height: 1.5))
                else
                  for (final root in roots)
                    _CommentThread(
                      comment: root,
                      replies: repliesByRoot[root.id] ?? const [],
                      expanded: _expandedThreads.contains(root.id),
                      highlightedId: _replyTo?.id,
                      onReply: _startReply,
                      onToggle: () => setState(() {
                        if (!_expandedThreads.remove(root.id)) _expandedThreads.add(root.id);
                      }),
                    ),
              ],
            ),
          ),
          _CommentComposer(
            controller: _comment,
            focusNode: _inputFocus,
            replyTo: _replyTo,
            sending: _sending,
            onCancelReply: _cancelReply,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _PostContent extends StatelessWidget {
  const _PostContent({required this.post, required this.commentCount, required this.onReply});

  final Post post;
  final int commentCount;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
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
                      if (canDeletePost(appState.currentUser, post))
                        DeleteIconButton(
                          onPressed: () async {
                            final deleted = await deletePostWithConfirmation(context, post);
                            if (deleted && context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/forum', (_) => false);
                          },
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${post.authorName} · ${_timeAgo(post.createdAt)}',
                      style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
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
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.gray100),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.mode_comment_outlined, size: 18),
                label: Text(appState.t('forum.reply')),
              ),
              const Spacer(),
              Text('$commentCount ${appState.t('forum.comments').toLowerCase()}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends StatelessWidget {
  const _CommentThread({
    required this.comment,
    required this.replies,
    required this.expanded,
    required this.highlightedId,
    required this.onReply,
    required this.onToggle,
  });

  final Comment comment;
  final List<Comment> replies;
  final bool expanded;
  final String? highlightedId;
  final ValueChanged<Comment> onReply;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(comment: comment, highlighted: highlightedId == comment.id, onReply: () => onReply(comment)),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 24, child: Divider(color: AppColors.gray300, thickness: 1)),
                          const SizedBox(width: 8),
                          Text(
                            expanded ? appState.t('forum.hideReplies') : '${appState.t('forum.viewReplies')} (${replies.length})',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded)
                    for (final reply in replies)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _CommentTile(
                          comment: reply,
                          compact: true,
                          highlighted: highlightedId == reply.id,
                          onReply: () => onReply(reply),
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onReply, this.highlighted = false, this.compact = false});

  final Comment comment;
  final VoidCallback onReply;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isAdmin = comment.authorRole == UserRole.admin;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(6),
      color: highlighted ? const Color(0x14033065) : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InitialAvatar(name: comment.authorName, size: compact ? 26 : 32, admin: isAdmin),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_timeAgo(comment.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (isAdmin) ...[const SizedBox(width: 6), const AdminBadge()],
                  ],
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    if (comment.replyToName != null && comment.replyToName!.isNotEmpty)
                      TextSpan(
                        text: '@${comment.replyToName} ',
                        style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800),
                      ),
                    TextSpan(text: comment.text),
                  ]),
                  style: const TextStyle(color: AppColors.gray700, height: 1.5),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _CommentAction(label: appState.t('forum.reply'), onTap: onReply),
                    if (canDeleteComment(appState.currentUser, comment)) ...[
                      const SizedBox(width: 16),
                      _CommentAction(
                        label: appState.t('common.delete'),
                        color: AppColors.red,
                        onTap: () => _deleteCommentWithConfirmation(context, comment),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({required this.label, required this.onTap, this.color = AppColors.muted});

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

Future<void> _deleteCommentWithConfirmation(BuildContext context, Comment comment) async {
  final confirmed = await confirmDelete(
    context,
    title: appState.t('forum.commentDeleteTitle'),
    message: appState.t('forum.commentDeleteMessage'),
  );
  if (!confirmed || !context.mounted) return;
  final error = await appState.deleteComment(comment);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? appState.t('forum.commentDeleted'))));
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.size, this.admin = false});

  final String name;
  final double size;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        border: Border.all(color: admin ? AppColors.blue : AppColors.yellow),
      ),
      child: Text(initial, style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: size * .42)),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Comment? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.gray200)),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (replyTo != null)
            Container(
              color: AppColors.gray50,
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${appState.t('forum.replyingTo')} '),
                        TextSpan(text: replyTo!.authorName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: appState.t('common.close'),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18, color: AppColors.gray600),
                    onPressed: onCancelReply,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: replyTo == null ? appState.t('forum.commentHint') : appState.t('forum.replyHint'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final canSend = !sending && controller.text.trim().isNotEmpty;
                    return IconButton(
                      tooltip: appState.t('forum.comment'),
                      onPressed: canSend ? onSend : null,
                      icon: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.send, color: canSend ? AppColors.blue : AppColors.gray300),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '';
  final diff = DateTime.now().difference(date.toLocal());
  final es = appState.language == AppLanguage.es;
  if (diff.inMinutes < 1) return es ? 'ahora' : 'agora';
  if (diff.inHours < 1) return '${diff.inMinutes} min';
  if (diff.inDays < 1) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return '${(diff.inDays / 7).floor()} sem';
}
