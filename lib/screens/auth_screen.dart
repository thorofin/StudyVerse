import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/group_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _ctrl    = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<GroupViewModel>();
    vm.clearError();
    final ok = await vm.login(_ctrl.text);
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Icon(Icons.school_rounded, size: 80, color: cs.primary),
                  const SizedBox(height: 24),

                  Text(
                    'StudyVerse',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Collaborative Study Room',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.outline),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Champ nom
                  TextFormField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      labelText: 'Votre nom',
                      hintText: 'Ex: Ahmed, Sara...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Le nom est requis'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),

                  const SizedBox(height: 12),

                  // Info : même nom = même compte
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: cs.outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Si vous avez déjà un compte, entrez le même nom pour retrouver vos classes.',
                            style: TextStyle(
                                fontSize: 12, color: cs.outline),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Erreur
                  if (vm.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        vm.error!,
                        style: TextStyle(color: cs.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Bouton
                  vm.loading
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton(
                    onPressed: _submit,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Entrer',
                          style: TextStyle(fontSize: 16)),
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