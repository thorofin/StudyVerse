
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/resource.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

enum ResourceViewState { idle, loading, error }

class ResourceViewModel extends ChangeNotifier {
  final Group _group;

  ResourceViewModel({required Group group}) : _group = group {
    _init();
  }

  // State
  ResourceViewState _state   = ResourceViewState.idle;
  String?           _error;
  List<Resource>    _resources = [];
  List<AIChatMessage> _messages = [];
  bool              _backendReady = false;
  String?           _activeResourceId;

  // Getters
  Group               get group           => _group;
  ResourceViewState   get state           => _state;
  String?             get error           => _error;
  List<Resource>      get resources       => List.unmodifiable(_resources);
  List<AIChatMessage> get messages        => List.unmodifiable(_messages);
  bool                get backendReady    => _backendReady;
  String?             get activeResourceId => _activeResourceId;
  bool                get isLoading       => _state == ResourceViewState.loading;

  List<Resource> get pdfResources =>
      _resources.where((r) => r.type == ResourceType.pdf).toList();
  List<Resource> get urlResources =>
      _resources.where((r) => r.type == ResourceType.url).toList();

  // Init
  Future<void> _init() async {
    _setState(ResourceViewState.loading);
    await _loadResources();
    _backendReady = await AIService.isReady();
    _setState(ResourceViewState.idle);
  }

  Future<void> loadResources() async {
    _setState(ResourceViewState.loading);
    await _loadResources();
    _setState(ResourceViewState.idle);
  }

  Future<void> _loadResources() async {
    _resources = await DatabaseService.getResources(_group.id);
  }

  void setActiveResource(String? id) {
    _activeResourceId = id;
    notifyListeners();
  }

  // Upload PDF → index in backend, save to Firestore
  Future<void> uploadPdf(File file) async {
    _setState(ResourceViewState.loading);
    try {
      final id = const Uuid().v4();
      final resource = Resource(
        id:        id,
        groupId:   _group.id,
        title:     file.path.split('/').last,
        url:       file.path, // replaced by Storage URL in production
        type:      ResourceType.pdf,
        sizeBytes: await file.length(),
      );

      final result = await AIService.uploadPdf(file, id);
      final withText = resource.copyWith(
        extractedText: result['extracted_text'] as String?,
      );

      await DatabaseService.insertResource(withText);
      await _loadResources();

      _addSystemMessage(
        ' **${resource.title}** uploaded and indexed. Ask me anything about it!',
      );
      _setState(ResourceViewState.idle);
    } catch (e) {
      _setError('Failed to upload PDF: $e');
    }
  }

  // Add URL → index in backend, save to Firestore
  Future<void> addUrl(String url) async {
    _setState(ResourceViewState.loading);
    try {
      final id = const Uuid().v4();
      final resource = Resource(
        id:      id,
        groupId: _group.id,
        title:   _titleFromUrl(url),
        url:     url,
        type:    ResourceType.url,
      );

      final result = await AIService.addUrl(url, id);
      final withText = resource.copyWith(
        extractedText: result['extracted_text'] as String?,
      );

      await DatabaseService.insertResource(withText);
      await _loadResources();

      _addSystemMessage(
        ' **${resource.title}** added and indexed. Ask me anything about it!',
      );
      _setState(ResourceViewState.idle);
    } catch (e) {
      _setError('Failed to add URL: $e');
    }
  }

  // Delete resource
  Future<void> deleteResource(String id) async {
    await DatabaseService.deleteResource(id);
    if (_activeResourceId == id) _activeResourceId = null;
    await _loadResources();
    notifyListeners();
  }

  // Ask question (RAG)
  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    final userMsg = AIChatMessage(
      id:        _uid(),
      content:   question.trim(),
      isUser:    true,
      timestamp: DateTime.now(),
    );
    final loadingMsg = AIChatMessage(
      id:        _uid(),
      content:   '',
      isUser:    false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
    _messages = [..._messages, userMsg, loadingMsg];
    notifyListeners();

    try {
      final ids = _activeResourceId != null
          ? [_activeResourceId!]
          : _resources.map((r) => r.id).toList();
      final answer = await AIService.ask(question, resourceIds: ids);
      _replaceLoading(loadingMsg.id, answer);
    } catch (e) {
      _replaceLoading(loadingMsg.id, '⚠️ Error: $e');
    }
  }

  // Summarize
  Future<void> summarizeResource(String resourceId) async {
    final r = _resources.firstWhere((x) => x.id == resourceId);
    _addSystemMessage('📋 Summarizing **${r.title}**…');
    final loadingMsg = AIChatMessage(
      id: _uid(), content: '', isUser: false,
      timestamp: DateTime.now(), isLoading: true,
    );
    _messages = [..._messages, loadingMsg];
    notifyListeners();
    try {
      final summary = await AIService.summarize(resourceId);
      _replaceLoading(loadingMsg.id, '**Summary — ${r.title}**\n\n$summary');
    } catch (e) {
      _replaceLoading(loadingMsg.id, '⚠️ Failed to summarize: $e');
    }
  }

  // Generate quiz
  Future<void> generateQuiz(String resourceId) async {
    final r = _resources.firstWhere((x) => x.id == resourceId);
    _addSystemMessage('🧠 Generating quiz from **${r.title}**…');
    final loadingMsg = AIChatMessage(
      id: _uid(), content: '', isUser: false,
      timestamp: DateTime.now(), isLoading: true,
    );
    _messages = [..._messages, loadingMsg];
    notifyListeners();
    try {
      final quiz = await AIService.generateQuiz(resourceId);
      _replaceLoading(loadingMsg.id, '**Quiz — ${r.title}**\n\n$quiz');
    } catch (e) {
      _replaceLoading(loadingMsg.id, '⚠️ Failed to generate quiz: $e');
    }
  }

  // Quick actions (uses active or first resource)
  Future<void> summarizeActive() async {
    if (_resources.isEmpty) {
      _addSystemMessage('No resources yet. Upload a PDF or add a URL first!');
      return;
    }
    await summarizeResource(_activeResourceId ?? _resources.first.id);
  }

  Future<void> quizActive() async {
    if (_resources.isEmpty) {
      _addSystemMessage('No resources yet. Upload a PDF or add a URL first!');
      return;
    }
    await generateQuiz(_activeResourceId ?? _resources.first.id);
  }

  void clearChat() {
    _messages = [];
    notifyListeners();
  }

  // Private helpers
  void _setState(ResourceViewState s) {
    _state = s;
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _state = ResourceViewState.error;
    _error = msg;
    notifyListeners();
  }

  void _addSystemMessage(String content) {
    _messages = [
      ..._messages,
      AIChatMessage(
        id: _uid(), content: content,
        isUser: false, timestamp: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  Future<void> openResource(Resource resource) async {
    try {
      if (resource.type == ResourceType.pdf) {
        // If it's a local file path (common during development)
        if (resource.url.startsWith('/') || resource.url.contains('cache')) {
          await AIService.openPdf(resource.url);
        } else {
          // If it's a remote URL
          await AIService.openPdfUrl(resource.url);
        }
      } else {
        // It's a standard website URL
        await AIService.openUrl(resource.url);
      }
    } catch (e) {
      _setError('Could not open resource: $e');
    }
  }

  void _replaceLoading(String id, String content) {
    _messages = _messages.map((m) {
      if (m.id == id) return m.copyWith(content: content, isLoading: false);
      return m;
    }).toList();
    notifyListeners();
  }

  String _uid() =>
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  String _titleFromUrl(String url) {
    try {
      return Uri.parse(url).host.replaceAll('www.', '');
    } catch (_) {
      return url;
    }
  }
}