import 'dart:async';
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
import 'package:flutter_tts/flutter_tts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers/auth_provider.dart';

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
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(authProvider);
        final user = userAsync.asData?.value;
        return MaterialApp(
          title: 'Voice To-Do',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: user == null ? const LoginPage() : TodoListScreen(user: user),
        );
      },
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  String? _error;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() {
        _error = 'Google sign-in failed:\n'+e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = 'Email sign-in failed:\n'+e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _registerWithEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = 'Registration failed:\n'+e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice To-Do'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign in to your account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const CircularProgressIndicator(),
                if (!_loading) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signInWithEmail,
                      child: const Text('Sign In'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _registerWithEmail,
                      child: const Text('Register'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: _signInWithGoogle,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// UI for To-Do List

class TodoListScreen extends ConsumerStatefulWidget {
  final User? user;
  const TodoListScreen({super.key, required this.user});

  @override
  ConsumerState<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends ConsumerState<TodoListScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  final TextEditingController _controller = TextEditingController();
  bool _showCompletedOnly = false;
  final List<String> _offlineQueue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    _isOnline = (await connectivity.checkConnectivity()) != ConnectivityResult.none;
    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final nowOnline = result != ConnectivityResult.none;
      if (!_isOnline && nowOnline) {
        _processOfflineQueue();
      }
      setState(() {
        _isOnline = nowOnline;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _processOfflineQueue() async {
    final notifier = ref.read(todoListProvider(widget.user?.uid).notifier);
    for (final cmd in List<String>.from(_offlineQueue)) {
      final command = parseVoiceCommand(cmd);
      final todos = ref.read(todoListProvider(widget.user?.uid));
      if (command.intent == 'add' && command.target != null && command.target!.isNotEmpty) {
        notifier.addTodo(command.target!);
        await _speak('Task added from offline queue.');
      } else if (command.intent == 'complete' && command.target != null) {
        final match = todos.firstWhereOrNull((t) => t.title.toLowerCase() == command.target);
        if (match != null) {
          notifier.toggleComplete(match);
          await _speak('Task completed from offline queue.');
        }
      } else if (command.intent == 'delete' && command.target != null) {
        final match = todos.firstWhereOrNull((t) => t.title.toLowerCase() == command.target);
        if (match != null) {
          notifier.deleteTodo(match.id);
          await _speak('Task deleted from offline queue.');
        }
      }
      // Remove processed command
      _offlineQueue.remove(cmd);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> _listen() async {
    debugPrint('VOICE: _listen called. _isListening=$_isListening');
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      debugPrint('VOICE: Stopped listening.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stopped listening.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listening for task...')));
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('VOICE: Speech status: $status');
        if (status == 'notListening') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stopped listening.')));
        }
      },
      onError: (error) {
        debugPrint('VOICE: Speech error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech error: \n$error')),
        );
      },
    );
    debugPrint('VOICE: Speech available: $available');
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not supported or permission denied.')),
      );
      return;
    }
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (val) async {
        debugPrint('VOICE: onResult called. recognizedWords="${val.recognizedWords}" finalResult=${val.finalResult}');
        setState(() {
          _controller.text = val.recognizedWords;
        });
        final text = val.recognizedWords.trim();
        final uid = widget.user?.uid;
        if (val.finalResult && text.isNotEmpty && uid != null) {
          ref.read(todoListProvider(uid).notifier).addTodo(text);
          _controller.clear();
          await _speech.stop();
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task added: $text')),
          );
          debugPrint('VOICE: Task added: $text');
        } else if (val.finalResult && text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No speech recognized.')),
          );
          await _speech.stop();
          setState(() => _isListening = false);
          debugPrint('VOICE: No speech recognized.');
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
      cancelOnError: true,
      partialResults: false,
    );
    debugPrint('VOICE: Started listening.');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final todos = ref.watch(todoListProvider(user?.uid));
    final filteredTodos = _showCompletedOnly ? todos.where((t) => t.isCompleted).toList() : todos;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
          onPressed: () => ref.read(authServiceProvider).signOut(),
        ),
        title: const Text('Voice To-Do'),
        actions: [
          if (user != null)
            Row(
              children: [
                if (user.photoURL != null)
                  CircleAvatar(backgroundImage: NetworkImage(user.photoURL!)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(user.displayName ?? user.email ?? ''),
                ),
              ],
            ),
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
          if (!_isOnline && _offlineQueue.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.amber,
              padding: const EdgeInsets.all(8),
              child: const Text('You are offline. Commands will be queued.'),
            ),
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
                      final uid = user?.uid;
                      if (uid == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add tasks.')));
                        return;
                      }
                      if (value.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task cannot be empty.')));
                        return;
                      }
                      ref.read(todoListProvider(uid).notifier).addTodo(value.trim());
                      _controller.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final uid = user?.uid;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add tasks.')));
                      return;
                    }
                    if (_controller.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task cannot be empty.')));
                      return;
                    }
                    ref.read(todoListProvider(uid).notifier).addTodo(_controller.text.trim());
                    _controller.clear();
                  },
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: _isListening ? Colors.red : null,
                  tooltip: 'Speak task',
                  onPressed: () async {
                    final uid = user?.uid;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to add tasks.')));
                      return;
                    }
                    await _listen();
                    // After listening, if controller has text, add task
                    if (_controller.text.trim().isNotEmpty) {
                      ref.read(todoListProvider(uid).notifier).addTodo(_controller.text.trim());
                      _controller.clear();
                    }
                  },
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
                          onChanged: (_) => ref.read(todoListProvider(user?.uid).notifier).toggleComplete(todo),
                        ),
                        title: Text(
                          todo.title,
                          style: TextStyle(
                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => ref.read(todoListProvider(user?.uid).notifier).deleteTodo(todo.id),
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
