import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/group_view_model.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft:  Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'StudyVerse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Collaborative Study Room',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tabs Login / Register
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: const Color(0xFF6C63FF),
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        tabs: const [
                          Tab(text: 'Login'),
                          Tab(text: 'Register'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Tab Views ──────────────────────────────
              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _LoginForm(),
                    _RegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Formulaire Login ──────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<GroupViewModel>();
    vm.clearError();
    final ok = await vm.login(
      email:    _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email
            _InputField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'exemple@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email requis';
                if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$')
                    .hasMatch(v)) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            _InputField(
              controller: _passwordCtrl,
              label: 'Mot de passe',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscure: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Mot de passe requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Erreur
            if (vm.error != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.error!,
                        style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Bouton Login
            vm.loading
                ? const Center(child: CircularProgressIndicator())
                : _GradientButton(
                    label: 'Se connecter',
                    icon: Icons.login_rounded,
                    onTap: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Formulaire Register ───────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;
  bool  _obscureConf  = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<GroupViewModel>();
    vm.clearError();
    final ok = await vm.register(
      name:     _nameCtrl.text,
      email:    _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nom
            _InputField(
              controller: _nameCtrl,
              label: 'Nom complet',
              hint: 'Ahmed Ben Ali',
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),

            // Email
            _InputField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'exemple@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email requis';
                if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$')
                    .hasMatch(v)) {
                  return 'Email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Password
            _InputField(
              controller: _passwordCtrl,
              label: 'Mot de passe',
              hint: 'Min. 6 caractères',
              icon: Icons.lock_outline,
              obscure: _obscure,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Mot de passe requis';
                }
                if (v.length < 6) {
                  return 'Minimum 6 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Confirm password
            _InputField(
              controller: _confirmCtrl,
              label: 'Confirmer le mot de passe',
              hint: '••••••••',
              icon: Icons.lock_outline,
              obscure: _obscureConf,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConf
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _obscureConf = !_obscureConf),
              ),
              validator: (v) {
                if (v != _passwordCtrl.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),

            // Erreur
            if (vm.error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.error!,
                        style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Bouton Register
            vm.loading
                ? const Center(child: CircularProgressIndicator())
                : _GradientButton(
                    label: 'Créer un compte',
                    icon: Icons.person_add_outlined,
                    onTap: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets communs ───────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController    controller;
  final String                   label;
  final String                   hint;
  final IconData                 icon;
  final bool                     obscure;
  final Widget?                  suffixIcon;
  final TextInputType?           keyboardType;
  final TextCapitalization       textCapitalization;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure           = false,
    this.suffixIcon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:          controller,
      obscureText:         obscure,
      keyboardType:        keyboardType,
      textCapitalization:  textCapitalization,
      validator:           validator,
      decoration: InputDecoration(
        labelText:   label,
        hintText:    hint,
        prefixIcon:  Icon(icon, color: const Color(0xFF6C63FF)),
        suffixIcon:  suffixIcon,
        filled:      true,
        fillColor:   Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF6C63FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}