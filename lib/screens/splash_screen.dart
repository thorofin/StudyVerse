import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/group_view_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final vm = context.read<GroupViewModel>();

    // Lancer en parallèle : vérif session + délai minimum de 2s
    final results = await Future.wait([
      vm.tryRestoreSession(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    if (!mounted) return;

    final hasSession = results[0] as bool;
    Navigator.pushReplacementNamed(
      context,
      hasSession ? '/home' : '/auth',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'StudyVerse',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Collaborative Study Room',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 56),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}