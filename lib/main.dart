import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/main_layout.dart';
import 'screens/locations_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/add_location_screen.dart';
import 'screens/join_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final uid = await AuthService(FirebaseAuth.instance).signInAnonymously();
  // Fire-and-forget: push registration (incl. the browser permission prompt
  // on web) must never block the UI from appearing.
  unawaited(FcmService(FirebaseFirestore.instance).registerToken(uid));
  runApp(const ProviderScope(child: ToAquiApp()));
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/locations',
            builder: (context, state) => const LocationsScreen(),
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => ContactsScreen(
              autoOpenAdd: state.uri.queryParameters['openAdd'] == 'true',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/locations/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddLocationScreen(),
      ),
      GoRoute(
        path: '/join',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JoinScreen(),
      ),
    ],
  );
});

class ToAquiApp extends ConsumerWidget {
  const ToAquiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ToAqui',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
