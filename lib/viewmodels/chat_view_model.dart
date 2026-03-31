import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/user.dart';
import '../services/database_service.dart';

class ChatViewModel extends ChangeNotifier {
  final String _groupId;
  final User _currentUser;

  List<Message> _messages = [];
  Map<String, User> _membersById = {};
  List<String> _typingUserIds = [];
  bool _loading = false;
  String? _error;

  Timer? _typingDebounce;
  StreamSubscription<List<Message>>? _messagesSub;
  StreamSubscription<List<User>>? _membersSub;
  StreamSubscription<List<String>>? _typingSub;
  bool _isTyping = false;
  bool _isRefreshing = false;

  ChatViewModel({
    required String groupId,
    required User currentUser,
  })  : _groupId = groupId,
        _currentUser = currentUser;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  String? get error => _error;
  User get currentUser => _currentUser;

  List<User> get typingUsers {
    return _typingUserIds
        .map((id) => _membersById[id])
        .whereType<User>()
        .toList();
  }

  String getTypingText() {
    final users = typingUsers;
    if (users.isEmpty) return '';
    if (users.length == 1) return '${users.first.name} est en train d\'ecrire...';
    if (users.length == 2) return '${users[0].name} et ${users[1].name} ecrivent...';
    return '${users[0].name} et ${users.length - 1} autres ecrivent...';
  }

  String senderNameOf(String userId) {
    return _membersById[userId]?.name ?? 'Membre';
  }

  Future<void> init() async {
    _loading = true;
    _error = null;
    notifyListeners();

    await _refreshAll();
    _startRealtimeListeners();

    _loading = false;
    notifyListeners();
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final members = await DatabaseService.getUsersByGroup(_groupId);
      _membersById = {for (final u in members) u.id: u};

      _messages = await DatabaseService.getByGroup(_groupId);
      _typingUserIds = await DatabaseService.getTypingUserIds(
        groupId: _groupId,
        excludeUserId: _currentUser.id,
      );
      _error = null;
      notifyListeners();
    } catch (_) {
      _error = 'Impossible de charger la discussion.';
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> refreshNow() async => _refreshAll();

  void _startRealtimeListeners() {
    _messagesSub?.cancel();
    _membersSub?.cancel();
    _typingSub?.cancel();

    _messagesSub = DatabaseService.watchMessagesByGroup(_groupId).listen(
      (messages) {
        _messages = messages;
        _error = null;
        notifyListeners();
      },
      onError: (_) {
        _error = 'Impossible de charger la discussion.';
        notifyListeners();
      },
    );

    _membersSub = DatabaseService.watchUsersByGroup(_groupId).listen(
      (members) {
        _membersById = {for (final u in members) u.id: u};
        notifyListeners();
      },
      onError: (_) {
        _error = 'Impossible de charger les membres du groupe.';
        notifyListeners();
      },
    );

    _typingSub = DatabaseService
        .watchTypingUserIds(groupId: _groupId, excludeUserId: _currentUser.id)
        .listen(
      (typingUserIds) {
        _typingUserIds = typingUserIds;
        notifyListeners();
      },
      onError: (_) {
        _typingUserIds = [];
        notifyListeners();
      },
    );
  }

  Future<void> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final message = Message(
      id: const Uuid().v4(),
      groupId: _groupId,
      userId: _currentUser.id,
      text: clean,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await DatabaseService.insertMessage(message);
      await setTyping(false);
    } catch (_) {
      _error = 'Echec de l\'envoi du message.';
      notifyListeners();
    }
  }

  Future<void> onInputChanged(String text) async {
    final hasText = text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      await setTyping(hasText);
    }

    _typingDebounce?.cancel();
    if (hasText) {
      _typingDebounce = Timer(
        const Duration(seconds: 2),
        () => setTyping(false),
      );
    }
  }

  Future<void> setTyping(bool value) async {
    _isTyping = value;
    await DatabaseService.setTypingStatus(
      groupId: _groupId,
      userId: _currentUser.id,
      isTyping: value,
    );
  }

  bool isMine(Message m) => m.userId == _currentUser.id;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _messagesSub?.cancel();
    _membersSub?.cancel();
    _typingSub?.cancel();
    DatabaseService.clearTypingStatus(
      groupId: _groupId,
      userId: _currentUser.id,
    );
    super.dispose();
  }
}