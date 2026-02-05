import 'package:flutter/material.dart';
import '../supabase_client.dart';
import 'blog_edit_page.dart';

class BlogEditRoutePage extends StatefulWidget {
  final String blogId;
  const BlogEditRoutePage({super.key, required this.blogId});

  @override
  State<BlogEditRoutePage> createState() => _BlogEditRoutePageState();
}

class _BlogEditRoutePageState extends State<BlogEditRoutePage> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? blog;

  @override
  void initState() {
    super.initState();
    _loadBlog();
  }

  Future<void> _loadBlog() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Fetch blog + author profile 
      final res = await supabase
          .from('blogs')
          .select('*, profiles(display_name, avatar_url)')
          .eq('id', widget.blogId)
          .single();

      blog = Map<String, dynamic>.from(res);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null || blog == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Blog')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error ?? 'Blog not found'),
          ),
        ),
      );
    }

    // Hand the existing edit page
    return BlogEditPage(blog: blog!);
  }
}
