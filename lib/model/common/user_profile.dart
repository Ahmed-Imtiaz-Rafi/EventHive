/// The logged-in user's profile, one row of `users` with the department
/// name from `departments`.
class UserProfile {
  final String username;
  final String email;
  final String? phone;
  final String? studentId;
  final int? departmentId;
  final String? departmentName;

  /// Link to the profile picture in the public `avatars` bucket. Null
  /// when the user has not set one.
  final String? avatarUrl;

  const UserProfile({
    required this.username,
    required this.email,
    this.phone,
    this.studentId,
    this.departmentId,
    this.departmentName,
    this.avatarUrl,
  });

  /// True when the profile has what registering requires: a student ID
  /// and a department (checked again by the database on every
  /// registration).
  bool get isComplete =>
      (studentId?.trim().isNotEmpty ?? false) && departmentId != null;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final department = map['departments'] as Map<String, dynamic>?;
    return UserProfile(
      username: map['username'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      studentId: map['student_id'] as String?,
      departmentId: map['department_id'] as int?,
      departmentName: department?['department_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}