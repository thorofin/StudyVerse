
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/group.dart';
import '../models/resource.dart';
import '../viewmodels/resource_view_model.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  ResourceViewModel? _vm;
  bool _initialized = false;

  final _inputCtrl      = TextEditingController();
  final _scrollCtrl     = ScrollController();

  static const _bg       = Color(0xFFF5F5F5);
  static const _surface  = Colors.white;
  static const _primary  = Color(0xFF6750A4); // deepPurple seed
  static const _onPrimary = Colors.white;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final group = ModalRoute.of(context)!.settings.arguments as Group;
      _vm = ResourceViewModel(group: group);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // PDF picker
  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      await _vm!.uploadPdf(File(result.files.single.path!));
      _scrollToBottom();
    }
  }

  // URL dialog
  Future<void> _showAddUrlDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add URL Resource'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/article',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) async {
            Navigator.pop(ctx);
            if (ctrl.text.trim().isNotEmpty) {
              await _vm!.addUrl(ctrl.text.trim());
              _scrollToBottom();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isNotEmpty) {
                await _vm!.addUrl(ctrl.text.trim());
                _scrollToBottom();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await _vm!.askQuestion(text);
    _scrollToBottom();
  }

  Future<void> _showAttachSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttachSheet(
        onPdf: () { Navigator.pop(context); _pickPdf(); },
        onUrl: () { Navigator.pop(context); _showAddUrlDialog(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_vm == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return ChangeNotifierProvider<ResourceViewModel>.value(
      value: _vm!,
      child: Consumer<ResourceViewModel>(
        builder: (context, vm, _) {
          if (vm.messages.isNotEmpty) _scrollToBottom();
          return Scaffold(
            backgroundColor: _bg,
            appBar: _buildAppBar(vm),
            body: Column(
              children: [
                _buildQuickActions(vm),
                _buildResourceStrip(vm),
                Expanded(child: _buildChat(vm)),
                _buildInputBar(vm),
              ],
            ),
          );
        },
      ),
    );
  }

  // AppBar
  PreferredSizeWidget _buildAppBar(ResourceViewModel vm) {
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Assistant — ${vm.group.name}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _onPrimary,
            ),
          ),
          Row(
            children: [
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: vm.backendReady
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5252),
                ),
              ),
              Text(
                vm.backendReady ? 'Mistral · Ready' : 'Backend offline',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear chat',
          onPressed: vm.clearChat,
        ),
        if (vm.resources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${vm.resources.length}',
                style: const TextStyle(
                  color: _primary, fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  // Quick action buttons
  Widget _buildQuickActions(ResourceViewModel vm) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.picture_as_pdf,
            label: 'Upload PDF',
            color: const Color(0xFFE53935),
            onTap: _pickPdf,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.link,
            label: 'Add URL',
            color: const Color(0xFF1976D2),
            onTap: _showAddUrlDialog,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.summarize,
            label: 'Summarize',
            color: const Color(0xFFF57C00),
            onTap: vm.resources.isEmpty ? null : vm.summarizeActive,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.quiz,
            label: 'Quiz Me',
            color: _primary,
            onTap: vm.resources.isEmpty ? null : vm.quizActive,
          ),
        ],
      ),
    );
  }

  // Resource strip (horizontal scrollable cards)
  Widget _buildResourceStrip(ResourceViewModel vm) {
    if (vm.resources.isEmpty) {
      return Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: const [
              Icon(Icons.folder_open, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text(
                'No resources yet — upload a PDF or add a URL',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: _surface,
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        itemCount: vm.resources.length,
        itemBuilder: (_, i) => _ResourceCard(
          resource: vm.resources[i],
          isActive: vm.activeResourceId == vm.resources[i].id,
          onTap: () => vm.setActiveResource(
            vm.activeResourceId == vm.resources[i].id
                ? null
                : vm.resources[i].id,
          ),
          onDelete:    () => vm.deleteResource(vm.resources[i].id),
          onSummarize: () { vm.summarizeResource(vm.resources[i].id); _scrollToBottom(); },
          onQuiz:      () { vm.generateQuiz(vm.resources[i].id); _scrollToBottom(); },
          onView:      () => vm.openResource(vm.resources[i]),
        ),
      ),
    );
  }

  // Chat area
  Widget _buildChat(ResourceViewModel vm) {
    if (vm.messages.isEmpty) return _emptyState();
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: vm.messages.length,
      itemBuilder: (_, i) => _Bubble(msg: vm.messages[i]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 56, color: _primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'StudyVerse AI Assistant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Upload PDFs or add URLs, then ask questions,\nget summaries, or generate quizzes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              '📄 Summarize my PDF',
              '🧠 Generate a quiz',
              '❓ Explain key concepts',
            ].map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
          ),
        ],
      ),
    );
  }

  // Input bar
  Widget _buildInputBar(ResourceViewModel vm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      color: _surface,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // + button
            IconButton(
              onPressed: _showAttachSheet,
              icon: const Icon(Icons.add_circle_outline),
              color: _primary,
              tooltip: 'Add resource',
            ),
            // text field
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: vm.activeResourceId != null
                      ? 'Ask about selected resource…'
                      : 'Ask about your resources…',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // send
            FilledButton(
              onPressed: vm.isLoading ? null : _send,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(44, 44),
                shape: const CircleBorder(),
              ),
              child: vm.isLoading
                  ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}


