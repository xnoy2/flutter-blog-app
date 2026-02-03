import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  String? imageUrl;
  bool removeImage = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.blog['title']);
    contentCtrl = TextEditingController(text: widget.blog['content']);
    imageUrl = widget.blog['image_url'];
  }

  Future<void> pickImage() async {
  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return;

  final bytes = await file.readAsBytes();
  final path =
      'blogs/${widget.blog['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

  await supabase.storage.from('blog-images').uploadBinary(
    path,
    bytes,
    fileOptions: FileOptions(upsert: true),
  );

  setState(() {
    imageUrl = supabase.storage.from('blog-images').getPublicUrl(path);
    removeImage = false;
  });
}

  Future<void> updateBlog() async {
    await supabase.from('blogs').update({
      'title': titleCtrl.text,
      'content': contentCtrl.text,
      'image_url': removeImage ? null : imageUrl,
    }).eq('id', widget.blog['id']);

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
            if (imageUrl != null && !removeImage)
              Column(
                children: [
                  Image.network(imageUrl!, height: 180),
                  TextButton(
                    onPressed: () => setState(() => removeImage = true),
                    child: const Text('Remove image'),
                  ),
                ],
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
              onPressed: pickImage,
              child: Text(
                (imageUrl == null || removeImage)
                    ? 'Upload Image'
                    : 'Change Image',
              ),
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
