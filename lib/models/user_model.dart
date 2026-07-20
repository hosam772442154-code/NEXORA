class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String uniId;
  final String role;
  final String cardUrl;
  final String status;
  final String banReason;

  const UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.uniId,
    required this.role,
    this.cardUrl = '',
    this.status = 'pending',
    this.banReason = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      uniId: json['uniId'] as String? ?? '',
      role: json['role'] as String? ?? 'student',
      cardUrl: json['cardUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      banReason: json['banReason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'uniId': uniId,
      'role': role,
      'cardUrl': cardUrl,
      'status': status,
      'banReason': banReason,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? uniId,
    String? role,
    String? cardUrl,
    String? status,
    String? banReason,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      uniId: uniId ?? this.uniId,
      role: role ?? this.role,
      cardUrl: cardUrl ?? this.cardUrl,
      status: status ?? this.status,
      banReason: banReason ?? this.banReason,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get isDoctor => role == 'doctor';
  bool get isRepresentative => role == 'representative';
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isBanned => status == 'banned';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, phone: $phone, '
        'uniId: $uniId, role: $role, status: $status)';
  }
}