// COMPONENT WIDGETS

// Quick action chip
class _ActionChip extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final Color     color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Resource card
class _ResourceCard extends StatelessWidget {
  final Resource     resource;
  final bool         isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSummarize;
  final VoidCallback onQuiz;
  final VoidCallback onView;

  const _ResourceCard({
    required this.resource,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onSummarize,
    required this.onQuiz,
    required this.onView,

  });

  @override
  Widget build(BuildContext context) {
    final isPdf  = resource.type == ResourceType.pdf;
    final color  = isPdf ? const Color(0xFFE53935) : const Color(0xFF1976D2);
    final icon   = isPdf ? Icons.picture_as_pdf : Icons.link;
    const primary = Color(0xFF6750A4);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? primary : Colors.grey.shade300,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    resource.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                Text(
                  resource.type.name.toUpperCase() +
                      (resource.displaySize.isNotEmpty
                          ? ' · ${resource.displaySize}'
                          : ''),
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(width: 6),
            _iconBtn(Icons.visibility_outlined, Colors.blueGrey, onView),
            _iconBtn(Icons.summarize_outlined, const Color(0xFFF57C00), onSummarize),
            _iconBtn(Icons.quiz_outlined, primary, onQuiz),
            _iconBtn(Icons.delete_outline, const Color(0xFFE53935), onDelete),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, color: color.withOpacity(0.8), size: 14),
        ),
      );
}

// Chat bubble
class _Bubble extends StatelessWidget {
  final AIChatMessage msg;
  const _Bubble({required this.msg});

  static const _primary = Color(0xFF6750A4);

  @override
  Widget build(BuildContext context) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomLeft:  Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(4),
            topRight:    Radius.circular(16),
            bottomLeft:  Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: msg.isLoading
            ? const _TypingIndicator()
            : Text(
          msg.content,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// Typing indicator
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
          final bounce = (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(Colors.grey.shade300,
                  const Color(0xFF6750A4), bounce),
            ),
          );
        }),
      ),
    );
  }
}

// Attach bottom sheet
class _AttachSheet extends StatelessWidget {
  final VoidCallback onPdf;
  final VoidCallback onUrl;
  const _AttachSheet({required this.onPdf, required this.onUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Resource',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFEBEE),
              child: Icon(Icons.picture_as_pdf, color: Color(0xFFE53935)),
            ),
            title: const Text('Upload PDF'),
            subtitle: const Text('Index a PDF for RAG-powered Q&A'),
            onTap: onPdf,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFFF5F5F5),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.link, color: Color(0xFF1976D2)),
            ),
            title: const Text('Add URL'),
            subtitle: const Text('Extract and index webpage content'),
            onTap: onUrl,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: const Color(0xFFF5F5F5),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}