import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../supabase_client.dart';
import '../widgets/avatar_widget.dart';

class CommentsWidget extends StatefulWidget {
  final String postId;
  const CommentsWidget({super.key, required this.postId});

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final user = supabase.auth.currentUser;
  final _controller = TextEditingController();

  List<Map<String, dynamic>> comments = [];
  Uint8List? imageBytes;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadComments();
  }

  Future<void> loadComments() async {
    final res = await supabase
        .from('comments')
        .select(
            'id, author, content, image_url, profiles(display_name, avatar_url)')
        .eq('blog_id', widget.postId)
        .order('created_at');

    if (!mounted) return;
    setState(() => comments = List<Map<String, dynamic>>.from(res));
  }

  Future<void> pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    imageBytes = await img.readAsBytes();
    setState(() {});
  }

  Future<void> confirmDeleteComment(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (ok == true) {
      await supabase.from('comments').delete().eq('id', id);
      loadComments();
    }
  }

  //  EDIT COMMENT 
  Future<void> editComment(Map c) async {
    final ctrl = TextEditingController(text: c['content']);

    Uint8List? editImageBytes;
    bool removeImage = false;
    final String? originalImageUrl = c['image_url'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Comment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: ctrl),
                    const SizedBox(height: 12),

                    // IMAGE PRIORITY
                    if (editImageBytes != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.memory(editImageBytes!, height: 120),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                editImageBytes = null;
                                removeImage = true;
                              });
                            },
                          ),
                        ],
                      )
                    else if (originalImageUrl != null && !removeImage)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.network(originalImageUrl, height: 120),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                removeImage = true;
                              });
                            },
                          ),
                        ],
                      ),

                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: () async {
                        final img = await ImagePicker()
                            .pickImage(source: ImageSource.gallery);
                        if (img != null) {
                          final bytes = await img.readAsBytes();
                          setDialogState(() {
                            editImageBytes = bytes;
                            removeImage = false;
                          });
                        }
                      },
                      child: Text(
                        editImageBytes != null ||
                                (originalImageUrl != null && !removeImage)
                            ? 'Change Image'
                            : 'Upload Image',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    String? imageUrl;

    // NEW image 
    if (editImageBytes != null) {
      final path = 'comments/${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage
          .from('blog-images')
          .uploadBinary(path, editImageBytes!);
      imageUrl = supabase.storage.from('blog-images').getPublicUrl(path);
    }
    // Removed image
    else if (removeImage) {
      imageUrl = null;
    }
    // Keep old image
    else {
      imageUrl = originalImageUrl;
    }

    await supabase.from('comments').update({
  'content': ctrl.text.trim(),
  'image_url': imageUrl,
    }).eq('id', c['id']);

    // FORCE PROFILE REFRESH
    await supabase.auth.refreshSession();

    //  Reload comments with updated avatar/name
    loadComments();

  }

  // Add comment

  Future<void> addComment() async {
    if (user == null) return;

    final text = _controller.text.trim();

    //  Block only if BOTH are empty
    if (text.isEmpty && imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment or image is required')),
      );
      return;
    }

    setState(() => loading = true);
    String? imageUrl;

    if (imageBytes != null) {
      final path = 'comments/${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage
          .from('blog-images')
          .uploadBinary(path, imageBytes!);
      imageUrl = supabase.storage.from('blog-images').getPublicUrl(path);
    } 

    await supabase.from('comments').insert({
      'blog_id': widget.postId,
      'author': user!.id,
      'content': _controller.text.trim(),
      'image_url': imageUrl,
    });

    _controller.clear();
    imageBytes = null;
    await loadComments();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in comments)
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
                Text(c['content']),
                if (c['image_url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.network(c['image_url'], height: 120),
                  ),
              ],
            ),
            trailing: c['author'] == user?.id
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

       if (imageBytes != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Image.memory(imageBytes!, height: 120),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => imageBytes = null),
                ),
              ],
            ),
          ),
        ),

        Row(
          children: [
            IconButton(icon: const Icon(Icons.image), onPressed: pickImage),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'Write a comment'),
              ),
            ),
            IconButton(
              icon: loading
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.send),
              onPressed: loading ? null : addComment,
            ),
          ],
        ),
      ],
    );
  }
}
