import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../supabase_client.dart';
import '../widgets/avatar_widget.dart';

class CommentsWidget extends StatefulWidget {
  final String blogId;

  const CommentsWidget({
    super.key,
    required this.blogId,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final user = supabase.auth.currentUser;
  final TextEditingController _controller = TextEditingController();

  // comments data (ALL comments for this blog)
  List<Map<String, dynamic>> comments = [];
  bool loading = true;
  String? error;

  // threaded map: parent_id -> children
  final Map<String, List<Map<String, dynamic>>> _childrenByParent = {};

  // reply mode
  String? replyingToId;
  String? replyingToName;

  // add comment
  bool sending = false;
  List<Uint8List> imageBytesList = [];

  // count
  int totalCount = 0;
  bool countLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCommentCount();
    loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // COUNT
  Future<void> _loadCommentCount() async {
    setState(() => countLoading = true);

    try {
      final res = await supabase
          .from('comments')
          .select('id')
          .eq('blog_id', widget.blogId);

      if (!mounted) return;

      setState(() {
        totalCount = (res as List).length;
      });
    } catch (_) {
      // ignore count failures
    } finally {
      if (mounted) setState(() => countLoading = false);
    }
  }

  // BUILD THREAD MAP
  void _buildThreadMap() {
    _childrenByParent.clear();
    for (final c in comments) {
      final parentId = c['parent_id'] as String?;
      final key = parentId ?? '__root__';
      _childrenByParent.putIfAbsent(key, () => []);
      _childrenByParent[key]!.add(c);
    }
  }

  List<Map<String, dynamic>> get _rootComments =>
      _childrenByParent['__root__'] ?? const [];

  // LOAD COMMENTS
  Future<void> loadComments() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // requires parent_id column in DB
      final res = await supabase
          .from('comments')
          .select(
            'id, blog_id, author, parent_id, content, image_url, image_urls, created_at, profiles(display_name, avatar_url)',
          )
          .eq('blog_id', widget.blogId)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        comments = list;
        totalCount = list.length;
        _buildThreadMap();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // PICK MULTIPLE IMAGES
  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes = await Future.wait(images.map((img) => img.readAsBytes()));

    if (!mounted) return;
    setState(() => imageBytesList.addAll(bytes));
  }

  // REPLY MODE
  void startReply(Map<String, dynamic> parent) {
    setState(() {
      replyingToId = parent['id'] as String?;
      replyingToName = parent['profiles']?['display_name'] ?? 'Unknown';
    });
  }

  void cancelReply() {
    setState(() {
      replyingToId = null;
      replyingToName = null;
    });
  }

  // DELETE COMMENT 
  Future<void> confirmDeleteComment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('comments').delete().eq('id', id);
      await loadComments();
      await _loadCommentCount();
    }
  }

  // EDIT COMMENT
  //  allow editing and keep parent_id unchanged
  Future<void> editComment(Map c) async {
    final ctrl = TextEditingController(text: (c['content'] ?? '').toString());

    List<String> existingImageUrls =
        List<String>.from(c['image_urls'] ?? const []);

    List<Uint8List> newImages = [];

    Future<void> pickNewImages() async {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isEmpty) return;

      final bytes = await Future.wait(images.map((img) => img.readAsBytes()));
      newImages.addAll(bytes);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Edit Comment'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: ctrl),
                    const SizedBox(height: 12),

                    // EXISTING IMAGES
                    if (existingImageUrls.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(existingImageUrls.length, (i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  existingImageUrls[i],
                                  height: 90,
                                  width: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      existingImageUrls.removeAt(i);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),

                    // NEW IMAGES
                    if (newImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(newImages.length, (i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  newImages[i],
                                  height: 90,
                                  width: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      newImages.removeAt(i);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],

                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await pickNewImages();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Add Images'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    // Upload NEW images
    for (final bytes in newImages) {
      final path =
          'comments/${DateTime.now().millisecondsSinceEpoch}_${existingImageUrls.length}.png';

      await supabase.storage.from('comment-images').uploadBinary(path, bytes);

      existingImageUrls.add(
        supabase.storage.from('comment-images').getPublicUrl(path),
      );
    }

    await supabase.from('comments').update({
      'content': ctrl.text.trim(),
      'image_urls': existingImageUrls,
      // IMPORTANT: do not modify parent_id here
    }).eq('id', c['id']);

    ctrl.dispose();
    await loadComments();
    await _loadCommentCount();
  }

  // ADD COMMENT / REPLY 
  Future<void> addComment() async {
    if (user == null) return;

    final text = _controller.text.trim();

    if (text.isEmpty && imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment or image is required')),
      );
      return;
    }

    setState(() => sending = true);

    try {
      List<String> imageUrls = [];

      for (final bytes in imageBytesList) {
        final path =
            'comments/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.png';

        await supabase.storage.from('comment-images').uploadBinary(path, bytes);

        imageUrls.add(
          supabase.storage.from('comment-images').getPublicUrl(path),
        );
      }

      await supabase.from('comments').insert({
        'blog_id': widget.blogId,
        'author': user!.id,
        'content': text,
        'image_urls': imageUrls,
        'parent_id': replyingToId, // null = top-level, not-null = reply
      });

      _controller.clear();
      imageBytesList.clear();

      // after posting a reply, exit reply mode
      cancelReply();

      await loadComments();
      await _loadCommentCount();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  // ================= RENDER THREAD =================
  Widget _buildCommentNode(Map<String, dynamic> c, {required int depth}) {
    final isMine = c['author'] == user?.id;
    final id = c['id'] as String?;
    final replies = id == null ? const [] : (_childrenByParent[id] ?? const []);

    final leftPad = (depth * 16).clamp(0, 48).toDouble();

    return Padding(
      padding: EdgeInsets.only(left: leftPad, top: 6, bottom: 6),
      child: Card(
        elevation: 0.6,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: AvatarWidget(
                  imageUrl: c['profiles']?['avatar_url'],
                  size: 36,
                ),
                title: Text(
                  c['profiles']?['display_name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((c['content'] ?? '').toString()),
                    if (c['image_urls'] != null &&
                        (c['image_urls'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(
                            (c['image_urls'] as List).length,
                            (i) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                c['image_urls'][i],
                                height: 90,
                                width: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => startReply(c),
                          child: const Text('Reply'),
                        ),
                        if (replies.isNotEmpty)
                          Text(
                            '${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: isMine
                    ? PopupMenuButton(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (v) {
                          if (v == 'edit') {
                            editComment(c);
                          } else {
                            confirmDeleteComment(c['id']);
                          }
                        },
                      )
                    : null,
              ),

              // replies (recursive)
              if (replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: replies
                        .map((r) => _buildCommentNode(r, depth: depth + 1))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countText = countLoading ? '' : ' ($totalCount)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header only (no show/hide)
        Row(
          children: [
            Text(
              'Comments$countText',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () async {
                await loadComments();
                await _loadCommentCount();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Failed to load comments: $error'),
          )
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('No comments yet. Be the first!'),
          )
        else
          ..._rootComments.map((c) => _buildCommentNode(c, depth: 0)),

        // Reply banner
        if (replyingToId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Replying to $replyingToName',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel reply',
                  onPressed: cancelReply,
                  icon: const Icon(Icons.close),
                )
              ],
            ),
          ),

        // Image preview before send
        if (imageBytesList.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(imageBytesList.length, (i) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytesList[i],
                      height: 90,
                      width: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        setState(() => imageBytesList.removeAt(i));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),

        const SizedBox(height: 8),

        // Input row
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: pickImages,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: replyingToId == null
                      ? 'Write a comment'
                      : 'Write a reply',
                ),
              ),
            ),
            IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: sending ? null : addComment,
            ),
          ],
        ),
      ],
    );
  }
}
