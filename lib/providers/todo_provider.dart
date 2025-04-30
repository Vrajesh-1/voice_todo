import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/todo.dart';
import '../models/todo_entity.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

final todoBoxProvider = Provider<Box>((ref) =>
  kIsWeb ? Hive.box<Map>('todos') : Hive.box<TodoEntity>('todos'));

class TodoListNotifier extends StateNotifier<List<Todo>> {
  final Box box;
  TodoListNotifier(this.box) : super(_loadTodos(box));

  static List<Todo> _loadTodos(Box box) {
    if (kIsWeb) {
      return box.values.map((e) => Todo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } else {
      return box.values.map((e) => (e as TodoEntity).toTodo()).toList();
    }
  }

  void addTodo(String title, {String? description}) {
    final todo = Todo(
      id: const Uuid().v4(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    if (kIsWeb) {
      box.put(todo.id, todo.toJson());
    } else {
      box.put(todo.id, todo.toEntity());
    }
    state = _loadTodos(box);
  }

  void updateTodo(Todo todo, {String? title, String? description, bool? isCompleted}) {
    final updated = todo.copyWith(
      title: title ?? todo.title,
      description: description ?? todo.description,
      isCompleted: isCompleted ?? todo.isCompleted,
      updatedAt: DateTime.now(),
    );
    if (kIsWeb) {
      box.put(updated.id, updated.toJson());
    } else {
      box.put(updated.id, updated.toEntity());
    }
    state = _loadTodos(box);
  }

  void deleteTodo(String id) {
    box.delete(id);
    state = _loadTodos(box);
  }

  void toggleComplete(Todo todo) {
    updateTodo(todo, isCompleted: !todo.isCompleted);
  }

  void refresh() {
    state = _loadTodos(box);
  }
}

final todoListProvider = StateNotifierProvider<TodoListNotifier, List<Todo>>((ref) {
  final box = ref.watch(todoBoxProvider);
  return TodoListNotifier(box);
});
