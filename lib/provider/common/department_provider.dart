import 'package:event_hive/model/common/department.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All departments, from the `departments` table, sorted by name. Used
/// by the profile's department picker.
final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  final rows = await Supabase.instance.client
      .from('departments')
      .select()
      .order('department_name', ascending: true);

  return (rows as List)
      .map((row) => Department.fromMap(row as Map<String, dynamic>))
      .toList();
});