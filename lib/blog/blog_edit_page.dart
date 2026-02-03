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

  List<String> imageUrls = [];
  List<Uint8List> newImages = [];

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.blog['title']);
    contentCtrl = TextEditingController(text: widget.blog['content']);
    imageUrls = List<String>.from(widget.blog['image_urls'] ?? []);
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes = await Future.wait(
      images.map((img) => img.readAsBytes()),
    );

    setState(() {
      newImages.addAll(bytes);
    });
  }

  Future<void> updateBlog() async {
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

    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Updated successfully')),
  );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Blog')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (imageUrls.isNotEmpty)
              Wrap(
                spacing: 8,
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

            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 5,
            ),

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
