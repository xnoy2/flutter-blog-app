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

  String? avatarUrl;        // stored avatar
  Uint8List? avatarBytes;   // preview avatar
  bool removeAvatar = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  // ===============================
  // FETCH PROFILE
  // ===============================
  Future<void> fetchProfile() async {
    if (user == null) return;

    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .maybeSingle();

    if (res != null) {
      displayNameCtrl.text = res['display_name'] ?? '';
      avatarUrl = res['avatar_url'];
    }

    setState(() => loading = false);
  }

  // ===============================
  // PICK AVATAR
  // ===============================
  Future<void> pickAvatar() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;

    final bytes = await img.readAsBytes();

    setState(() {
      avatarBytes = bytes;
      removeAvatar = false; // override remove
    });
  }

 // SAVE PROFILE
Future<void> updateProfile() async {
  String? finalAvatarUrl = avatarUrl;

  // NEW IMAGE SELECTED
  if (avatarBytes != null) {
    final path = 'avatars/${user!.id}.png';

    await supabase.storage.from('avatars').remove([path]);
    await supabase.storage
        .from('avatars')
        .uploadBinary(path, avatarBytes!);

    //  CACHE BUST
    finalAvatarUrl =
        '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // IMAGE REMOVED
  if (removeAvatar) {
    finalAvatarUrl = null;
    await supabase.storage
        .from('avatars')
        .remove(['avatars/${user!.id}.png']);
  }

  await supabase.from('profiles').update({
    'display_name': displayNameCtrl.text.trim(),
    'avatar_url': finalAvatarUrl,
  }).eq('id', user!.id);

  // FORCE SESSION REFRESH
  await supabase.auth.refreshSession();

  setState(() {
    avatarUrl = finalAvatarUrl;
    avatarBytes = null;
    removeAvatar = false;
  });

  showMsg('Profile updated');
}

  void showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    /// FINAL IMAGE DECISION (THIS IS THE FIX)
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
              if (mounted) Navigator.pop(context);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ===============================
            // AVATAR
            // ===============================
            Stack(
              alignment: Alignment.topRight,
              children: [
                GestureDetector(
                  onTap: pickAvatar,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                ),

                if (avatarImage != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        avatarBytes = null;
                        removeAvatar = true;
                      });
                    },
                  ),
              ],
            ),

            const SizedBox(height: 20),

            TextField(
              controller: displayNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: updateProfile,
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
