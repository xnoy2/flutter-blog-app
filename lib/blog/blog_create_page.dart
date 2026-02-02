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
  Uint8List? _imageBytes;

  Future<void> pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    _imageBytes = await img.readAsBytes();
    setState(() {});
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

  String? imageUrl;

  if (_imageBytes != null) {
    final path = 'blogs/${DateTime.now().millisecondsSinceEpoch}.png';
    await supabase.storage
        .from('blog-images')
        .uploadBinary(path, _imageBytes!);
    imageUrl = supabase.storage.from('blog-images').getPublicUrl(path);
  }

  await supabase.from('blogs').insert({
    'title': titleCtrl.text.trim(),
    'content': contentCtrl.text.trim(),
    'author': supabase.auth.currentUser!.id,
    'image_url': imageUrl,
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
            if (_imageBytes != null)
              Stack(
                children: [
                  Image.memory(_imageBytes!, height: 180, fit: BoxFit.cover),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _imageBytes = null),
                    ),
                  ),
                ],
              ),

            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content'), maxLines: 5),

            const SizedBox(height: 12),
            ElevatedButton(onPressed: pickImage, child: const Text('Upload Image')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: createBlog, child: const Text('Create')),
          ],
        ),
      ),
    );
  }
}
