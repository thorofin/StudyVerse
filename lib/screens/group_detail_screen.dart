import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../viewmodels/group_view_model.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Group        _group;
  List<User>        _members     = [];
  List<GroupMember> _roles       = [];
  bool              _loading     = true;
  bool              _initialized = false;
  StreamSubscription<List<GroupMember>>? _membersSub;

  List<User> _buildDisplayMembers({
    required List<GroupMember> roles,
    required List<User> users,
  }) {
    final usersById = {for (final u in users) u.id: u};
    return roles
        .map((r) => usersById[r.userId] ?? User(id: r.userId, name: 'Membre'))
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _group       = ModalRoute.of(context)!.settings.arguments as Group;
      _initialized = true;
      _loadMembers();
      _startMembersSubscription();
    }
  }

  void _startMembersSubscription() {
    _membersSub?.cancel();
    final vm = context.read<GroupViewModel>();
    _membersSub = DatabaseService.watchMembersByGroup(_group.id).listen(
      (roles) async {
        final members = await vm.getMembersWithDetails(_group.id);
        final displayMembers = _buildDisplayMembers(
          roles: roles,
          users: members,
        );
        if (!mounted) return;
        setState(() {
          _roles = roles;
          _members = displayMembers;
          _loading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final vm = context.read<GroupViewModel>();
    final members = await vm.getMembersWithDetails(_group.id);
    final roles   = await vm.getMembersRoles(_group.id);
    final displayMembers = _buildDisplayMembers(
      roles: roles,
      users: members,
    );
    if (!mounted) return;
    setState(() {
      _members = displayMembers;
      _roles   = roles;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm      = context.watch<GroupViewModel>();
    final cs      = Theme.of(context).colorScheme;
    final isAdmin = vm.isAdmin(_group);
    final current = vm.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMembers,
          ),
          // Menu contextuel selon le rôle
          PopupMenuButton(
            itemBuilder: (_) => [
              if (isAdmin)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Supprimer la classe',
                        style: TextStyle(color: Colors.red)),
                  ]),
                )
              else
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(children: [
                    Icon(Icons.exit_to_app_outlined),
                    SizedBox(width: 8),
                    Text('Quitter la classe'),
                  ]),
                ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                await _confirmDelete(context, vm);
              } else if (value == 'leave') {
                await _confirmLeave(context, vm);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Carte info groupe ──────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: isAdmin
                              ? cs.primaryContainer
                              : cs.secondaryContainer,
                          child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings
                                : Icons.school,
                            size: 28,
                            color: isAdmin
                                ? cs.onPrimaryContainer
                                : cs.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _group.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isAdmin
                                      ? cs.primaryContainer
                                      : cs.secondaryContainer,
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isAdmin ? 'Professeur' : 'Étudiant',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isAdmin
                                        ? cs.onPrimaryContainer
                                        : cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Code — visible pour tous
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Code de la classe',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _group.code,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy,
                                color: cs.onPrimaryContainer),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _group.code));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                  content: Text('Code copié !')));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Liste des membres ──────────────────────────
            Row(
              children: [
                const Icon(Icons.people_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Membres (${_roles.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _loading
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
                : _roles.isEmpty
                ? Center(
                child: Text('Aucun membre.',
                    style: TextStyle(color: cs.outline)))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _roles.length,
              itemBuilder: (ctx, i) {
                final roleEntry = _roles[i];
                final member = _members[i];
                final role   = roleEntry.role;
                final isMe   = member.id == current?.id;
                return _MemberTile(
                  user:    member,
                  role:    role,
                  isMe:    isMe,
                  isAdmin: isAdmin,
                  onRemove: isAdmin &&
                      role == MemberRole.student
                      ? () async {
                    await _removeMember(member);
                  }
                      : null,
                );
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // ── Boutons navigation ────────────────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context, '/chat',
                  arguments: _group,
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context, '/resources',
                  arguments: _group,
                ),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Ressources'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────

  Future<void> _removeMember(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer le membre ?'),
        content: Text('Voulez-vous retirer "${user.name}" de la classe ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.removeMember(_group.id, user.id);
      _loadMembers();
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, GroupViewModel vm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la classe ?'),
        content: const Text(
            'Cette action est irréversible. Tous les membres seront retirés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await vm.supprimerGroupe(_group);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<void> _confirmLeave(
      BuildContext context, GroupViewModel vm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la classe ?'),
        content: Text('Voulez-vous quitter "${_group.name}" ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quitter')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await vm.quitterGroupe(_group);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    }
  }
}

// ── Widget membre ─────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final User         user;
  final MemberRole   role;
  final bool         isMe;
  final bool         isAdmin;
  final VoidCallback? onRemove;

  const _MemberTile({
    required this.user,
    required this.role,
    required this.isMe,
    required this.isAdmin,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final isProfesseur = role == MemberRole.admin;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isProfesseur
              ? cs.primaryContainer
              : cs.secondaryContainer,
          child: Text(
            user.name[0].toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isProfesseur
                  ? cs.onPrimaryContainer
                  : cs.onSecondaryContainer,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(user.name,
                style:
                const TextStyle(fontWeight: FontWeight.w500)),
            if (isMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Vous',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              isProfesseur
                  ? Icons.admin_panel_settings_outlined
                  : Icons.school_outlined,
              size: 14,
              color: cs.outline,
            ),
            const SizedBox(width: 4),
            Text(
              isProfesseur ? 'Professeur' : 'Étudiant',
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ],
        ),
        // Bouton retirer (admin only, pas sur lui-même)
        trailing: onRemove != null
            ? IconButton(
          icon: const Icon(Icons.person_remove_outlined,
              color: Colors.red),
          tooltip: 'Retirer',
          onPressed: onRemove,
        )
            : null,
      ),
    );
  }
}