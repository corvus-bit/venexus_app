import 'package:flutter/material.dart';

import '../core/models.dart';
import '../main.dart';

Future<void> showEditPostDialog(BuildContext context, Post post) => showDialog<void>(
      context: context,
      builder: (_) => _ForumEditDialog(post: post),
    );

Future<void> showEditCommentDialog(BuildContext context, Comment comment) => showDialog<void>(
      context: context,
      builder: (_) => _ForumEditDialog(comment: comment),
    );

class _ForumEditDialog extends StatefulWidget {
  const _ForumEditDialog({this.post, this.comment}) : assert((post == null) != (comment == null));

  final Post? post;
  final Comment? comment;

  @override
  State<_ForumEditDialog> createState() => _ForumEditDialogState();
}

class _ForumEditDialogState extends State<_ForumEditDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.post?.title);
  late final TextEditingController _text = TextEditingController(text: widget.post?.body ?? widget.comment?.text);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final value = _text.text.trim();
    if (widget.post != null && (title.isEmpty || title.length > 200 || value.isEmpty || value.length > 5000)) {
      setState(() => _error = appState.t('forum.invalidPost'));
      return;
    }
    if (widget.comment != null && (value.isEmpty || value.length > 2000)) {
      setState(() => _error = appState.t('forum.invalidComment'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = widget.post != null
        ? await appState.updatePost(widget.post!, title: title, body: value)
        : await appState.updateComment(widget.comment!, text: value);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('forum.editSaved'))));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(appState.t(widget.post == null ? 'forum.editComment' : 'forum.editPost')),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.post != null) ...[
                  TextField(controller: _title, maxLength: 200, enabled: !_saving, decoration: InputDecoration(labelText: appState.t('forum.postTitle'))),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _text,
                  minLines: widget.post == null ? 3 : 5,
                  maxLines: 8,
                  maxLength: widget.post == null ? 2000 : 5000,
                  enabled: !_saving,
                  decoration: InputDecoration(labelText: appState.t(widget.post == null ? 'forum.comment' : 'forum.postBody')),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(appState.t('common.cancel'))),
          ElevatedButton(onPressed: _saving ? null : _save, child: Text(appState.t('common.save'))),
        ],
      ),
    );
  }
}
