import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../models/message.dart';
import '../viewmodels/chat_view_model.dart';
import '../viewmodels/group_view_model.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  ChatViewModel? _vm;
  Group? _group;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final group = ModalRoute.of(context)?.settings.arguments as Group?;
    final user = context.read<GroupViewModel>().currentUser;

    if (group != null && user != null) {
      _group = group;
      _vm = ChatViewModel(groupId: group.id, currentUser: user)..init();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _send(ChatViewModel vm) async {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;

    _inputCtrl.clear();
    await vm.sendMessage(text);

    if (_scrollCtrl.hasClients) {
      await _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _vm == null || _group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(
          child: Text('Impossible d\'ouvrir ce chat.'),
        ),
      );
    }

    return ChangeNotifierProvider<ChatViewModel>.value(
      value: _vm!,
      child: Consumer<ChatViewModel>(
        builder: (context, vm, _) {
          final messages = vm.messages;
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            body: SafeArea(
              child: Column(
                children: [
                  _ChatHeader(group: _group!),
                  if (vm.error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFC8BE)),
                      ),
                      child: Text(
                        vm.error!,
                        style: const TextStyle(
                          color: Color(0xFF8A2A1E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (vm.loading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: vm.refreshNow,
                        child: messages.isEmpty
                            ? const _EmptyChatState()
                            : ListView.builder(
                                controller: _scrollCtrl,
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final m = messages[i];
                                  final isMine = vm.isMine(m);
                                  final sender = vm.senderNameOf(m.userId);
                                  return _MessageBubble(
                                    message: m,
                                    senderName: sender,
                                    isMine: isMine,
                                  );
                                },
                              ),
                      ),
                    ),
                  _TypingBar(text: vm.getTypingText()),
                  _Composer(
                    controller: _inputCtrl,
                    onChanged: vm.onInputChanged,
                    onSend: () => _send(vm),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final Group group;

  const _ChatHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              group.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Messagerie du groupe',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String senderName;
  final bool isMine;

  const _MessageBubble({
    required this.message,
    required this.senderName,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 2),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0xFFEAE7FF),
                  child: Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : 'M',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (!isMine) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMine
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
                          )
                        : null,
                    color: isMine ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMine ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 3,
              left: isMine ? 0 : 34,
              right: isMine ? 6 : 0,
            ),
            child: Text(
              message.getFormattedTime(),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBar extends StatelessWidget {
  final String text;

  const _TypingBar({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Ecrire un message... ',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C59FF)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.mark_chat_unread_outlined, size: 56, color: Color(0xFF6C63FF)),
        SizedBox(height: 12),
        Center(
          child: Text(
            'Aucun message pour le moment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Soyez le premier a ecrire dans ce groupe.',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }
}