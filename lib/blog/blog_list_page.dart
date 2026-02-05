import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../supabase_client.dart';
import '../widgets/avatar_widget.dart';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  final ScrollController _scrollCtrl = ScrollController();
  final user = supabase.auth.currentUser;

  List<Map<String, dynamic>> blogs = [];
  Map<String, dynamic>? myProfile;

  bool loading = false;
  bool hasMore = true;

  static const int pageSize = 5;
  int offset = 0;


  @override
  void initState() {
    super.initState();
    fetchMyProfile();
    fetchBlogs(reset: true);

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !loading &&
          hasMore) {
        fetchBlogs();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchMyProfile() async {
    if (user == null) return;

    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      myProfile = res == null ? null : Map<String, dynamic>.from(res);
    });
  }

  Future<void> fetchBlogs({bool reset = false}) async {
    if (loading) return;

    if (reset) {
      setState(() {
        blogs.clear();
        offset = 0;
        hasMore = true;
      });
    }

    setState(() => loading = true);

    try {
      final res = await supabase
          .from('blogs')
          .select(
            'id,title,content,author,created_at,image_url,image_urls,profiles(display_name,avatar_url),comments(count)',
          )
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);

      if (!mounted) return;

      final page = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

        setState(() {
        blogs.addAll(page);
        offset += pageSize;
        hasMore = page.length == pageSize;
        loading = false;

        
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load blogs: $e')),
      );
    }
  }

  int commentCount(Map<String, dynamic> blog) {
    final agg = blog['comments'];
    if (agg is List && agg.isNotEmpty) {
      final first = agg.first;
      if (first is Map && first['count'] is int) return first['count'];
    }
    return 0;
  }

  List<String> imageUrls(Map<String, dynamic> blog) {
    final raw = blog['image_urls'];
    if (raw is List) {
      final urls = raw.whereType<String>().toList();
      if (urls.isNotEmpty) return urls;
    }
    final single = blog['image_url'];
    if (single is String && single.isNotEmpty) return [single];
    return const [];
  }

  // timeaAgo base on local PHP Time
  String timeAgo(dynamic createdAt) {
    if (createdAt == null) return '';

    DateTime? dt;

    if (createdAt is DateTime) {
      dt = createdAt;
    } else if (createdAt is String) {
      var s = createdAt.trim();

      if (s.contains(' ') && !s.contains('T')) {
        s = s.replaceFirst(' ', 'T');
      }

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

  Future<void> confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Blog'),
        content: const Text('Are you sure you want to delete this blog?'),
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
      await supabase.from('blogs').delete().eq('id', id);
      await fetchBlogs(reset: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog deleted')),
      );
    }
  }

  // THUMBNAIL PREVIEW: only first image + overlay 
  Widget _thumbnailPreview(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    final first = urls.first;
    final more = urls.length - 1;

    return SizedBox(
      width: 130,
      height: 130,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              ),
            ),
            if (more > 0)
              Container(
                alignment: Alignment.center,
                color: Colors.black45,
                child: Text(
                  '+$more',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Post',
            onPressed: () async {
              await context.push('/create');
              await fetchBlogs(reset: true);
            },
          ),
          if (myProfile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () async {
                  final changed = await context.push<bool>('/profile');

                  if (changed == true) {
                    await fetchMyProfile();
                    await fetchBlogs(reset: true);
                  }
                },
                child: AvatarWidget(
                  imageUrl: myProfile!['avatar_url'],
                  size: 34,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async => supabase.auth.signOut(),
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollCtrl,
        itemCount: blogs.length + (hasMore ? 1 : 0),
        itemBuilder: (_, index) {
          if (index >= blogs.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final blog = blogs[index];
          final profile = blog['profiles'];
          final isAuthor = blog['author'] == user?.id;

          final id = blog['id'].toString();
          final imgs = imageUrls(blog);

          final title = (blog['title'] ?? '').toString();
          final content = (blog['content'] ?? '').toString();
          final count = commentCount(blog);

          final authorName =
              profile is Map ? (profile['display_name'] ?? 'Unknown') : 'Unknown';
          final authorAvatar = profile is Map ? profile['avatar_url'] : null;

          final createdAt = timeAgo(blog['created_at']);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: InkWell(
              onTap: () async {
                final changed = await context.push<bool>('/post/$id');
                if (changed == true) {
                  await fetchBlogs(reset: true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        AvatarWidget(imageUrl: authorAvatar, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authorName.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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
                        if (isAuthor)
                          PopupMenuButton<String>(
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await context.push('/edit/$id');
                                await fetchBlogs(reset: true);
                              } else {
                                await confirmDelete(id);
                              }
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Thumbnail + Content 
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imgs.isNotEmpty) _thumbnailPreview(imgs),
                        if (imgs.isNotEmpty) const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            content,
                            maxLines: imgs.isNotEmpty ? 4 : 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Counts row
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 16),
                        const SizedBox(width: 6),
                        Text('$count'),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Action bar
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => context.push('/post/$id'),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Comment'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
