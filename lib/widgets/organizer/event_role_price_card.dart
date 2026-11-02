import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:event_hive/core/theme/app_theme.dart';

/// Simple model for a pricing role.
/// Later this maps to the event_role_price table:
///   event_id, role_name, price
class EventRole {
  String name;
  double price;
  EventRole({required this.name, required this.price});
}

/// Collapsible card that shows the list of pricing roles.
/// The parent screen owns the roles list and passes it down.
/// All add/edit/delete actions call back to the parent via callbacks.
class EventRolePriceCard extends StatefulWidget {
  final List<EventRole> roles;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  const EventRolePriceCard({
    super.key,
    required this.roles,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<EventRolePriceCard> createState() => _EventRolePriceCardState();
}

class _EventRolePriceCardState extends State<EventRolePriceCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 16, color: kNavy),
                  const SizedBox(width: 6),
                  const Text(
                    'Pricing (Roles)',
                    style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Info tooltip icon
                  const Icon(Icons.info_outline, size: 16, color: kTextSub),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kNavy,
                  ),
                ],
              ),
            ),
          ),

          // ── Role list + add button
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // One row per role
                  ...List.generate(widget.roles.length, (i) {
                    final role = widget.roles[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              role.name,
                              style: const TextStyle(
                                fontSize: 14,
                                color: kTextMain,
                              ),
                            ),
                          ),
                          Text(
                            role.price == role.price.truncateToDouble()
                                ? role.price.toInt().toString()
                                : role.price.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: kTextMain,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Edit button
                          GestureDetector(
                            onTap: () => widget.onEdit(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: kTextSub,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Delete button
                          GestureDetector(
                            onTap: () => widget.onDelete(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  // Add Role button — aligned to the right like the design
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.add, size: 16, color: kNavy),
                      label: const Text(
                        'Add Role',
                        style: TextStyle(color: kNavy, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kNavy),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog for adding or editing a role.
// Returns the entered name and price, or null if the user cancelled.
// ─────────────────────────────────────────────────────────────────────────────
Future<EventRole?> showRoleDialog(
    BuildContext context, {
      EventRole? existing, // pass existing role when editing
    }) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final priceCtrl = TextEditingController(
    text: existing != null ? existing.price.toString() : '',
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<EventRole>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        existing == null ? 'Add Role' : 'Edit Role',
        style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: _dialogInputDecoration('Role name (e.g. Participant)'),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Role name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: _dialogInputDecoration('Price (e.g. 500)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Price is required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed < 0) return 'Enter a valid price';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: kTextSub)),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(
                ctx,
                EventRole(
                  name: nameCtrl.text.trim(),
                  price: double.parse(priceCtrl.text.trim()),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            existing == null ? 'Add' : 'Save',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

InputDecoration _dialogInputDecoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: kTextSub, fontSize: 13),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: kNavy, width: 1.5),
  ),
);
