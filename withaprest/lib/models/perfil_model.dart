class ProfileModel {
  final String id; // uuid (auth.users.id)
  final String rol; // 'admin' | 'usuario'
  final String? nombre; // puede venir null
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.rol,
    this.nombre,
    this.createdAt,
  });

  bool get esAdmin => rol == 'admin';

  String get nombreSeguro =>
      (nombre == null || nombre!.trim().isEmpty) ? 'Usuario' : nombre!.trim();

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: (map['id'] ?? '') as String,
      rol: (map['rol'] ?? 'usuario') as String,
      nombre: map['nombre'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rol': rol,
      'nombre': nombre,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? rol,
    String? nombre,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      rol: rol ?? this.rol,
      nombre: nombre ?? this.nombre,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
