class AppUser {
  final String id, name, username, role, siteId;
  final String? password;

  const AppUser({
    required this.id, required this.name, required this.username,
    required this.role, this.siteId = '', this.password,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'username': username, 'role': role, 'siteId': siteId, 'password': password,
  };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] ?? '', name: j['name'] ?? '', username: j['username'] ?? '',
    role: j['role'] ?? '', siteId: j['siteId'] ?? '', password: j['password'],
  );
}
