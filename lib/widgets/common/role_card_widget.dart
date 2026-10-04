import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum UserRole { participant, organizer }

extension UserRoleX on UserRole {
  String get label =>
      this == UserRole.participant ? 'Participant' : 'Organizer';
}

/// Simple pill-style role toggle chip
class RoleChip extends StatelessWidget {
  const RoleChip({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kAmber : kSurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? kAmber : kBorder, width: 1.5),
        ),
        child: Text(
          role.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kTextSub,
          ),
        ),
      ),
    );
  }
}
