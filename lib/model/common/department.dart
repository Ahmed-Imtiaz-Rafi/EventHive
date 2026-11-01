/// One academic department, a row of `departments`. Used by the profile
/// picker and, later, by event eligibility.
class Department {
  final int id;
  final String name;

  const Department({required this.id, required this.name});

  factory Department.fromMap(Map<String, dynamic> map) => Department(
    id: map['department_id'] as int,
    name: map['department_name'] as String,
  );
}