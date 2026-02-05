import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../supabase_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final displayNameCtrl = TextEditingController();
  final user = supabase.auth.currentUser;

  String? avatarUrl;
  Uint8List? avatarBytes;
  bool removeAvatar = false;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    if (user == null) return;

    final res =
        await supabase.from('profiles').select().eq('id', user!.id).maybeSingle();

    if (res != null) {
      displayNameCtrl.text = (res['display_name'] ?? '').toString();
      avatarUrl = res['avatar_url'];
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> pickAvatar() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();

    if (!mounted) return;
    setState(() {
      avatarBytes = bytes;
      removeAvatar = false;
    });
  }

  Future<void> updateProfile() async {
    if (user == null) return;

    if (displayNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      String? finalAvatarUrl = avatarUrl;

      // NEW IMAGE SELECTED
      if (avatarBytes != null) {
        final path = 'avatars/${user!.id}.png';

        await supabase.storage.from('avatars').remove([path]);
        await supabase.storage.from('avatars').uploadBinary(path, avatarBytes!);

        // cache bust
        finalAvatarUrl =
            '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      // IMAGE REMOVED
      if (removeAvatar) {
        finalAvatarUrl = null;
        await supabase.storage.from('avatars').remove(['avatars/${user!.id}.png']);
      }

      await supabase.from('profiles').update({
        'display_name': displayNameCtrl.text.trim(),
        'avatar_url': finalAvatarUrl,
      }).eq('id', user!.id);

      await supabase.auth.refreshSession();

      if (!mounted) return;

      setState(() {
        avatarUrl = finalAvatarUrl;
        avatarBytes = null;
        removeAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
      );
      context.pop(true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ImageProvider? avatarImage;
    if (removeAvatar) {
      avatarImage = null;
    } else if (avatarBytes != null) {
      avatarImage = MemoryImage(avatarBytes!);
    } else if (avatarUrl != null) {
      avatarImage = NetworkImage(avatarUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pop(context);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: saving ? null : pickAvatar,
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(Icons.person, size: 46)
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: saving ? null : pickAvatar,
                              icon: const Icon(Icons.camera_alt_outlined),
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (avatarImage != null)
                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                setState(() {
                                  avatarBytes = null;
                                  removeAvatar = true;
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove avatar'),
                      ),

                    const SizedBox(height: 8),
                    TextField(
                      controller: displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : updateProfile,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
