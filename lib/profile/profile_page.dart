import 'dart:typed_data';
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

  bool loading = true;
  bool savingName = false;      // for display name save
  bool savingAvatar = false;    // for avatar auto-save
  bool changedSomething = false; // return to BlogList so it can refresh

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

    if (!mounted) return;

    if (res != null) {
      displayNameCtrl.text = (res['display_name'] ?? '').toString();
      avatarUrl = (res['avatar_url'] ?? '').toString();
      if (avatarUrl != null && avatarUrl!.isEmpty) avatarUrl = null;
    }

    setState(() => loading = false);
  }

  // AUTO SAVE AVATAR ON PICK
  Future<void> pickAvatarAndAutoSave() async {
    if (user == null || savingAvatar) return;

    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();
    if (!mounted) return;

    setState(() {
      avatarBytes = bytes; // show preview instantly
    });

    await _saveAvatar(bytes);
  }

  Future<void> _saveAvatar(Uint8List bytes) async {
    if (user == null) return;

    setState(() => savingAvatar = true);

    try {
      final path = 'avatars/${user!.id}.png';

      // overwrite existing
      await supabase.storage.from('avatars').remove([path]);
      await supabase.storage.from('avatars').uploadBinary(path, bytes);

      // cache bust
      final newUrl =
          '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

      await supabase.from('profiles').update({
        'avatar_url': newUrl,
      }).eq('id', user!.id);

      if (!mounted) return;

      setState(() {
        avatarUrl = newUrl;
        avatarBytes = null; // rely on URL
        changedSomething = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save photo: $e')),
      );
    } finally {
      if (mounted) setState(() => savingAvatar = false);
    }
  }

  // AUTO REMOVE AVATAR
  Future<void> removeAvatarAndAutoSave() async {
    if (user == null || savingAvatar) return;

    setState(() => savingAvatar = true);

    try {
      final path = 'avatars/${user!.id}.png';

      await supabase.storage.from('avatars').remove([path]);
      await supabase.from('profiles').update({'avatar_url': null}).eq('id', user!.id);

      if (!mounted) return;

      setState(() {
        avatarUrl = null;
        avatarBytes = null;
        changedSomething = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: $e')),
      );
    } finally {
      if (mounted) setState(() => savingAvatar = false);
    }
  }

  // SAVE Button
  Future<void> saveDisplayName() async {
    if (user == null) return;

    final name = displayNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required')),
      );
      return;
    }

    setState(() => savingName = true);

    try {
      await supabase.from('profiles').update({
        'display_name': name,
      }).eq('id', user!.id);

      if (!mounted) return;

      setState(() => changedSomething = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save name: $e')),
      );
    } finally {
      if (mounted) setState(() => savingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // what avatar to show
    ImageProvider? avatarImage;
    if (avatarBytes != null) {
      avatarImage = MemoryImage(avatarBytes!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl!);
    }

    final busy = savingAvatar || savingName;

    return WillPopScope(
      onWillPop: () async {
        // return result to caller so BlogList can refresh
        Navigator.pop(context, changedSomething);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, changedSomething),
          ),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await supabase.auth.signOut();
                if (mounted) Navigator.pop(context, true);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: busy ? null : pickAvatarAndAutoSave,
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
                          child: savingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: busy ? null : pickAvatarAndAutoSave,
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
                      onPressed: busy ? null : removeAvatarAndAutoSave,
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
                      onPressed: savingName ? null : saveDisplayName,
                      icon: savingName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save name'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
