import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'models/todo_entity.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'providers/todo_provider.dart';
import 'models/todo.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:collection/collection.dart';

// --- Natural Language Command Parsing ---
class VoiceCommandResult {
  final String intent;
  final String? target;
  VoiceCommandResult(this.intent, this.target);
}

VoiceCommandResult parseVoiceCommand(String text) {
  final lower = text.toLowerCase().trim();
  if (lower.startsWith('add ')) {
    return VoiceCommandResult('add', lower.substring(4).trim());
  } else if (lower.startsWith('complete ')) {
    return VoiceCommandResult('complete', lower.substring(9).trim());
  } else if (lower.startsWith('delete ')) {
    return VoiceCommandResult('delete', lower.substring(7).trim());
  } else if (lower.contains('show completed')) {
    return VoiceCommandResult('show_completed', null);
  } else {
    // fallback: treat as add if not recognized
    return VoiceCommandResult('add', lower);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  if (!kIsWeb) {
    Hive.registerAdapter(TodoEntityAdapter());
    await Hive.openBox<TodoEntity>('todos');
  } else {
    await Hive.openBox<Map>('todos');
  }
  runApp(const ProviderScope(child: VoiceTodoApp()));
}

class VoiceTodoApp extends StatelessWidget {
  const VoiceTodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice To-Do',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TodoListScreen(),
    );
  }
}

// UI for To-Do List

class TodoListScreen extends ConsumerStatefulWidget {
  const TodoListScreen({super.key});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _controller = TextEditingController();
  bool _showCompletedOnly = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
            if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
              final command = parseVoiceCommand(val.recognizedWords.trim());
              final notifier = ref.read(todoListProvider.notifier);
              final todos = ref.read(todoListProvider);
              if (command.intent == 'add' && command.target != null && command.target!.isNotEmpty) {
                notifier.addTodo(command.target!);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task added.')));
              } else if (command.intent == 'complete' && command.target != null) {
                final match = todos.firstWhereOrNull((t) => t.title.toLowerCase() == command.target);
                if (match != null) {
                  notifier.toggleComplete(match);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task completed.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task not found.')));
                }
              } else if (command.intent == 'delete' && command.target != null) {
                final match = todos.firstWhereOrNull((t) => t.title.toLowerCase() == command.target);
                if (match != null) {
                  notifier.deleteTodo(match.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task deleted.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task not found.')));
                }
              } else if (command.intent == 'show_completed') {
                setState(() => _showCompletedOnly = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Showing completed tasks.')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sorry, command not recognized.')));
              }
              _controller.clear();
              _speech.stop();
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoListProvider);
    final filteredTodos = _showCompletedOnly ? todos.where((t) => t.isCompleted).toList() : todos;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice To-Do'),
        actions: [
          if (_showCompletedOnly)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Show all tasks',
              onPressed: () => setState(() => _showCompletedOnly = false),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Add a new task',
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        ref.read(todoListProvider.notifier).addTodo(value.trim());
                        _controller.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      ref.read(todoListProvider.notifier).addTodo(_controller.text.trim());
                      _controller.clear();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening ? Colors.red : null,
                  tooltip: 'Speak task',
                  onPressed: _listen,
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTodos.isEmpty
                ? const Center(child: Text('No tasks yet.'))
                : ListView.builder(
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, i) {
                      final todo = filteredTodos[i];
                      return ListTile(
                        leading: Checkbox(
                          value: todo.isCompleted,
                          onChanged: (_) => ref.read(todoListProvider.notifier).toggleComplete(todo),
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => ref.read(todoListProvider.notifier).deleteTodo(todo.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
