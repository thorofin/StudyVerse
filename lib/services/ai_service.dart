// HTTP client talking to the local Flask + Ollama (Mistral) backend.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class AIService {
  static const String _base = 'http://10.0.2.2:5000/api';

  // Upload PDF
  static Future<Map<String, dynamic>> uploadPdf(
      File file, String resourceId) async {
    final uri     = Uri.parse('$_base/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['resource_id'] = resourceId;
    request.files.add(await http.MultipartFile.fromPath(
      'file', file.path,
      contentType: MediaType('application', 'pdf'),
    ));
    final streamed  = await request.send().timeout(const Duration(seconds: 60));
    final response  = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw AIServiceException('Upload failed: ${response.body}');
  }

  // Add URL
  static Future<Map<String, dynamic>> addUrl(
      String url, String resourceId) async {
    final response = await http
        .post(
      Uri.parse('$_base/add_url'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'url': url, 'resource_id': resourceId}),
    )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw AIServiceException('URL extraction failed: ${response.body}');
  }

  // Ask (RAG)
  static Future<String> ask(
      String question, {
        List<String> resourceIds = const [],
      }) async {
    final response = await http
        .post(
      Uri.parse('$_base/ask'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'question':     question,
        'resource_ids': resourceIds,
      }),
    )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['answer'] as String? ?? 'No answer returned.';
    }
    throw AIServiceException('Ask failed: ${response.body}');
  }

  // Summarize
  static Future<String> summarize(String resourceId) async {
    final response = await http
        .post(
      Uri.parse('$_base/summarize'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'resource_id': resourceId}),
    )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['summary'] as String? ?? 'No summary returned.';
    }
    throw AIServiceException('Summarize failed: ${response.body}');
  }

  // Generate quiz
  static Future<String> generateQuiz(String resourceId,
      {int questionCount = 5}) async {
    final response = await http
        .post(
      Uri.parse('$_base/quiz'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'resource_id':    resourceId,
        'question_count': questionCount,
      }),
    )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['quiz'] as String? ?? 'No quiz generated.';
    }
    throw AIServiceException('Quiz generation failed: ${response.body}');
  }

  // Explain topic
  static Future<String> explain(String resourceId, String topic) async {
    final response = await http
        .post(
      Uri.parse('$_base/explain'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'resource_id': resourceId, 'topic': topic}),
    )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['explanation'] as String? ?? 'No explanation returned.';
    }
    throw AIServiceException('Explain failed: ${response.body}');
  }

  // Health check
  static Future<bool> isReady() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception("Cannot open URL");
    }
  }

  static Future<void> openPdf(String filePath) async {
    await OpenFile.open(filePath);
  }

  static Future<void> openPdfUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  @override
  String toString() => 'AIServiceException: $message';
}