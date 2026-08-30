import 'user.dart';

class ExpenseGroup {
  final String id;
  final String name;
  List<User> members; // Populated in-memory

  ExpenseGroup({
    required this.id,
    required this.name,
    this.members = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory ExpenseGroup.fromMap(Map<String, dynamic> map) {
    return ExpenseGroup(
      id: map['id'],
      name: map['name'],
    );
  }
}
