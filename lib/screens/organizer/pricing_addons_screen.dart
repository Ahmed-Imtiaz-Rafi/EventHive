/// pricing_addons_screen.dart
///
/// Screen 5 — Pricing & Add-ons.
/// Shows two tabs: Pricing (Roles) and Add-ons for a selected event.
/// Loads existing data from event_role_price and event_accessories tables.
/// Saves all changes through the update_event() RPC, which is the only
/// permitted write path for event data per the schema's RLS rules.
/// Navigated to from the Event Details / Manage screen (manage_event_screen).
library;

import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PricingAddonsScreen extends StatefulWidget {
  final String eventId;
  const PricingAddonsScreen({super.key, required this.eventId});

  @override
  State<PricingAddonsScreen> createState() => _PricingAddonsScreenState();
}

class _PricingAddonsScreenState extends State<PricingAddonsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  // Roles list: each map has 'role_name' and 'price'
  List<Map<String, dynamic>> _roles = [];

  // Add-ons list: each map has 'name' (accessory_name) and 'price'
  List<Map<String, dynamic>> _addons = [];

  // Available role names from the registration_roles lookup table
  List<String> _availableRoleNames = [];

  // We need all event fields to call update_event() — it does a full replace
  Map<String, dynamic>? _eventData;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── DATA LOADING ────────────────────────────────────────────────────────

  /// Loads the full event row, its existing roles and add-ons,
  /// and the list of available role names from registration_roles.
  /// We need the full event row because update_event() requires all fields.
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch everything we need in parallel
      final results = await Future.wait<dynamic>([
        _supabase
            .from('events')
            .select()
            .eq('event_id', widget.eventId)
            .single(),
        _supabase
            .from('event_role_price')
            .select()
            .eq('event_id', widget.eventId),
        _supabase
            .from('event_accessories')
            .select()
            .eq('event_id', widget.eventId),
        _supabase
            .from('registration_roles')
            .select('role_name')
            .order('role_name'),
      ]);

      if (!mounted) return;
      setState(() {
        _eventData = Map<String, dynamic>.from(results[0] as Map);

        // Map role rows into simple {role_name, price} maps
        _roles = (results[1] as List)
            .map(
              (r) => {
                'role_name': r['role_name'].toString(),
                'price': (r['price'] as num?)?.toDouble() ?? 0.0,
              },
            )
            .toList();

        // Map accessory rows, deduplicating by name (one entry per add-on name)
        final seen = <String>{};
        _addons = [];
        for (final r in results[2] as List) {
          final name = r['accessory_name'].toString();
          if (seen.add(name)) {
            _addons.add({
              'name': name,
              'price': (r['price'] as num?)?.toDouble() ?? 0.0,
            });
          }
        }

        _availableRoleNames = (results[3] as List)
            .map((r) => r['role_name'].toString())
            .toList();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ─── SAVE ────────────────────────────────────────────────────────────────

  /// Saves all changes by calling update_event() RPC.
  /// update_event() does a full replace of roles and accessories atomically,
  /// so we always send the complete current list, not just the changed items.
  /// We must pass all required event fields — the RPC won't accept partial data.
  Future<void> _save() async {
    if (_saving || _eventData == null) return;
    if (_roles.isEmpty) {
      _msg('Add at least one pricing role before saving.');
      return;
    }

    final ev = _eventData!;

    // Guard: club_id is required by update_event()
    final clubId = ev['club_id'];
    if (clubId == null) {
      _msg('This event has no hosting club set. Please edit the event first.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Fetch current category IDs — update_event() needs them for the full replace
      final catRows = await _supabase
          .from('event_category_map')
          .select('category_id')
          .eq('event_id', widget.eventId);
      final catIds = (catRows as List)
          .map((r) => r['category_id'] as int)
          .toList();

      if (catIds.isEmpty) {
        _msg('This event has no categories set. Please edit the event first.');
        setState(() => _saving = false);
        return;
      }

      // Build JSON arrays in the exact format update_event() expects
      final rolePrices = _roles
          .map((r) => {'role_name': r['role_name'], 'price': r['price']})
          .toList();

      // Accessories: size defaults to 'one_size' since this screen doesn't manage sizes
      final accessories = _addons
          .map(
            (a) => {'name': a['name'], 'size': 'one_size', 'price': a['price']},
          )
          .toList();

      await _supabase.rpc(
        'update_event',
        params: {
          'p_event_id': widget.eventId,
          'p_name': ev['name'],
          'p_event_date': ev['event_date'],
          'p_venue': ev['venue'],
          'p_capacity': ev['capacity'],
          'p_category_ids': catIds,
          'p_club_id': clubId,
          'p_description': ev['description'],
          'p_start_time': ev['start_time'],
          'p_end_time': ev['end_time'],
          'p_image_url': ev['image_url'],
          'p_department_ids': <int>[],
          'p_accessories': accessories,
          'p_role_prices': rolePrices,
        },
      );

      if (!mounted) return;
      _msg('Pricing saved successfully!');
      context.go('/organizer/event/${widget.eventId}');
    } catch (e) {
      // Show the full error so you can see exactly what the RPC rejected
      debugPrint('update_event error: $e');
      _msg('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ─── ROLE DIALOG ─────────────────────────────────────────────────────────

  /// Opens a dialog to add a new role or edit an existing one.
  /// [index] is null when adding a new role.
  Future<void> _showRoleDialog({int? index}) async {
    final existing = index != null ? _roles[index] : null;
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '0',
    );

    // Find the default selected role — skip ones already added when adding new
    final usedNames = _roles.map((r) => r['role_name'] as String).toSet();
    String selectedRole =
        existing?['role_name'] as String? ??
        _availableRoleNames.firstWhere(
          (n) => !usedNames.contains(n),
          orElse: () =>
              _availableRoleNames.isNotEmpty ? _availableRoleNames.first : '',
        );

    if (selectedRole.isEmpty) {
      _msg('All available roles are already added.');
      priceCtrl.dispose();
      return;
    }

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        // Use a local variable inside the dialog so StatefulBuilder
        // updates it correctly on dropdown change
        String dialogRole = selectedRole;

        return StatefulBuilder(
          builder: (context, set) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              existing == null ? 'Add Role' : 'Edit Role',
              style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: dialogRole,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Role'),
                  // Disable role name change when editing
                  onChanged: existing != null
                      ? null
                      : (v) {
                          if (v != null) set(() => dialogRole = v);
                        },
                  items: _availableRoleNames
                      .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    hintText: 'Enter 0 for free',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kNavy),
                onPressed: () {
                  final price = double.tryParse(priceCtrl.text);
                  if (price == null || price < 0) return;
                  // Use dialogRole — this is the correctly updated value
                  Navigator.pop(ctx, {'role_name': dialogRole, 'price': price});
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );

    priceCtrl.dispose();
    if (saved == null || !mounted) return;

    setState(() {
      if (index == null) {
        if (_roles.any((r) => r['role_name'] == saved['role_name'])) {
          _msg('This role is already added.');
          return;
        }
        _roles.add(saved);
      } else {
        _roles[index] = saved;
      }
    });
  }

  // ─── ADD-ON DIALOG ───────────────────────────────────────────────────────

  /// Opens a dialog to add a new add-on or edit an existing one.
  Future<void> _showAddonDialog({int? index}) async {
    final existing = index != null ? _addons[index] : null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '0',
    );

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add Add-on' : 'Edit Add-on',
          style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. T-shirt',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'e.g. 500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kNavy),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text);
              if (name.isEmpty || price == null || price < 0) return;
              Navigator.pop(ctx, {'name': name, 'price': price});
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    if (saved == null || !mounted) return;

    setState(() {
      if (index == null) {
        _addons.add(saved);
      } else {
        _addons[index] = saved;
      }
    });
  }

  // ─── DELETE HELPERS ──────────────────────────────────────────────────────

  /// Asks for confirmation then removes a role from the local list.
  void _deleteRole(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Role?'),
        content: Text(
          'Remove "${_roles[index]['role_name']}" from this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _roles.removeAt(index));
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Asks for confirmation then removes an add-on from the local list.
  void _deleteAddon(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Add-on?'),
        content: Text('Remove "${_addons[index]['name']}" from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _addons.removeAt(index));
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text(
          'Pricing & Add-ons',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/event/${widget.eventId}'),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: kAmber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Pricing (Roles)'),
            Tab(text: 'Add-ons'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabCtrl,
              children: [_buildRolesTab(), _buildAddonsTab()],
            ),
      bottomNavigationBar: _loading || _error != null ? null : _buildSaveBar(),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kTextSub),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadData,
          style: ElevatedButton.styleFrom(backgroundColor: kNavy),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  // ── Roles tab ─────────────────────────────────────────────────────────────
  Widget _buildRolesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header row with title and Add Role button
        Row(
          children: [
            const Text(
              'Event Roles',
              style: TextStyle(
                color: kNavy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showRoleDialog(),
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
          ],
        ),
        const SizedBox(height: 12),

        if (_roles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No roles added yet. Tap "+ Add Role" to start.',
                style: TextStyle(color: kTextSub),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(_roles.length, (i) {
                final role = _roles[i];
                final price = role['price'] as double;
                final priceStr = price == price.truncateToDouble()
                    ? price.toInt().toString()
                    : price.toString();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: kTextSub,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              role['role_name'].toString(),
                              style: const TextStyle(
                                color: kTextMain,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            priceStr,
                            style: const TextStyle(
                              color: kTextMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Edit button
                          IconButton(
                            onPressed: () => _showRoleDialog(index: i),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: kTextSub,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          // Delete button
                          IconButton(
                            onPressed: () => _deleteRole(i),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFD32F2F),
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFFE0E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < _roles.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── Add-ons tab ───────────────────────────────────────────────────────────
  Widget _buildAddonsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text(
              'Add-ons',
              style: TextStyle(
                color: kNavy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showAddonDialog(),
              icon: const Icon(Icons.add, size: 16, color: kNavy),
              label: const Text(
                'Add Add-on',
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
          ],
        ),
        const SizedBox(height: 12),

        if (_addons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No add-ons yet. Tap "+ Add Add-on" to start.',
                style: TextStyle(color: kTextSub),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(_addons.length, (i) {
                final addon = _addons[i];
                final price = addon['price'] as double;
                final priceStr = price == price.truncateToDouble()
                    ? price.toInt().toString()
                    : price.toString();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.extension_outlined,
                            size: 18,
                            color: kTextSub,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              addon['name'].toString(),
                              style: const TextStyle(
                                color: kTextMain,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            priceStr,
                            style: const TextStyle(
                              color: kTextMain,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showAddonDialog(index: i),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: kTextSub,
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          IconButton(
                            onPressed: () => _deleteAddon(i),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFD32F2F),
                            ),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFFFE0E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < _addons.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── Save bar at the bottom ─────────────────────────────────────────────────
  Widget _buildSaveBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
