// lib/services/event_prioritization_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Structured data class representing the prioritized event outputted by the AI
class PrioritizedEvent {
  final int priorityScore;
  final String title;
  final String summary;
  final String deadlineStatus;

  PrioritizedEvent({
    required this.priorityScore,
    required this.title,
    required this.summary,
    required this.deadlineStatus,
  });
}

class EventPrioritizationService {
  WebSocketChannel? _channel;
  final Function(String) onDebugLog;
  final Function(PrioritizedEvent) onEventProcessed;

  EventPrioritizationService({
    required this.onDebugLog,
    required this.onEventProcessed,
  });

  void connect() {
    final String url = kIsWeb ? 'ws://127.0.0.1:18789' : 'ws://10.0.2.2:18789';
    _channel = WebSocketChannel.connect(Uri.parse(url));

    // Send a handshake telling the backend who we are
    _sendJson({'type': 'init_flow', 'flow': 'gmail_prioritization'});

    _channel!.stream.listen((message) {
      final payload = jsonDecode(message);
      
      if (payload['type'] == 'debug_log') {
        onDebugLog(payload['text']);
      } else if (payload['type'] == 'final_response') {
        _parseResponseToPayload(payload['text']);
      }
    });
  }

  void _parseResponseToPayload(String aiText) {
    try {
      // Extract Priority (e.g., "Resolution: Priority 100")
      final scoreMatch = RegExp(r'Priority\s*(\d+)').firstMatch(aiText);
      int score = scoreMatch != null ? int.parse(scoreMatch.group(1)!) : 50;

      // Extract subject/title line
      final titleMatch = RegExp(r'Resolution:\s*Priority\s*\d+\.\s*([^.]+)\.').firstMatch(aiText);
      String title = titleMatch != null ? titleMatch.group(1)!.trim() : "New Academic Event";

      final processedEvent = PrioritizedEvent(
        priorityScore: score,
        title: title,
        summary: aiText.replaceAll(RegExp(r'Resolution:\s*'), ''),
        deadlineStatus: aiText.contains('tomorrow') ? 'Urgent' : 'Normal',
      );

      onEventProcessed(processedEvent);
    } catch (e) {
      print("⚠️ Error parsing LLM text string into concrete Dart Payload: $e");
    }
  }

  void _sendJson(Map<String, dynamic> data) => _channel?.sink.add(jsonEncode(data));
  void disconnect() => _channel?.sink.close();
}