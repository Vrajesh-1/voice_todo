import 'package:hive/hive.dart';
import 'todo.dart';

part 'todo_entity.g.dart';

@HiveType(typeId: 1)
class TodoEntity extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String? description;
  @HiveField(3)
  bool isCompleted;
  @HiveField(4)
  DateTime? createdAt;
  @HiveField(5)
  DateTime? updatedAt;

  TodoEntity({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });
}

// Conversion methods between Todo and TodoEntity
extension TodoEntityMapper on TodoEntity {
  Todo toTodo() => Todo(
        id: id,
        title: title,
        description: description,
        isCompleted: isCompleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension TodoMapper on Todo {
  TodoEntity toEntity() => TodoEntity(
        id: id,
        title: title,
        description: description,
        isCompleted: isCompleted,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
