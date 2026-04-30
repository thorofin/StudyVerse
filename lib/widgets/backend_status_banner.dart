// Used inside AIAssistantScreen, auto-retries every 5 seconds

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class BackendStatusBanner extends StatefulWidget {
  final VoidCallback onReady;
  const BackendStatusBanner({super.key, required this.onReady});

  @override
  State<BackendStatusBanner> createState() => _BackendStatusBannerState();
}

class _BackendStatusBannerState extends State<BackendStatusBanner> {
  final _ai = AIService();
  Timer? _timer;
  bool _checking = false;
  int  _attempt  = 0;

  static const _kPurple = Color(0xFF6C63FF);
  static const _kAmber  = Color(0xFFFFB300);
  static const _kRed    = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _check(); // immediate first check
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() { _checking = true; _attempt++; });
    final ready = await AIService.isReady();
    if (!mounted) return;
    if (ready) {
      _timer?.cancel();
      widget.onReady();
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _kAmber, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI backend not running',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_checking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kAmber),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Run this one command on your PC to start everything:',
            style: TextStyle(color: Color(0xFF757575), fontSize: 12),
          ),
          const SizedBox(height: 8),
          // Windows command
          _CodeBlock(
            label: 'Windows',
            icon: Icons.computer,
            code: 'start_dev3.bat',
          ),
          const SizedBox(height: 6),
          // Mac/Linux command
          _CodeBlock(
            label: 'Mac / Linux',
            icon: Icons.terminal,
            code: './start_dev3.sh',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.sync, color: _kAmber, size: 13),
              const SizedBox(width: 4),
              Text(
                'Retrying... (attempt $_attempt)',
                style: const TextStyle(
                    color: Color(0xFF757575), fontSize: 11),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _check,
                child: const Text(
                  'Retry now',
                  style: TextStyle(
                    color: _kPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final String code;
  const _CodeBlock({required this.label, required this.icon, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Expanded(
            child: Text(
              code,
              style: const TextStyle(
                color: Color(0xFF69F0AE),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}