import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../supabase_client.dart';

class BlogCreatePage extends StatefulWidget {
  const BlogCreatePage({super.key});

  @override
  State<BlogCreatePage> createState() => _BlogCreatePageState();
}

class _BlogCreatePageState extends State<BlogCreatePage> {
  final titleCtrl = TextEditingController();
  final contentCtrl = TextEditingController();

  List<Uint8List> imageBytesList = [];
  bool loading = false;

  @override
  void dispose() {
    titleCtrl.dispose();
    contentCtrl.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;

    final bytes = await Future.wait(images.map((img) => img.readAsBytes()));
    if (!mounted) return;

    setState(() => imageBytesList.addAll(bytes));
  }

  Future<void> createBlog() async {
    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and blog content are required')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      List<String> imageUrls = [];

      for (final bytes in imageBytesList) {
        final path =
            'blogs/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.png';

        await supabase.storage.from('blog-images').uploadBinary(path, bytes);
        imageUrls.add(supabase.storage.from('blog-images').getPublicUrl(path));
      }

      await supabase.from('blogs').insert({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'author': supabase.auth.currentUser!.id,
        'image_urls': imageUrls,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog created successfully')),
      );
      Navigator.pop(context);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create blog: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _imageGrid() {
    if (imageBytesList.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imageBytesList.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.memory(imageBytesList[i], fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () => setState(() => imageBytesList.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Post details',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'Write a short title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Content *',
                        hintText: 'Write your post...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Images',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: loading ? null : pickImages,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (imageBytesList.isEmpty)
                      Text(
                        'No images selected.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.black54),
                      )
                    else
                      _imageGrid(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : createBlog,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
