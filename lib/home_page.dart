import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'auth/login_page.dart';
import 'blog/blog_list_page.dart';
import 'profile/profile_page.dart';

class HomePage extends StatelessWidget {
  Future<void> logout(BuildContext context) async {
    await supabase.auth.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Profile'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfilePage()),
            ),
          ),
          ListTile(
            title: const Text('Blogs'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BlogListPage()),
            ),
          ),
        ],
      ),
    );
  }
}
