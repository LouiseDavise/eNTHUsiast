import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class EventPrioritizationService {
  WebSocketChannel? _channel;

  Future<void> connectAndAnalyze() async {
    // Create a Completer to manually control when this Future is done
    final completer = Completer<void>();
    // 1. Handle platform routing for the WebSocket
    String url;
    if (kIsWeb) {
      url = 'ws://127.0.0.1:18789';
    } else if (Platform.isAndroid) {
      url = 'ws://10.0.2.2:18789';
    } else {
      url = 'ws://localhost:18789';
    }

    _channel = WebSocketChannel.connect(Uri.parse(url));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("Error: User not logged in.");
      return;
    }

    // 2. Send the handshake to kick off the agent's flow
    _channel!.sink.add(jsonEncode({
      'type': 'init_flow',
      'uid': uid
    }));

    // 3. Listen to the Agent's thoughts and final response
    _channel!.stream.listen((message) {
      final data = jsonDecode(message);

      if (data['type'] == 'debug_log') {
        print("🤖 Agent Thought: ${data['text']}");
      } 
      else if (data['type'] == 'status') {
        print("⚙️ Agent Status: ${data['text']}");
      }
      else if (data['type'] == 'final_response') {
        // When the agent finishes, pass the raw JSON to Firebase
        _saveToFirestore(data['text'], uid);
        
        // Optionally close the connection once done
        _channel!.sink.close(); 

        if (!completer.isCompleted) completer.complete();
      }
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    }, onError: (error) {
      print("WebSocket Error: $error");
      if (!completer.isCompleted) completer.complete();
    });
    
    return completer.future;
  }

  // 4. Parse the LLM's JSON and write it to Firestore
  Future<void> _saveToFirestore(String rawJson, String uid) async {
    try {
      final dynamic decodedData = jsonDecode(rawJson);
      
      final List<dynamic> llmResults = decodedData is List ? decodedData : [decodedData];

      int savedCount = 0;

      for (var llmResult in llmResults) {
        // Only skip explicit sentinel/error entries — never skip by score alone,
        // because valid Todos are intentionally saved with priorityScore = 0.
        final String title = llmResult['title']?.toString() ?? '';
        if (title == 'System Error' || title == 'No New Tasks' || title.isEmpty) {
          print("ℹ️ Ignoring fallback JSON: $title");
          continue; 
        }

        final String taskType = llmResult['type']?.toString().toLowerCase() ?? 'todo';
        // Todos always get 0; everything else uses the LLM score.
        // .toInt() is a safety net: if the LLM returns a double (e.g. 49.5) despite
        // our prompt instructions, we ceil it here so Firestore gets a clean int.
        final num rawScore = taskType == 'todo' ? 0 : (llmResult['priorityScore'] ?? 0);
        final int priorityScore = rawScore.ceil();

        // --- DYNAMIC DEADLINE + TIME PARSING ---
        DateTime parsedDueDate;
        String parsedTime = '23:59'; // fallback if no time in deadline
        try {
          if (llmResult['deadline'] != null) {
            parsedDueDate = DateTime.parse(llmResult['deadline']);
            // Only use the extracted time if it's not midnight (i.e. the LLM
            // actually specified a time rather than defaulting to T00:00:00).
            final bool hasExplicitTime =
                parsedDueDate.hour != 0 || parsedDueDate.minute != 0;
            if (hasExplicitTime) {
              parsedTime =
                  '${parsedDueDate.hour.toString().padLeft(2, '0')}:${parsedDueDate.minute.toString().padLeft(2, '0')}';
            }
          } else {
            parsedDueDate = DateTime.now().add(const Duration(days: 3));
          }
        } catch (e) {
          print("⚠️ Warning: Could not parse LLM deadline string, using fallback.");
          parsedDueDate = DateTime.now().add(const Duration(days: 3));
        }
        // ----------------------------------------

        final String taskId = DateTime.now().microsecondsSinceEpoch.toString();

        await FirebaseFirestore.instance
            .collection('ccxpUsers')
            .doc(uid)
            .collection('upcoming')
            .doc(taskId)
            .set({
              'id': taskId,
              'title': title,
              'summary': llmResult['summary'] ?? '',
              'progress': 0,
              'priorityScore': priorityScore,
              
              'type': taskType,
              'code': llmResult['courseCode'] ?? 'AI_GEN',
              
              'dueDate': Timestamp.fromDate(parsedDueDate),
              'time': parsedTime,
              'location': 'Online',
              'subtasks': <String>[],
              'status': 'Incomplete',
              'markCompleted': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
        savedCount++;
      }
      print("✅ Successfully saved $savedCount real LLM tasks to Firestore!");
    } catch (e) {
      print("❌ Failed to parse or save JSON: $e");
    }
  }
}