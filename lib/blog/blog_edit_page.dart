import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../supabase_client.dart';

class BlogEditPage extends StatefulWidget {
  final Map blog;
  const BlogEditPage({super.key, required this.blog});

  @override
  State<BlogEditPage> createState() => _BlogEditPageState();
}

class _BlogEditPageState extends State<BlogEditPage> {
  late TextEditingController titleCtrl;
  late TextEditingController contentCtrl;

  // Existing images (from DB)
  List<String> imageUrls = [];

  // Newly picked images (local only)
  List<Uint8List> newImages = [];

  bool saving = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: (widget.blog['title'] ?? '').toString());
    contentCtrl = TextEditingController(text: (widget.blog['content'] ?? '').toString());
    imageUrls = List<String>.from(widget.blog['image_urls'] ?? const []);
  }

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

    setState(() => newImages.addAll(bytes));
  }

  Future<void> updateBlog() async {
    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      // Upload newly added images
      for (final bytes in newImages) {
        final path =
            'blogs/${widget.blog['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

        await supabase.storage.from('blog-images').uploadBinary(path, bytes);
        imageUrls.add(supabase.storage.from('blog-images').getPublicUrl(path));
      }

      await supabase.from('blogs').update({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'image_urls': imageUrls,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.blog['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _networkGrid() {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: imageUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final url = imageUrls[i];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: saving ? null : () => setState(() => imageUrls.removeAt(i)),
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

  Widget _memoryGrid() {
    if (newImages.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: newImages.length,
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
                child: Image.memory(newImages[i], fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: saving ? null : () => setState(() => newImages.removeAt(i)),
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
      appBar: AppBar(title: const Text('Edit Post')),
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
                      decoration: const InputDecoration(
                        labelText: 'Title *',
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
                          onPressed: saving ? null : pickImages,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Add'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    if (imageUrls.isNotEmpty) ...[
                      Text('Current images',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _networkGrid(),
                      const SizedBox(height: 12),
                    ] else
                      Text(
                        'No current images.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.black54),
                      ),

                    if (newImages.isNotEmpty) ...[
                      Text('New images to upload',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _memoryGrid(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saving ? null : updateBlog,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
