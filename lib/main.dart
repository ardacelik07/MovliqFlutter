import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MovliqApp(),
    ),
  );
}

class MovliqApp extends StatelessWidget {
  const MovliqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movliq',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
