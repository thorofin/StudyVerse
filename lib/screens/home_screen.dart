import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../viewmodels/group_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<GroupViewModel>().consulterListeGroupes(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Group> _filteredGroups(List<Group> groups) {
    if (_searchQuery.isEmpty) return groups;
    return groups
        .where((g) =>
            g.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<GroupViewModel>();
    final groups = _filteredGroups(vm.groups);
    final name   = vm.currentUser?.name ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _Header(name: name, vm: vm),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    context.read<GroupViewModel>().consulterListeGroupes(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _SearchBar(
                        ctrl: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 20),
                      _StatsRow(groupCount: vm.groups.length),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Study Groups',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          _NewButton(
                            onCreateTap: () =>
                                _showCreerGroupeDialog(context),
                            onJoinTap: () =>
                                _showRejoindreDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      vm.loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : groups.isEmpty
                              ? _EmptyState(
                                  hasSearch: _searchQuery.isNotEmpty)
                              : Column(
                                  children: groups
                                      .asMap()
                                      .entries
                                      .map((e) => _GroupCard(
                                            group: e.value,
                                            index: e.key,
                                          ))
                                      .toList(),
                                ),
                      const SizedBox(height: 24),
                      if (vm.groups.isNotEmpty) ...[
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RecentActivity(groups: vm.groups),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        onCreateTap: () => _showCreerGroupeDialog(context),
        onJoinTap:   () => _showRejoindreDialog(context),
        onLogout: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Déconnexion'),
              content:
                  const Text('Voulez-vous vous déconnecter ?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Déconnecter')),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            await context.read<GroupViewModel>().logout();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/auth');
            }
          }
        },
      ),
    );
  }

  void _showCreerGroupeDialog(BuildContext context) {
    final ctrl        = TextEditingController();
    final vm          = context.read<GroupViewModel>();
    final codePreview = vm.genererCodeUnique();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Créer une classe'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Nom de la classe',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.class_outlined),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Code généré automatiquement',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          codePreview,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        color: Colors.white, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: codePreview));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Code copié !')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
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

  void _showCodeDialog(
      BuildContext context, String name, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Classe créée !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                size: 60, color: Colors.green),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Partagez ce code avec vos étudiants :',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: Colors.white,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRejoindreDialog(BuildContext context) {
    final ctrl = TextEditingController();
    String? erreur;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.group_add_outlined,
                  color: Color(0xFF6C63FF)),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
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
              Text(
                'Demandez le code à votre professeur.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
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
                            : vm.error ?? 'Code invalide.',
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

// ── Header violet ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String         name;
  final GroupViewModel vm;
  const _Header({required this.name, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $name!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ready to study together?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text(
                      'Voulez-vous vous déconnecter ?'),
                  actions: [
                    TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        child: const Text('Déconnecter')),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await vm.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/auth');
                }
              }
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.3),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barre de recherche ────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final ValueChanged<String>  onChanged;
  const _SearchBar({required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search study groups...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int groupCount;
  const _StatsRow({required this.groupCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.groups_outlined,
          value: '$groupCount',
          label: 'Groups',
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.access_time_outlined,
          value: '24h',
          label: 'This Week',
          color: const Color(0xFFFF6584),
        ),
        const SizedBox(width: 12),
        _StatCard(
          icon: Icons.trending_up,
          value: '85%',
          label: 'Progress',
          color: const Color(0xFF43D9AD),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final Color    color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton New ────────────────────────────────────────────────

class _NewButton extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  const _NewButton(
      {required this.onCreateTap, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'create') onCreateTap();
        if (v == 'join') onJoinTap();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'create',
          child: Row(children: [
            Icon(Icons.add_circle_outline,
                color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Créer une classe'),
          ]),
        ),
        PopupMenuItem(
          value: 'join',
          child: Row(children: [
            Icon(Icons.group_add_outlined,
                color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Rejoindre une classe'),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte groupe ──────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final Group group;
  final int   index;
  const _GroupCard({required this.group, required this.index});

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFFFF6584),
    Color(0xFF43D9AD),
    Color(0xFFFFA94D),
    Color(0xFF4DABF7),
    Color(0xFFDA77F2),
  ];

  static const _icons = [
    Icons.calculate_outlined,
    Icons.science_outlined,
    Icons.computer_outlined,
    Icons.biotech_outlined,
    Icons.history_edu_outlined,
    Icons.language_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final vm      = context.read<GroupViewModel>();
    final isAdmin = vm.isAdmin(group);
    final color   = _colors[index % _colors.length];
    final icon    = _icons[index % _icons.length];

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/group-detail',
        arguments: group,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 13,
                          color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        isAdmin ? 'Professeur' : 'Étudiant',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.code,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${(index + 1) * 5} min ago',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent Activity ───────────────────────────────────────────

class _RecentActivity extends StatelessWidget {
  final List<Group> groups;
  const _RecentActivity({required this.groups});

  @override
  Widget build(BuildContext context) {
    final recent = groups.take(3).toList();
    return Column(
      children: recent.asMap().entries.map((e) {
        final group   = e.value;
        final vm      = context.read<GroupViewModel>();
        final isAdmin = vm.isAdmin(group);
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            '/group-detail',
            arguments: group,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(0xFF6C63FF).withOpacity(0.15),
                  child: Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isAdmin
                            ? 'Vous êtes professeur'
                            : 'Vous êtes étudiant',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined,
                  size: 40, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Aucun groupe trouvé'
                  : 'Aucune classe pour l\'instant',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Essayez un autre terme de recherche.'
                  : 'Créez une classe ou rejoignez-en une avec un code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  final VoidCallback onLogout;
  const _BottomNav({
    required this.onCreateTap,
    required this.onJoinTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.add_circle_outline,
                label: 'Créer',
                active: false,
                onTap: onCreateTap,
              ),
              _NavItem(
                icon: Icons.group_add_outlined,
                label: 'Rejoindre',
                active: false,
                onTap: onJoinTap,
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                active: false,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF6C63FF)
        : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}