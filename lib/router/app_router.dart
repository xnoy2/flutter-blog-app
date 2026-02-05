import 'dart:async';
import 'package:flutter/material.dart'; 
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../supabase_client.dart';

import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../blog/blog_list_page.dart';
import '../blog/blog_create_page.dart';
import '../blog/post_view_page.dart';
import '../profile/profile_page.dart';
import '../blog/blog_edit_route_page.dart';

/// Notifies go_router to re-check redirects when auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentSession != null;

    final goingToLogin = state.matchedLocation == '/login';
    final goingToRegister = state.matchedLocation == '/register';

    // If not logged in, force user to /login (but allow /register)
    if (!isLoggedIn) {
      return (goingToLogin || goingToRegister) ? null : '/login';
    }

    // If logged in, prevent going back to login/register
    if (isLoggedIn && (goingToLogin || goingToRegister)) return '/';

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const BlogListPage(),
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),

    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(), 
    ),

    GoRoute(
      path: '/create',
      builder: (context, state) => const BlogCreatePage(),
    ),

    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(), 
    ),

    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        return PostViewPage(postId: postId);
      },
    ),

    GoRoute(
      path: '/edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BlogEditRoutePage(blogId: id); // use blog_edit_route
      },
    ),
  ],
);
