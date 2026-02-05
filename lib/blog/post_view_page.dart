import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../supabase_client.dart';
import '../comment/comments_widget.dart';

class PostViewPage extends StatefulWidget {
  final String postId;
  const PostViewPage({super.key, required this.postId});

  @override
  State<PostViewPage> createState() => _PostViewPageState();
}

class _PostViewPageState extends State<PostViewPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? post;


  // Scroll-to-comments
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _commentsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  List<String> _imageUrlsFromAny(Map<String, dynamic> row) {
    final listRaw = row['image_urls'];
    if (listRaw is List) {
      final urls = listRaw.whereType<String>().toList();
      if (urls.isNotEmpty) return urls;
    }
    final single = row['image_url'];
    if (single is String && single.isNotEmpty) return [single];
    return const [];
  }

  // FIXED timeAgo for "timestamp without time zone"
  String timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';

    DateTime? dt;

    if (createdAt is DateTime) {
      dt = createdAt;
    } else if (createdAt is String) {
      var s = createdAt.trim();

      // "YYYY-MM-DD HH:mm:ss" -> "YYYY-MM-DDTHH:mm:ss"
      if (s.contains(' ') && !s.contains('T')) {
        s = s.replaceFirst(' ', 'T');
      }

      // If string has no timezone, assume UTC (DB is timestamp without tz)
      final hasZ = s.endsWith('Z');
      final hasPlus = s.contains('+');
      final hasOffsetMinus =
          s.length > 10 && s.substring(10).contains('-'); // after date part
      final hasTimezone = hasZ || hasPlus || hasOffsetMinus;

      if (!hasTimezone) {
        s = '${s}Z';
      }

      dt = DateTime.tryParse(s);
    }

    if (dt == null) return '';

    dt = dt.toLocal();
    final diff = DateTime.now().difference(dt);

    if (diff.isNegative) return 'Just now';
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _loadPost() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final p = await supabase
          .from('blogs')
          .select(
              'id,title,content,image_url,image_urls,created_at,author,profiles(display_name,avatar_url)')
          .eq('id', widget.postId)
          .single();

      post = Map<String, dynamic>.from(p);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _isPostOwner() {
    final me = supabase.auth.currentUser?.id;
    final authorId = post?['author']?.toString();
    return me != null && authorId != null && me == authorId;
  }

  Future<void> _confirmDeletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Blog'),
        content: const Text('Are you sure you want to delete this blog post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    
    try {
      await supabase.from('blogs').delete().eq('id', widget.postId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog deleted')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete blog: $e')),
      );
    }
  }


  Widget _avatar(String? url) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person));
    }
    return CircleAvatar(
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (_, __) {},
    );
  }

  // IMAGE COLLAGE + GALLERY
  void _openGallery(List<String> urls, int initialIndex) {
    if (urls.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GalleryViewer(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _imgTile(String url, {Widget? overlay, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image),
            ),
          ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }

  Widget _moreOverlay(int moreCount) {
    return Container(
      alignment: Alignment.center,
      color: Colors.black54,
      child: Text(
        '+$moreCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _imagePreviewCollage(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final radius = BorderRadius.circular(14);

    // 1 image
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _imgTile(
            urls[0],
            onTap: () => _openGallery(urls, 0),
          ),
        ),
      );
    }

    // 2 images
    if (urls.length == 2) {
      return ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Row(
            children: [
              Expanded(
                child: _imgTile(
                  urls[0],
                  onTap: () => _openGallery(urls, 0),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _imgTile(
                  urls[1],
                  onTap: () => _openGallery(urls, 1),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3+ images
    final moreCount = urls.length - 3;
    final showOverlay = moreCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _imgTile(
                    urls[0],
                    onTap: () => _openGallery(urls, 0),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: _imgTile(
                          urls[1],
                          onTap: () => _openGallery(urls, 1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: _imgTile(
                          urls[2],
                          overlay: showOverlay ? _moreOverlay(moreCount) : null,
                          onTap: () => _openGallery(urls, 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showOverlay) ...[
          const SizedBox(height: 6),
          Text(
            '+$moreCount more image(s)',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null || post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${error ?? "Post not found"}'),
          ),
        ),
      );
    }

    final title = (post!['title'] ?? '').toString();
    final content = (post!['content'] ?? '').toString();
    final images = _imageUrlsFromAny(post!);

    final postProfile = post!['profiles'];
    final postAuthorName =
        (postProfile is Map ? postProfile['display_name'] : null) as String?;
    final postAuthorAvatar =
        (postProfile is Map ? postProfile['avatar_url'] : null) as String?;

    final createdAt = timeAgo(post!['created_at']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (_isPostOwner())
            PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  await context.push('/edit/${widget.postId}');
                  await _loadPost();
                } else {
                  await _confirmDeletePost();
                }
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPost,
        child: ListView(
          controller: _scrollCtrl, //  scroll controller
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            // Header
            Row(
              children: [
                _avatar(postAuthorAvatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postAuthorName?.isNotEmpty == true
                            ? postAuthorName!
                            : 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title + content
            if (title.isNotEmpty)
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            const SizedBox(height: 10),
            if (content.isNotEmpty)
              Text(content, style: Theme.of(context).textTheme.bodyLarge),

            // Collage preview (same as blog_list)
            if (images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _imagePreviewCollage(images),
            ],

            const SizedBox(height: 12),

            // Action bar (UI only)
        

            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),

            // Comments anchor
            Container(key: _commentsKey),

            // Comments
            CommentsWidget(blogId: widget.postId),
          ],
        ),
      ),
    );
  }
}

// =========================
// Fullscreen gallery viewer
// =========================
class _GalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _GalleryViewer({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller;
  late int _index;

  final FocusNode _focusNode = FocusNode(debugLabel: 'gallery_focus');
  bool _pageScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= widget.urls.length - 1) return;
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _prev() {
    if (_index <= 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focusNode.requestFocus(),
      child: FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: true,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _NextIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _PrevIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
        },
        actions: <Type, Action<Intent>>{
          _NextIntent: CallbackAction<_NextIntent>(onInvoke: (_) {
            _next();
            return null;
          }),
          _PrevIntent: CallbackAction<_PrevIntent>(onInvoke: (_) {
            _prev();
            return null;
          }),
          _CloseIntent: CallbackAction<_CloseIntent>(onInvoke: (_) {
            Navigator.of(context).maybePop();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${_index + 1} / ${widget.urls.length}'),
          ),
          body: PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            physics: _pageScrollEnabled
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final url = widget.urls[i];

              return GestureDetector(
                onScaleStart: (_) => setState(() => _pageScrollEnabled = false),
                onScaleEnd: (_) => setState(() => _pageScrollEnabled = true),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white70,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Intents
class _NextIntent extends Intent {
  const _NextIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
