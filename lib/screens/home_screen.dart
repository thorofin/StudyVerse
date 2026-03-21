import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../viewmodels/group_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
          () => context.read<GroupViewModel>().consulterListeGroupes(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${vm.currentUser?.name ?? ''} !'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<GroupViewModel>().consulterListeGroupes(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<GroupViewModel>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/auth');
              }
            },
          ),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.groups.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
        onRefresh: () => context
            .read<GroupViewModel>()
            .consulterListeGroupes(),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: vm.groups.length,
          itemBuilder: (ctx, i) =>
              _GroupCard(group: vm.groups[i]),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Étudiant : rejoindre
          FloatingActionButton.small(
            heroTag: 'join',
            tooltip: 'Rejoindre une classe',
            onPressed: () => _showRejoindreDialog(context),
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 12),
          // Admin : créer
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => _showCreerGroupeDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Créer une classe'),
          ),
        ],
      ),
    );
  }

  // ── Créer un groupe (Admin) ───────────────────────────────

  void _showCreerGroupeDialog(BuildContext context) {
    final ctrl        = TextEditingController();
    final vm          = context.read<GroupViewModel>();
    final codePreview = vm.genererCodeUnique();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.admin_panel_settings_outlined),
            SizedBox(width: 8),
            Text('Créer une classe'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Nom de la classe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_outlined),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code généré automatiquement',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        Text(
                          codePreview,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: codePreview));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copié !')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Partagez ce code avec vos étudiants.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              final group = await context
                  .read<GroupViewModel>()
                  .creerGroupe(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (group != null && context.mounted) {
                _showCodeDialog(context, group.name, group.code);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  // ── Afficher le code après création ──────────────────────

  void _showCodeDialog(
      BuildContext context, String name, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Classe créée !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: Colors.green),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Partagez ce code avec vos étudiants :',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color:
                Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copié !')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copier le code'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Rejoindre un groupe (Étudiant) ────────────────────────

  void _showRejoindreDialog(BuildContext context) {
    final ctrl = TextEditingController();
    String? erreur;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.school_outlined),
              SizedBox(width: 8),
              Text('Rejoindre une classe'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Code de la classe',
                  hintText: 'Ex: ABC123',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  errorText: erreur,
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                autofocus: true,
                onChanged: (v) {
                  setDialogState(() {
                    erreur = v.length == 6 ? null : erreur;
                  });
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Demandez le code à votre professeur.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final vm    = context.read<GroupViewModel>();
                final valid = vm.validerCodeInvitation(ctrl.text);
                if (!valid) {
                  setDialogState(() => erreur = vm.error);
                  vm.clearError();
                  return;
                }
                final group =
                await vm.rejoindreGroupeViaCode(ctrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        group != null
                            ? 'Vous avez rejoint "${group.name}" !'
                            : vm.error ??
                            'Code invalide.',
                      ),
                    ),
                  );
                  vm.clearError();
                }
              },
              child: const Text('Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privés ────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final vm      = context.read<GroupViewModel>();
    final cs      = Theme.of(context).colorScheme;
    final adminMe = vm.isAdmin(group);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: adminMe
              ? cs.primaryContainer
              : cs.secondaryContainer,
          child: Icon(
            adminMe ? Icons.admin_panel_settings : Icons.school,
            color: adminMe
                ? cs.onPrimaryContainer
                : cs.onSecondaryContainer,
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            // Badge rôle
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: adminMe
                    ? cs.primaryContainer
                    : cs.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                adminMe ? 'Professeur' : 'Étudiant',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: adminMe
                      ? cs.onPrimaryContainer
                      : cs.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              group.code,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: cs.outline,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: group.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copié !'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Icon(Icons.copy, size: 12, color: cs.outline),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(
          context,
          '/group-detail',
          arguments: group,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.class_outlined, size: 80, color: cs.outline),
            const SizedBox(height: 20),
            Text(
              'Aucune classe pour l\'instant',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Créez une classe (professeur)\nou rejoignez-en une avec un code (étudiant).',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}