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
  List<Uint8List> imageBytesList = [];
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

  // ================= LOAD COMMENTS ==============
  Future<void> loadComments() async {
    final res = await supabase
        .from('comments')
        .select(
          'id, author, content, image_urls, profiles(display_name, avatar_url)',
        )
        .eq('blog_id', widget.postId)
        .order('created_at');

    if (!mounted) return;
    setState(() => comments = List<Map<String, dynamic>>.from(res));
  }

  // ================= PICK MULTIPLE IMAGES =================
  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes =
        await Future.wait(images.map((img) => img.readAsBytes()));

    setState(() {
      imageBytesList.addAll(bytes);
    });
  }

  // ================= DELETE COMMENT =================
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
      loadComments();
    }
  }

  // ================= EDIT COMMENT =================
  Future<void> editComment(Map c) async {
  final ctrl = TextEditingController(text: c['content']);

  List<String> existingImageUrls =
      List<String>.from(c['image_urls'] ?? []);

  List<Uint8List> newImages = [];

  Future<void> pickNewImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes =
        await Future.wait(images.map((img) => img.readAsBytes()));

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
                      spacing: 6,
                      children: List.generate(existingImageUrls.length, (i) {
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.network(
                              existingImageUrls[i],
                              height: 90,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red),
                              onPressed: () {
                                setModalState(() {
                                  existingImageUrls.removeAt(i);
                                });
                              },
                            ),
                          ],
                        );
                      }),
                    ),

                  // NEW IMAGES
                  if (newImages.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: List.generate(newImages.length, (i) {
                        return Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.memory(newImages[i], height: 90),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red),
                              onPressed: () {
                                setModalState(() {
                                  newImages.removeAt(i);
                                });
                              },
                            ),
                          ],
                        );
                      }),
                    ),

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

  /// Upload NEW images
  for (final bytes in newImages) {
    final path =
        'comments/${DateTime.now().millisecondsSinceEpoch}_${existingImageUrls.length}.png';

    await supabase.storage
        .from('blog-images')
        .uploadBinary(path, bytes);

    existingImageUrls.add(
      supabase.storage.from('blog-images').getPublicUrl(path),
    );
  }

  await supabase.from('comments').update({
    'content': ctrl.text.trim(),
    'image_urls': existingImageUrls,
  }).eq('id', c['id']);

  loadComments();
}

  // ================= ADD COMMENT =================
  Future<void> addComment() async {
    if (user == null) return;

    final text = _controller.text.trim();

    if (text.isEmpty && imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment or image is required')),
      );
      return;
    }

    setState(() => loading = true);

    List<String> imageUrls = [];

    for (final bytes in imageBytesList) {
      final path =
          'comments/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.png';

      await supabase.storage
          .from('blog-images')
          .uploadBinary(path, bytes);

      imageUrls.add(
        supabase.storage.from('blog-images').getPublicUrl(path),
      );
    }

    await supabase.from('comments').insert({
      'blog_id': widget.postId,
      'author': user!.id,
      'content': text,
      'image_urls': imageUrls,
    });

    _controller.clear();
    imageBytesList.clear();
    await loadComments();
    setState(() => loading = false);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // COMMENTS LIST
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
                if (c['image_urls'] != null &&
                    (c['image_urls'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      children: List.generate(
                        c['image_urls'].length,
                        (i) => Image.network(
                          c['image_urls'][i],
                          height: 100,
                        ),
                      ),
                    ),
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

        // IMAGE PREVIEW BEFORE SEND
        if (imageBytesList.isNotEmpty)
          Wrap(
            spacing: 8,
            children: List.generate(imageBytesList.length, (i) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.memory(imageBytesList[i], height: 100),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        imageBytesList.removeAt(i);
                      });
                    },
                  ),
                ],
              );
            }),
          ),

        // INPUT ROW
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
