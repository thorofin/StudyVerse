import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class GroupViewModel extends ChangeNotifier {
  User?       _currentUser;
  List<Group> _groups         = [];
  bool        _loading        = false;
  String?     _error;
  String?     _successMessage;
  String?     _lastGeneratedCode;

  User?       get currentUser       => _currentUser;
  List<Group> get groups            => List.unmodifiable(_groups);
  bool        get loading           => _loading;
  String?     get error             => _error;
  String?     get successMessage    => _successMessage;
  String?     get lastGeneratedCode => _lastGeneratedCode;
  bool        get isLoggedIn        => _currentUser != null;

  // ── Session ───────────────────────────────────────────────

  /// Appelé au SplashScreen — restaure la session et les groupes
  Future<bool> tryRestoreSession() async {
    final session = await AuthService.getSession();
    if (session == null) return false;
    _currentUser = User(id: session['id']!, name: session['name']!);
    await consulterListeGroupes();
    return true;
  }

  // ── Auth — login par nom ──────────────────────────────────

  Future<bool> login(String name) async {
    if (name.trim().isEmpty) {
      _error = 'Le nom ne peut pas être vide.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error   = null;
    notifyListeners();

    // Chercher si l'utilisateur existe déjà par son nom
    User? existing = await DatabaseService.findUserByName(name.trim());

    if (existing != null) {
      // Utilisateur connu → restaurer son compte et ses groupes
      _currentUser = existing;
    } else {
      // Nouvel utilisateur → créer un compte
      final id = const Uuid().v4();
      _currentUser = User(id: id, name: name.trim());
      await DatabaseService.insertUser(_currentUser!);
    }

    // Sauvegarder la session
    await AuthService.saveSession(
        _currentUser!.id, _currentUser!.name);

    // Charger les groupes de cet utilisateur
    await consulterListeGroupes();

    _loading = false;
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await AuthService.clearSession();
    _currentUser = null;
    _groups      = [];
    notifyListeners();
  }

  // ── Vérifier le rôle ─────────────────────────────────────

  bool isAdmin(Group group) => group.adminId == _currentUser?.id;

  Future<MemberRole?> getRoleInGroup(String groupId) async {
    if (_currentUser == null) return null;
    return DatabaseService.getUserRole(groupId, _currentUser!.id);
  }

  // ── F01 : Consulter liste des groupes ─────────────────────

  Future<void> consulterListeGroupes() async {
    _loading = true;
    notifyListeners();
    if (_currentUser != null) {
      _groups = await DatabaseService.getGroupsByUser(_currentUser!.id);
    }
    _loading = false;
    notifyListeners();
  }

  // ── F01 : Générer code unique ─────────────────────────────

  String genererCodeUnique() {
    final code = Group.generateCode();
    _lastGeneratedCode = code;
    notifyListeners();
    return code;
  }

  // ── F01 : Créer un groupe (Admin) ─────────────────────────

  Future<Group?> creerGroupe(String name) async {
    if (name.trim().isEmpty) {
      _error = 'Le nom du groupe est requis.';
      notifyListeners();
      return null;
    }
    if (_currentUser == null) {
      _error = 'Vous devez être connecté.';
      notifyListeners();
      return null;
    }

    _loading = true;
    _error   = null;
    notifyListeners();

    final group = Group(
      id:      const Uuid().v4(),
      name:    name.trim(),
      code:    genererCodeUnique(),
      adminId: _currentUser!.id,
    );

    await DatabaseService.insert(group);

    // Créateur = membre ADMIN
    await DatabaseService.insertMember(GroupMember(
      groupId: group.id,
      userId:  _currentUser!.id,
      role:    MemberRole.admin,
    ));

    _groups.add(group);
    _successMessage = 'Classe créée ! Code : ${group.code}';
    _loading        = false;
    notifyListeners();
    return group;
  }

  // ── F01 : Valider code d'invitation ───────────────────────

  bool validerCodeInvitation(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      _error = 'Le code ne peut pas être vide.';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(clean)) {
      _error = 'Le code doit contenir 6 caractères.';
      notifyListeners();
      return false;
    }
    return true;
  }

  // ── F01 : Rejoindre un groupe (Student) ───────────────────

  Future<Group?> rejoindreGroupeViaCode(String code) async {
    if (!validerCodeInvitation(code)) return null;
    if (_currentUser == null) return null;

    final clean = code.trim().toUpperCase();
    _loading = true;
    _error   = null;
    notifyListeners();

    final already = _groups.where((g) => g.code == clean).firstOrNull;
    if (already != null) {
      _successMessage = 'Vous êtes déjà dans "${already.name}".';
      _loading        = false;
      notifyListeners();
      return already;
    }

    final found = await DatabaseService.findByCode(clean);
    if (found != null) {
      await DatabaseService.insertMember(GroupMember(
        groupId: found.id,
        userId:  _currentUser!.id,
        role:    MemberRole.student,
      ));
      _groups.add(found);
      _successMessage = 'Vous avez rejoint "${found.name}" !';
    } else {
      _error = 'Code invalide. Vérifiez avec votre professeur.';
    }

    _loading = false;
    notifyListeners();
    return found;
  }

  // ── Supprimer un groupe (Admin) ───────────────────────────

  Future<void> supprimerGroupe(Group group) async {
    if (!isAdmin(group)) {
      _error = 'Seul l\'admin peut supprimer ce groupe.';
      notifyListeners();
      return;
    }
    await DatabaseService.deleteGroup(group.id);
    _groups.removeWhere((g) => g.id == group.id);
    notifyListeners();
  }

  // ── Quitter un groupe (Student) ───────────────────────────

  Future<void> quitterGroupe(Group group) async {
    if (_currentUser == null) return;
    await DatabaseService.removeMember(group.id, _currentUser!.id);
    _groups.removeWhere((g) => g.id == group.id);
    notifyListeners();
  }

  // ── Membres d'un groupe ───────────────────────────────────

  Future<List<User>> getMembersWithDetails(String groupId) async {
    return DatabaseService.getUsersByGroup(groupId);
  }

  Future<List<GroupMember>> getMembersRoles(String groupId) async {
    return DatabaseService.getMembersByGroup(groupId);
  }

  // ── Utilitaires ───────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  String generateCodeForTest() => Group.generateCode();
}