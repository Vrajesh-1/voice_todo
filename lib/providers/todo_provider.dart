import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/todo.dart';
import '../models/todo_entity.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

final todoBoxProvider = Provider<Box>((ref) =>
  kIsWeb ? Hive.box<Map>('todos') : Hive.box<TodoEntity>('todos'));

class TodoListNotifier extends StateNotifier<List<Todo>> {
  final Box box;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  StreamSubscription? _firestoreSub;
  bool _syncing = false;
  String? _uid;

  TodoListNotifier(this.box, this._uid) : super(_loadTodos(box)) {
    _listenToFirestore();
  }

  static List<Todo> _loadTodos(Box box) {
    if (kIsWeb) {
      return box.values.map((e) => Todo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } else {
      return box.values.map((e) => (e as TodoEntity).toTodo()).toList();
    }
  }

  void _listenToFirestore() {
    _firestoreSub?.cancel();
    if (_uid == null) return;
    _firestoreSub = firestore.collection('users').doc(_uid).collection('todos').snapshots().listen((snapshot) {
      if (_syncing) return; // prevent feedback loop
      final todos = snapshot.docs.map((doc) => Todo.fromJson(doc.data() as Map<String, dynamic>)).toList();
      state = todos;
      // Also update local storage
      for (var todo in todos) {
        if (kIsWeb) {
          box.put(todo.id, todo.toJson());
        } else {
          box.put(todo.id, todo.toEntity());
        }
      }
    });
  }

  Future<void> addTodo(String title, {String? description}) async {
    if (_uid == null) return;
    final todo = Todo(
      id: const Uuid().v4(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _syncing = true;
    await firestore.collection('users').doc(_uid).collection('todos').doc(todo.id).set(todo.toJson());
    _syncing = false;
    if (kIsWeb) {
      box.put(todo.id, todo.toJson());
    } else {
      box.put(todo.id, todo.toEntity());
    }
    state = _loadTodos(box);
  }

  Future<void> updateTodo(Todo todo, {String? title, String? description, bool? isCompleted}) async {
    if (_uid == null) return;
    final updated = todo.copyWith(
      title: title ?? todo.title,
      description: description ?? todo.description,
      isCompleted: isCompleted ?? todo.isCompleted,
      updatedAt: DateTime.now(),
    );
    _syncing = true;
    await firestore.collection('users').doc(_uid).collection('todos').doc(updated.id).set(updated.toJson());
    _syncing = false;
    if (kIsWeb) {
      box.put(updated.id, updated.toJson());
    } else {
      box.put(updated.id, updated.toEntity());
    }
    state = _loadTodos(box);
  }

  Future<void> deleteTodo(String id) async {
    if (_uid == null) return;
    _syncing = true;
    await firestore.collection('users').doc(_uid).collection('todos').doc(id).delete();
    _syncing = false;
    box.delete(id);
    state = _loadTodos(box);
  }

  void toggleComplete(Todo todo) {
    updateTodo(todo, isCompleted: !todo.isCompleted);
  }

  void refresh() {
    state = _loadTodos(box);
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

final todoListProvider = StateNotifierProvider.family<TodoListNotifier, List<Todo>, String?>((ref, uid) {
  final box = ref.watch(todoBoxProvider);
  return TodoListNotifier(box, uid);
});
