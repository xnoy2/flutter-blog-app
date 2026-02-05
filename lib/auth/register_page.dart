import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../supabase_client.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;


  Future<void> register() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    final confirmPassword = confirmPasswordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Pass message to Login page
      context.go(
        '/login',
        extra: 'Registration successful! Please log in.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // EMAIL
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // PASSWORD
            TextField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // CONFIRM PASSWORD
            TextField(
              controller: confirmPasswordCtrl,
              obscureText: obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => obscureConfirm = !obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // REGISTER BUTTON
            SizedBox(
            width: 200,
            height: 48, 
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: loading ? null : register,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Register'),
            ),
          ),

            const SizedBox(height: 12),

            // BACK TO LOGIN
            TextButton(
              onPressed: loading ? null : () => context.go('/login'),
              child: const Text('Already have an account? Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
