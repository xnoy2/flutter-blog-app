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

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final bytes = await Future.wait(
      images.map((img) => img.readAsBytes()),
    );

    setState(() {
      imageBytesList.addAll(bytes);
    });
  }

  Future<void> createBlog() async {
    // REQUIRED FIELD CHECK
    if (titleCtrl.text.trim().isEmpty ||
        contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and blog content are required'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    List<String> imageUrls = [];

    for (final bytes in imageBytesList) {
      final path =
          'blogs/${DateTime.now().millisecondsSinceEpoch}_${imageUrls.length}.png';

      await supabase.storage
          .from('blog-images')
          .uploadBinary(path, bytes);

      imageUrls.add(
        supabase.storage.from('blog-images').getPublicUrl(path),
      );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Blog')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (imageBytesList.isNotEmpty)
              Wrap(
                spacing: 8,
                children: List.generate(imageBytesList.length, (i) {
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.memory(imageBytesList[i], height: 120),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
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
              child: const Text('Upload Images'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : createBlog,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
