import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../supabase_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    // check if email and pass is null
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      //  after login, jump to blog_list_page
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Enter Email *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: InputDecoration(
                labelText: 'Enter Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : login,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Login'),
            ),
          ),


            const SizedBox(height: 12),

            TextButton(
              onPressed: loading ? null : () => context.push('/register'),
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
