import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/app_state.dart';
import 'core/app_theme.dart';
import 'screens/cartilha_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/forum_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/search_screen.dart';
import 'screens/senai_screen.dart';

final appState = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // SUPABASE_URL and SUPABASE_ANON_KEY can also be supplied by --dart-define.
  }

  runApp(const VenexusApp());
  unawaited(appState.init());
}

class VenexusApp extends StatelessWidget {
  const VenexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Venexus',
      theme: buildVenexusTheme(),
      home: const _StartupGate(),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget screen;
    final name = settings.name ?? '/';

    if (!appState.ready) {
      screen = const _StartupGate();
      return MaterialPageRoute(builder: (_) => screen, settings: settings);
    }

    if (!appState.isLoggedIn) {
      switch (name) {
        case '/register':
          screen = const RegisterScreen();
          break;
        case '/forgot-password':
          screen = const ForgotPasswordScreen();
          break;
        case '/reset-password':
          final phone = settings.arguments is String ? settings.arguments as String : '';
          screen = ResetPasswordScreen(phone: phone);
          break;
        default:
          screen = const LoginScreen();
      }
      return MaterialPageRoute(builder: (_) => screen, settings: settings);
    }

    if (name.startsWith('/forum/') && name != '/forum/new') {
      final postId = name.replaceFirst('/forum/', '');
      screen = PostDetailScreen(postId: postId);
      return MaterialPageRoute(builder: (_) => screen, settings: settings);
    }

    switch (name) {
      case '/cartilha':
        screen = const CartilhaScreen();
        break;
      case '/forum':
        screen = const ForumScreen();
        break;
      case '/forum/new':
        screen = const CreatePostScreen();
        break;
      case '/senai':
        screen = const SenaiScreen();
        break;
      case '/perfil':
        screen = const ProfileScreen();
        break;
      case '/search':
        screen = const SearchScreen();
        break;
      case '/notifications':
        screen = const NotificationsScreen();
        break;
      case '/login':
      case '/register':
      case '/forgot-password':
      case '/reset-password':
      case '/':
      default:
        screen = const DashboardScreen();
        break;
    }

    return MaterialPageRoute(builder: (_) => screen, settings: settings);
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        if (appState.ready) {
          return appState.isLoggedIn ? const DashboardScreen() : const LoginScreen();
        }

        return _StartupScreen(
          error: appState.initializationError,
          retrying: appState.initializing,
          onRetry: appState.init,
        );
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.error,
    required this.retrying,
    required this.onRetry,
  });

  final Object? error;
  final bool retrying;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border.fromBorderSide(BorderSide(color: AppColors.gray200)),
                  boxShadow: AppShadows.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'VENEXUS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!hasError) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      const Text(
                        'Conectando ao serviço...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.gray600),
                      ),
                    ] else ...[
                      const Icon(Icons.cloud_off_outlined, color: AppColors.red, size: 42),
                      const SizedBox(height: 14),
                      const Text(
                        'Não foi possível iniciar o aplicativo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.purple,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gray600, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: retrying ? null : onRetry,
                        child: Text(retrying ? 'TENTANDO...' : 'TENTAR NOVAMENTE'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
