class User {
  final String id;
  final String name;
  final bool isLocal; // true for the person using the app, false for others
  final String? upiId;

  User({
    required this.id,
    required this.name,
    this.isLocal = false,
    this.upiId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': isLocal ? name.replaceAll(' (You)', '') : name,
      'is_local': isLocal ? 1 : 0,
      'upi_id': upiId,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final isLocal = map['is_local'] == 1;
    String userName = map['name'];
    if (isLocal && !userName.endsWith(' (You)')) {
      userName = '$userName (You)';
    }
    
    return User(
      id: map['id'],
      name: userName,
      isLocal: isLocal,
      upiId: map['upi_id'],
    );
  }
}
