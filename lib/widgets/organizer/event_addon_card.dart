import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:event_hive/core/theme/app_theme.dart';

/// Simple model for an event add-on.
/// Later this maps to the event_accessories table:
///   event_id, accessory_name, price
class EventAddon {
  String name;
  double price;
  EventAddon({required this.name, required this.price});
}

/// Collapsible card that shows the list of event add-ons.
/// Works the same way as EventRolePriceCard — parent owns the data.
class EventAddonCard extends StatefulWidget {
  final List<EventAddon> addons;
  final VoidCallback onAdd;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;

  const EventAddonCard({
    super.key,
    required this.addons,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<EventAddonCard> createState() => _EventAddonCardState();
}

class _EventAddonCardState extends State<EventAddonCard> {
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
          // ── Header row with Add-on button and expand toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.extension_outlined, size: 16, color: kNavy),
                  const SizedBox(width: 6),
                  const Text(
                    'Add-ons',
                    style: TextStyle(
                      color: kNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  // "+ Add-on" button sits in the header row (matches design)
                  OutlinedButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add, size: 14, color: kNavy),
                    label: const Text(
                      'Add-on',
                      style: TextStyle(color: kNavy, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kNavy),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: kNavy,
                  ),
                ],
              ),
            ),
          ),

          // ── Add-on list
          if (_expanded && widget.addons.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: List.generate(widget.addons.length, (i) {
                  final addon = widget.addons[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            addon.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: kTextMain,
                            ),
                          ),
                        ),
                        Text(
                          addon.price == addon.price.truncateToDouble()
                              ? addon.price.toInt().toString()
                              : addon.price.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: kTextMain,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog for adding or editing an add-on.
// Same pattern as showRoleDialog — returns the result or null if cancelled.
// ─────────────────────────────────────────────────────────────────────────────
Future<EventAddon?> showAddonDialog(
    BuildContext context, {
      EventAddon? existing,
    }) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final priceCtrl = TextEditingController(
    text: existing != null ? existing.price.toString() : '',
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<EventAddon>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        existing == null ? 'Add Add-on' : 'Edit Add-on',
        style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              decoration: _dialogInputDecoration('Add-on name (e.g. T-Shirt)'),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: _dialogInputDecoration('Price (e.g. 150)'),
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
                EventAddon(
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
