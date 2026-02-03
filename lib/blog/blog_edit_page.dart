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

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.blog['title']);
    contentCtrl = TextEditingController(text: widget.blog['content']);
    imageUrls = List<String>.from(widget.blog['image_urls'] ?? []);
  }

  // PICK MULTIPLE IMAGES
  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes =
        await Future.wait(images.map((img) => img.readAsBytes()));

    setState(() {
      newImages.addAll(bytes);
    });
  }

  // SAVE UPDATE
  Future<void> updateBlog() async {
    // Upload newly added images
    for (final bytes in newImages) {
      final path =
          'blogs/${widget.blog['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage
          .from('blog-images')
          .uploadBinary(path, bytes);

      imageUrls.add(
        supabase.storage.from('blog-images').getPublicUrl(path),
      );
    }

    await supabase.from('blogs').update({
      'title': titleCtrl.text.trim(),
      'content': contentCtrl.text.trim(),
      'image_urls': imageUrls,
    }).eq('id', widget.blog['id']);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updated successfully')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Blog')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// EXISTING IMAGES
            if (imageUrls.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(imageUrls.length, (i) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.network(imageUrls[i], height: 120),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            imageUrls.removeAt(i);
                          });
                        },
                      ),
                    ],
                  );
                }),
              ),

            /// NEW IMAGES PREVIEW
            if (newImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(newImages.length, (i) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.memory(newImages[i], height: 120),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            newImages.removeAt(i);
                          });
                        },
                      ),
                    ],
                  );
                }),
              ),
            ],

            const SizedBox(height: 16),

            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 5,
            ),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: pickImages,
              child: const Text('Add Images'),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: updateBlog,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
