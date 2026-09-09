import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../providers/team_provider.dart';
import 'app_error_widget.dart';
import 'app_loading_indicator.dart';
import 'confirmation_dialog.dart';

class CommentsSection extends StatefulWidget {
  final String taskId;
  final String? projectTeamManagerId;
  final List<Comment>? comments;
  final bool? isLoading;
  final String? currentUserId;
  final bool? isManagerOrAdmin;
  final Future<void> Function(String content)? onAddComment;
  final Future<void> Function(String commentId, String content)?
  onUpdateComment;
  final Future<void> Function(String commentId)? onDeleteComment;

  const CommentsSection({
    super.key,
    required this.taskId,
    this.projectTeamManagerId,
    this.comments,
    this.isLoading,
    this.currentUserId,
    this.isManagerOrAdmin,
    this.onAddComment,
    this.onUpdateComment,
    this.onDeleteComment,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final _commentController = TextEditingController();
  bool _localLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Comment> _internalComments = [];

  bool get _isLoading => widget.isLoading ?? _localLoading;
  List<Comment> get _displayComments => widget.comments ?? _internalComments;

  @override
  void initState() {
    super.initState();
    if (widget.comments == null) {
      _fetchComments();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _localLoading = true;
      _errorMessage = null;
    });

    try {
      final client = context.read<ApiClient>();
      final response = await client.get('/tasks/${widget.taskId}/comments');
      if (response is List) {
        _internalComments = response
            .map((item) => Comment.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      if (mounted) {
        setState(() {
          _localLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (widget.onAddComment != null) {
        await widget.onAddComment!(text);
      } else {
        final client = context.read<ApiClient>();
        final response = await client.post(
          '/tasks/${widget.taskId}/comments',
          body: {'content': text},
        );
        final newComment = Comment.fromJson(response as Map<String, dynamic>);
        _internalComments.insert(0, newComment);
      }
      _commentController.clear();
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editComment(Comment comment) async {
    final editController = TextEditingController(text: comment.content);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: editController,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'Enter updated comment...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null &&
        updated.isNotEmpty &&
        updated != comment.content &&
        mounted) {
      try {
        if (widget.onUpdateComment != null) {
          await widget.onUpdateComment!(comment.id, updated);
        } else {
          final client = context.read<ApiClient>();
          final response = await client.put(
            '/comments/${comment.id}',
            body: {'content': updated},
          );
          final edited = Comment.fromJson(response as Map<String, dynamic>);
          setState(() {
            final index = _internalComments.indexWhere(
              (c) => c.id == comment.id,
            );
            if (index != -1) {
              _internalComments[index] = edited;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Delete Comment',
      message: 'Are you sure you want to permanently delete this comment?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        if (widget.onDeleteComment != null) {
          await widget.onDeleteComment!(comment.id);
        } else {
          final client = context.read<ApiClient>();
          await client.delete('/comments/${comment.id}');
          setState(() {
            _internalComments.removeWhere((c) => c.id == comment.id);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final teamProv = context.watch<TeamProvider>();
    final currentUserId = widget.currentUserId ?? currentUser?.id ?? '';
    final isAuthorizedAdminOrManager =
        widget.isManagerOrAdmin ??
        (currentUser?.isAdmin == true || currentUser?.isManager == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        // Add comment row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLines: 2,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isSubmitting ? null : _addComment,
              style: FilledButton.styleFrom(minimumSize: const Size(80, 48)),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Comments List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: AppLoadingIndicator(message: 'Loading comments...'),
          )
        else if (_errorMessage != null)
          AppErrorWidget(message: _errorMessage!, onRetry: _fetchComments)
        else if (_displayComments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                'No comments yet. Be the first to comment!',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _displayComments.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final comment = _displayComments[index];
              final isAuthor =
                  currentUserId.isNotEmpty && comment.userId == currentUserId;
              final canModerate = isAuthor || isAuthorizedAdminOrManager;

              final authorEmp = teamProv.employees
                  .where(
                    (e) => e.userId == comment.userId || e.id == comment.userId,
                  )
                  .firstOrNull;

              final authorDisplayName = isAuthor
                  ? 'You'
                  : ((comment.authorName != null &&
                            comment.authorName!.isNotEmpty)
                        ? comment.authorName!
                        : (authorEmp != null
                              ? authorEmp.name
                              : (comment.userId == currentUser?.id
                                    ? (currentUser?.name ?? 'You')
                                    : 'Unknown User')));

              final formattedDate = DateFormat(
                'MMM d, yyyy • h:mm a',
              ).format(comment.createdAt.toLocal());
              final accessibleDate = DateFormat(
                'MMMM d, yyyy',
              ).format(comment.createdAt.toLocal());

              return Semantics(
                label:
                    '$authorDisplayName, $accessibleDate, comment: ${comment.content}',
                container: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      authorDisplayName.isNotEmpty
                          ? authorDisplayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  title: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        authorDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  trailing: canModerate
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _editComment(comment);
                            } else if (val == 'delete') {
                              _deleteComment(comment);
                            }
                          },
                          itemBuilder: (context) => [
                            if (isAuthor || isAuthorizedAdminOrManager)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }
}
