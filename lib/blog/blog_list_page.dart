import 'package:flutter/material.dart';
import '../supabase_client.dart';
import '../profile/profile_page.dart';
import '../widgets/avatar_widget.dart';
import 'blog_create_page.dart';
import 'blog_edit_page.dart';
import '../comment/comments_widget.dart';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  final ScrollController _scroll = ScrollController();

  List blogs = [];
  bool loading = false;
  bool hasMore = true;

  static const int pageSize = 3;
  int offset = 0;

  Map<String, dynamic>? myProfile;
  final user = supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    fetchBlogs();
    fetchMyProfile();

    _scroll.addListener(() {
      if (_scroll.position.pixels >=
              _scroll.position.maxScrollExtent - 200 &&
          !loading &&
          hasMore) {
        fetchBlogs();
      }
    });
  }

  Future<void> fetchMyProfile() async {
    if (user == null) return;
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .maybeSingle();
    if (!mounted) return;
    setState(() => myProfile = res);
  }

  Future<void> fetchBlogs() async {
    setState(() => loading = true);

    final res = await supabase
        .from('blogs')
        .select('*, profiles(display_name, avatar_url)')
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1);

    if (!mounted) return;

    setState(() {
      blogs.addAll(res);
      offset += pageSize;
      hasMore = res.length == pageSize;
      loading = false;
    });
  }

  Future<void> confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Blog'),
        content: const Text('Are you sure you want to delete this blog?')
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('blogs').delete().eq('id', id);
      setState(() {
        blogs.clear();
        offset = 0;
        hasMore = true;
      });
      fetchBlogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Blog',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlogCreatePage()),
              );
              setState(() {
                blogs.clear();
                offset = 0;
                hasMore = true;
              });
              fetchBlogs();
            },
          ),
          if (myProfile != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );

                  // FORCE REFRESH
                  blogs.clear();
                  offset = 0;
                  hasMore = true;

                  await fetchMyProfile();
                  await fetchBlogs();
                },

                child: AvatarWidget(
                  imageUrl: myProfile!['avatar_url'],
                  size: 34,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async => supabase.auth.signOut(),
          ),
        ],
      ),

      body: ListView.builder(
        controller: _scroll,
        itemCount: blogs.length + (hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= blogs.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final blog = blogs[i];
          final profile = blog['profiles'];
          final isAuthor = blog['author'] == user?.id;

          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// AUTHOR
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: profile?['avatar_url'],
                        size: 36,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        profile?['display_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (isAuthor)
                        PopupMenuButton(
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlogEditPage(blog: blog),
                                ),
                              );
                              setState(() {
                                blogs.clear();
                                offset = 0;
                                hasMore = true;
                              });
                              fetchBlogs();
                            } else {
                              confirmDelete(blog['id']);
                            }
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// TITLE
                  Text(
                    blog['title'],
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  /// IMAGE
                  if (blog['image_url'] != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        blog['image_url'],
                        fit: BoxFit.contain,
                      ),
                    ),

                  const SizedBox(height: 8),

                  /// CONTENT
                  Text(
                    blog['content'],
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 12),

                  CommentsWidget(postId: blog['id']),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
